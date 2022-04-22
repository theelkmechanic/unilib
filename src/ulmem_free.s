.include "unilib_impl.inc"

.code

; ulmem_free - Free an allocated banked RAM pointer
;   In: YX              - BRP to free
.proc ulmem_free
                        ; Get BRP into YX
                        ldx gREG::r0L
                        ldy gREG::r0H
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULM_free - Free an allocated banked RAM pointer
;   In: YX              - BRP to free
.proc ULM_free
                        ; Make sure our paramters are in range before we do anything, check bank first so we can switch to it
                        pha
                        tya
                        beq :+
                        lda ULM_numbanks
                        beq @check_slot
                        cpy ULM_numbanks
                        bcc @check_slot

                        ; Bad BRP, so blow up
:                       lda #ULERR::INVALID_BRP
                        sta UL_lasterr
                        jmp UL_terminate

                        ; Switch to bank and check that slot is in range and has a valid value in it
@check_slot:            cpx #8
                        bcc :-
                        lda BANKSEL::RAM
                        pha
                        sty BANKSEL::RAM
                        lda BANK::RAM,x
                        beq :-
                        cmp #249 ; Length can't be more than 248, so if it is we're in the middle of a chunk
                        bcs :-

                        ; Okay, we have a valid pointer, so mark it free
@savedstart = gREG::r15H
@savedend = gREG::r13H
@savedsize = gREG::r15L
                        stx @savedstart
                        sta @savedsize
                        clc
                        adc @savedstart
                        sta @savedend
                        ldy @savedsize
                        lda #0
:                       sta BANK::RAM,x
                        inx
                        dey
                        bne :-

                        ; And update the free count
                        lda BANK::RAM
                        clc
                        adc @savedsize
                        sta BANK::RAM

                        ; Check before and after for free slots that we can consolidate with this one
@beforestart = gREG::r14H
@beforesize = gREG::r13L
@aftersize = gREG::r14L
                        stz @beforestart
                        stz @aftersize
                        ldx #7
@check_short:           lda BANK::RAM,x
                        beq @next_short

                        ; Check if the small free is right after ours
                        cmp @savedend
                        bne :+
                        stx @aftersize
                        stz BANK::RAM,x
                        bra @next_short

                        ; Check if the small free is right before ours
:                       tay
                        stx @beforesize
                        clc
                        adc @beforesize
                        cmp @savedstart
                        bne @next_short
                        sty @beforestart
                        stz BANK::RAM,x

@next_short:            dex
                        bne @check_short

                        ; Now, if we don't have a short free after or before, see if we have a long free; if we do, don't
                        ; any short free we may calculate because it will be wrong
                        lda @savedend
                        beq :+
                        tax
                        lda BANK::RAM,x
                        beq @restore_bank
:                       lda @savedstart
                        cmp #9
                        bcc :+
                        tax
                        dex
                        lda BANK::RAM,x
                        beq @restore_bank

                        ; Add up the size of our slot after consolidation and save it in the small list if small enough
:                       ldx @savedstart
                        lda @beforestart
                        beq :+
                        tax
                        lda @beforesize
:                       clc
                        adc @savedsize
                        adc @aftersize
                        cmp #8
                        bcs @restore_bank
                        tay
                        txa
                        sta BANK::RAM,y

                        ; Restore bank and exit
@restore_bank:          pla
                        sta BANKSEL::RAM
                        pla
                        rts
.endproc
