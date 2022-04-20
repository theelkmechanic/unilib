.include "unilib_impl.inc"

.code

; ulmem_alloc - Allocate a chunk of banked RAM
;   In: YX              - size to allocate (max = 7,936 bytes)
;       carry           - if set, allocated memory will be cleared
;  Out: YX              - banked RAM "pointer" (Y=bank, X=slot#), 0/0 if allocation fails
;       carry           - set on success, clear on failure
.proc ulmem_alloc
@numslots = gREG::r15H
@extraslot = gREG::r15L
@roomybank = gREG::r15L
@roomybankstart = gREG::r14H
@roomybanksize = gREG::r14L
@chunkstart = gREG::r13H
@inused = gREG::r13L
                        ; Switch to bank 1 to start
                        pha
                        lda BANKSEL::RAM
                        pha
                        php
                        lda #1
                        sta BANKSEL::RAM

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
                        sty BANKSEL::RAM
                        stz @roomybank

                        ; Search for slot chunk in this bank; shortcut is if bank is empty we know enough room and start
                        ; and no small blocks immediately, and it may be a match too
@scan_for_match:        lda #8
                        ldx BANK::RAM
                        cpx #248
                        bne @really_need_the_scan
                        cpx @numslots
                        beq @found_slot
                        ldy @roomybank
                        bne @scan_next_bank
                        ldy BANKSEL::RAM
                        sty @roomybank
                        sta @roomybankstart
                        stx @roomybanksize
                        bra @scan_next_bank

@really_need_the_scan:  tax
@scan_reset:            ldy #0
                        sty @inused
                        stx @chunkstart
@scan_next:             lda BANK::RAM,x
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
                        lda BANKSEL::RAM
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
@scan_next_bank:        inc BANKSEL::RAM
                        ldy BANKSEL::RAM
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
                        plp
                        clc

                        ; Restore bank and return
@done:                  pla
                        sta BANKSEL::RAM
                        pla
                        rts

                        ; For small numbers, we have the index of a matching slot count saved in the corresponding byte of
                        ; each page; scan the pages to see if there's one there
@check_small_blocks:    ldy #1
                        sty BANKSEL::RAM
                        tax
:                       lda BANK::RAM,x
                        bne @found_slot
                        iny
                        sty BANKSEL::RAM
                        cpy ULM_numbanks
                        bne :-
                        jmp @need_scan

                        ; Take chunk from start of bank with room
@take_chunk:            lda @roomybankstart
                        ldx @roomybanksize
                        sty BANKSEL::RAM

                        ; Found a slot in a bank we can use, so mark it as allocated (marked with length so it's
                        ; easy to free later); when we get here, slot # is in A and free chunk length is in X; if
                        ; free chunk length is a small one, remove it from the small chunk list
@found_slot:            pha
                        cpx #8
                        bcs :+
                        stz BANK::RAM,x
:                       tax
                        lda @numslots
                        tay
:                       sta BANK::RAM,x
                        lda #$ff ; just want the first slot to have the length so we can detect wrong pointers on free
                        inx
                        dey
                        bne :-

                        ; If we're not at the end, see if there's empty space past us that will fit in the short table
                        cpx #0
                        beq @adjust_free_count
                        stx @extraslot
:                       lda BANK::RAM,x
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
                        sta BANK::RAM,y

                        ; Decrement the free count for this page
@adjust_free_count:     lda BANK::RAM
                        sec
                        sbc @numslots
                        sta BANK::RAM

                        ; If carry was set on entry, clear the allocated memory
                        plx
                        plp
                        phx
                        bcc @return_brp

                        ; Save r0/r1 so we can use memory_fill
                        lda gREG::r0
                        pha
                        lda gREG::r0+1
                        pha
                        lda gREG::r1
                        pha
                        lda gREG::r1+1
                        pha

                        ; Calculate address
                        txa
                        stz gREG::r0+1
                        asl
                        rol gREG::r0+1
                        asl
                        rol gREG::r0+1
                        asl
                        rol gREG::r0+1
                        asl
                        rol gREG::r0+1
                        asl
                        sta gREG::r0
                        lda gREG::r0+1
                        rol
                        adc #$a0
                        sta gREG::r0+1

                        ; Calculate length
                        lda @numslots
                        stz gREG::r1+1
                        asl
                        rol gREG::r1+1
                        asl
                        rol gREG::r1+1
                        asl
                        rol gREG::r1+1
                        asl
                        rol gREG::r1+1
                        asl
                        rol gREG::r1+1
                        sta gREG::r1

                        ; Clear allocated memory
                        lda #0
                        jsr MEMORY_FILL

                        ; Restore r0/r1
                        pla
                        sta gREG::r1+1
                        pla
                        sta gREG::r1
                        pla
                        sta gREG::r0+1
                        pla
                        sta gREG::r0

                        ; Return bank in Y and slot in X
@return_brp:            plx
                        ldy BANKSEL::RAM
                        sec
                        jmp @done
.endproc
