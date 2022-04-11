; mem_impl - Banked RAM memory allocation routines

.include "unilib_impl.inc"
.include "cbm_kernal.inc"

.code

; mem_alloc - Allocate a chunk of banked RAM
;   In: YX              - size to allocate (max = 7,936 bytes)
;  Out: YX              - banked RAM "pointer" (Y=bank, X=slot#), 0/0 if allocation fails
.proc ULAPI_mem_alloc
@numslots = gREG::r15H
@extraslot = gREG::r15L
@roomybank = gREG::r15L
@roomybankstart = gREG::r14H
@roomybanksize = gREG::r14L
@chunkstart = gREG::r13H
@inused = gREG::r13L
                        ; Switch to bank 1 to start
                        pha
                        lda BANK_RAM
                        pha
                        lda #1
                        sta BANK_RAM

                        ; Figure out how many slots we need by dividing by 32, but first, if any of the low 5 bits are
                        ; set, we'll need an extra slot
                        stz @extraslot
                        sty @numslots
                        txa
                        and #$1F
                        beq :+
                        inc @extraslot

                        ; Divide size by 32
:                       txa
                        lsr @numslots
                        ror
                        lsr @numslots
                        ror
                        lsr @numslots
                        ror
                        lsr @numslots
                        ror
                        lsr @numslots
                        ror
                        ldy @numslots
                        lsr @extraslot
                        adc #0
                        sta @numslots
                        tya
                        bne @failed ; Definitely too big if number of slots is a 16-bit value
                        lda @numslots
                        beq @failed ; Can't alloc nothing
                        cmp #$f8 ; Too big if number of slots is > $f8, since that's the largest free chunk we can have
                        bcs @failed

                        ; Okay, number of slots is in range, see if we have a "smallest" slot that will fit it exactly
                        cmp #8
                        bcc @check_small_blocks

                        ; Need to scan for a chunk of slots; first look for an exact match, and also save the first bank
                        ; with enough room along the way
@need_scan:             ldy #1
                        sty BANK_RAM
                        stz @roomybank

                        ; Search for slot chunk in this bank; shortcut is if bank is empty we know enough room and start
                        ; and no small blocks immediately, and it may be a match too
@scan_for_match:        lda #8
                        ldx BANK_BASE
                        cpx #248
                        bne @really_need_the_scan
                        cpx @numslots
                        beq @found_slot
                        ldy @roomybank
                        bne @scan_next_bank
                        ldy BANK_RAM
                        sty @roomybank
                        sta @roomybankstart
                        stx @roomybanksize
                        bra @scan_next_bank

@really_need_the_scan:  tax
@scan_reset:            ldy #0
                        sty @inused
                        stx @chunkstart
@scan_next:             lda BANK_BASE,x
                        beq @scan_in_free

                        ; We're in a used chunk now; just step through if we were already in it
@scan_in_used:          inc @inused
                        cpy #0
                        beq @check_if_at_end

                        ; Check the size of the free block we just ended to see if it's an exact match for what
                        ; we're scanning for; if it's exact, we can just allocate there
@check_free_slot_size:  cpy @numslots
                        bne @check_max_chunk
                        tya
                        tax
                        lda @chunkstart
                        bra @found_slot

                        ; If it's greater than we're scanning for, save as roomy bank if we don't have one yet
@check_max_chunk:       bcc @check_if_at_end
                        lda @roomybank
                        bne @check_if_at_end
                        lda @chunkstart
                        sta @roomybankstart
                        sty @roomybanksize
                        lda BANK_RAM
                        sta @roomybank

                        ; If we're at the end, step to the next bank; otherwise just step to the next slot
@check_if_at_end:       cpx #0
                        beq @scan_next_bank
                        .byte $24 ; skip next 1-byte instruction

                        ; Count a free slot
@scan_in_free:          iny

                        ; Step to the next slot, unless we're at the end, in which case we should check one more
                        ; free slot
@scan_step:             inx
                        beq @scan_in_used
                        lda @inused
                        bne @scan_reset
                        bra @scan_next

                        ; Step to the next bank
@scan_next_bank:        inc BANK_RAM
                        ldy BANK_RAM
                        cpy ULM_numbanks
                        bne @scan_for_match

                        ; If we get here, there was no exact match, so take a chunk from the biggest free chunk,
                        ; unless it's not big enough, in which case fail
                        ldy @roomybank
                        bne @take_chunk

                        ; Return NULL
@failed:                lda #0
                        tax
                        tay

                        ; Restore bank and return
@done:                  pla
                        sta BANK_RAM
                        pla
                        rts

                        ; For small numbers, we have the index of a matching slot count saved in the corresponding byte of
                        ; each page; scan the pages to see if there's one there
@check_small_blocks:    ldy #1
                        sty BANK_RAM
                        tax
:                       lda BANK_BASE,x
                        bne @found_slot
                        iny
                        sty BANK_RAM
                        cpy ULM_numbanks
                        bne :-
                        jmp @need_scan

                        ; Take chunk from start of bank with room
@take_chunk:            lda @roomybankstart
                        ldx @roomybanksize
                        sty BANK_RAM

                        ; Found a slot in a bank we can use, so mark it as allocated (marked with length so it's
                        ; easy to free later); when we get here, slot # is in A and free chunk length is in X; if
                        ; free chunk length is a small one, remove it from the small chunk list
@found_slot:            pha
                        cpx #8
                        bcs :+
                        stz BANK_BASE,x
:                       tax
                        lda @numslots
                        tay
:                       sta BANK_BASE,x
                        lda #$ff ; just want the first slot to have the length so we can detect wrong pointers on free
                        inx
                        dey
                        bne :-

                        ; If we're not at the end, see if there's empty space past us that will fit in the short table
                        cpx #0
                        beq @adjust_free_count
                        stx @extraslot
:                       lda BANK_BASE,x
                        bne :+
                        iny
                        inx
                        beq :+
                        cpy #8
                        bcc :-
                        bra @adjust_free_count

                        ; Small block end, so update short table entry with start of this free block
:                       cpy #0
                        beq @adjust_free_count
                        cpy #8
                        bcs @adjust_free_count
                        lda @extraslot
                        sta BANK_BASE,y

                        ; Decrement the free count for this page
@adjust_free_count:     lda BANK_BASE
                        sec
                        sbc @numslots
                        sta BANK_BASE

                        ; Return bank in Y and slot in X
                        plx
                        ldy BANK_RAM
                        bra @done
.endproc

; mem_free - Free an allocated banked RAM "pointer"
;   In: Y               - RAM bank
;       X               - slot #
.proc ULAPI_mem_free
                        ; Make sure our paramters are in range before we do anything, check bank first so we can switch to it
                        pha
                        tya
                        beq :+
                        lda ULM_numbanks
                        beq @check_slot
                        cpy ULM_numbanks
                        bcc @check_slot
:                       jmp @exit

                        ; Switch to bank and check that slot is in range and has a valid value in it
@check_slot:            cpx #8
                        bcc :-
                        lda BANK_RAM
                        pha
                        sty BANK_RAM
                        lda BANK_BASE,x
                        beq @restore_bank
                        cmp #249 ; Length can't be more than 248, so if it is we're in the middle of a chunk
                        bcs @restore_bank

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
:                       sta BANK_BASE,x
                        inx
                        dey
                        bne :-

                        ; And update the free count
                        lda BANK_BASE
                        clc
                        adc @savedsize
                        sta BANK_BASE

                        ; Check before and after for free slots that we can consolidate with this one
@beforestart = gREG::r14H
@beforesize = gREG::r13L
@aftersize = gREG::r14L
                        stz @beforestart
                        stz @aftersize
                        ldx #7
@check_short:           lda BANK_BASE,x
                        beq @next_short

                        ; Check if the small free is right after ours
                        cmp @savedend
                        bne :+
                        stx @aftersize
                        stz BANK_BASE,x
                        bra @next_short

                        ; Check if the small free is right before ours
:                       tay
                        stx @beforesize
                        clc
                        adc @beforesize
                        cmp @savedstart
                        bne @next_short
                        sty @beforestart
                        stz BANK_BASE,x

@next_short:            dex
                        bne @check_short

                        ; Now, if we don't have a short free after or before, see if we have a long free; if we do, don't
                        ; any short free we may calculate because it will be wrong
                        lda @savedend
                        beq :+
                        tax
                        lda BANK_BASE,x
                        beq @restore_bank
:                       lda @savedstart
                        cmp #9
                        bcc :+
                        tax
                        dex
                        lda BANK_BASE,x
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
                        sta BANK_BASE,y

                        ; Restore bank and exit
@restore_bank:          pla
                        sta BANK_RAM
@exit:                  pla
                        rts
.endproc

; mem_access - Access the memory at a banked RAM "pointer"
;   In: Y               - RAM bank
;       X               - slot #
;  Out: BANK_RAM        - Set to RAM bank from "pointer"
;       YX              - 16-bit address of memory
.proc ULAPI_mem_access
                        ; Set the RAM bank
                        pha
                        sty BANK_RAM

                        ; We need to multiply the slot # by 32 and add $A000 to get the address
                        txa
                        lsr
                        lsr
                        lsr
                        clc
                        adc #$A0
                        tay
                        txa
                        asl
                        asl
                        asl
                        asl
                        asl
                        tax
                        pla
                        rts
.endproc

; ULM_init - Initialize banked memory management
.proc ULM_init
                        ; See how many RAM banks we have to work with
                        sec
                        jsr MEMTOP
                        sta ULM_numbanks

                        ; Save whatever bank we were on and switch to bank 1
                        lda BANK_RAM
                        pha
                        lda #1
                        sta BANK_RAM

                        ; First page of each bank is slot tracking. First byte is # of free slots, then the next 7 are
                        ; the index of the first free entry that is exactly 1 slot, 2 slots, etc., or 0 if there is no
                        ; exact match. Since there isn't to begin with, the whole first page gets set to 0, and the first
                        ; byte is set to 248 (since the slots for the first page are in use for the bitmap).
@init_bank:             lda #0
                        tax
:                       inx
                        sta BANK_BASE,x
                        bne :-
                        lda #248
                        sta BANK_BASE
                        inc BANK_RAM
                        lda BANK_RAM
                        cmp ULM_numbanks
                        bne @init_bank

                        ; Restore the original bank
                        pla
                        sta BANK_RAM
                        rts
.endproc

.bss

ULM_numbanks:           .res    1
