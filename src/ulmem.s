.include "unilib_impl.inc"

.code

; ulmem_access - Access the memory at a banked RAM pointer (BRP)
;   In: YX              - BRP
;  Out: BANKSEL::RAM    - Set to RAM bank from BRP
;       YX              - 16-bit address of memory
.proc ulmem_access
                        sty BANKSEL::RAM
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

.proc ULM_slot2addr
                        ; Given a slot index in X, turn it into an address in YX; we multiply by 32
                        ; and add BANK::RAM to get the address
                        pha
                        jsr UL_mulxby32
                        tya
                        clc
                        adc #>BANK::RAM
                        tay
                        pla
                        rts
.endproc

; ulmem_capacity - Return the capacity (in bytes) of a banked RAM pointer (BRP)
;   In: YX              - BRP
;  Out: YX              - allocated capacity of the BRP
.proc ulmem_capacity
                        pha
                        sty BANKSEL::RAM
                        lda BANK::RAM,x
                        beq @error
                        inc
                        beq @error
                        dec
                        tax
                        jsr UL_mulxby32
                        pla
                        rts
@error:                 ldx #0
                        ldy #0
                        pla
                        rts
.endproc

; ULM_calcslots - calculate # of slots to use for memory size
;   In: YX              - allocation size
;  Out: A               - number of 32-byte slots needed
;       carry           - clear if size will fit in our banks, set if too big or 0
.proc ULM_calcslots
                        ; Figure out how many slots we need by dividing by 32 (with round up)
                        jsr UL_divyxby32
                        tya
                        bne @failed ; Definitely too big if number of slots is a 16-bit value
                        txa
                        beq @failed ; Can't alloc nothing
                        cmp #$f8 ; Too big if number of slots is > $f8, since that's the largest free chunk we can have
                        rts
@failed:                sec
                        rts
.endproc

_realloc_need_more:
_realloc_numslots = ULM_scratchspace
_realloc_origslots = ULM_scratchspace+1
                        ; Need to allocate more memory, so get back our needed size and allocate
                        ldx _realloc_numslots
                        jsr UL_mulxby32
                        clc
                        jsr ulmem_alloc

                        ; Now we need to copy the old BRP contents into the new one

; ulmem_realloc - Change size of a previously allocated BRP
;   In: r0              - previously allocated BRP
;       YX              - new allocated size (max = 7,936 bytes)
;  Out: YX              - new banked RAM pointer, 0/0 if allocation fails (previous allocation will still be valid)
;       carry           - set on success, clear on failure
ulmem_realloc:
                        ; Calculate number of slots
                        pha
                        lda BANKSEL::RAM
                        pha
                        jsr ULM_calcslots
                        bcs :+
                        jmp _realloc_failed

                        ; See how many slots are in the original
:                       sta _realloc_numslots
                        ldx gREG::r0L
                        ldy gREG::r0H
                        sty BANKSEL::RAM
                        lda BANK::RAM,x
                        cmp _realloc_numslots
                        bcc _realloc_need_more
                        beq _return_r0

                        ; Free extra memory as follows (os = original slot entry, oc = original slot capacity, nc = new slot capacity):
                        ;   * slotmap[os] = nc
                        ;   * slotmap[os + nc] = [oc - nc]
                        ;   * Call ulmem_free on BRP(BANKSEL::RAM, os + nc) (this will take care of clearing slotmap, updating short free list, etc.)
                        sta _realloc_origslots
                        lda _realloc_numslots
                        sta BANK::RAM,x
                        txa
                        clc
                        adc _realloc_numslots
                        tax
                        lda _realloc_origslots
                        sec
                        sbc _realloc_numslots
                        sta BANK::RAM,x
                        ldy BANKSEL::RAM
                        jsr ulmem_free

                        ; Return original BRP
_return_r0:             ldx gREG::r0L
                        ldy gREG::r0H
                        bra _alloc_done

; ulmem_alloc - Allocate a chunk of banked RAM
;   In: YX              - size to allocate (max = 7,936 bytes)
;       carry           - if set, allocated memory will be cleared
;  Out: YX              - banked RAM pointer, 0/0 if allocation fails
;       carry           - set on success, clear on failure
ulmem_alloc:
_alloc_numslots = ULM_scratchspace
_alloc_freestart = ULM_scratchspace+1
_alloc_roomybank = ULM_scratchspace+1
_alloc_roomybankstart = ULM_scratchspace+2
_alloc_roomybanksize = ULM_scratchspace+3
_alloc_chunkstart = ULM_scratchspace+4
_alloc_inused = ULM_scratchspace+5
                        ; Switch to bank 1 to start
                        pha
                        lda BANKSEL::RAM
                        pha
                        php
                        lda #1
                        sta BANKSEL::RAM

                        ; Figure out how many slots we need
                        jsr ULM_calcslots
                        bcs _alloc_failed

                        ; Okay, number of slots is in range, see if we have a "smallest" slot that will fit it exactly
                        sta _alloc_numslots
                        cmp #8
                        bcs _alloc_need_scan

                        ; For small numbers, we have the index of a matching slot count saved in the corresponding byte of
                        ; each page; scan the pages to see if there's one there
_alloc_check_small_blocks:
                        ldy #1
                        sty BANKSEL::RAM
                        tax
:                       lda BANK::RAM,x
                        beq :+
                        jmp _alloc_found_slot
:                       iny
                        sty BANKSEL::RAM
                        cpy ULM_numbanks
                        bne :--

                        ; Need to scan for a chunk of slots; first look for an exact match, and also save the first bank
                        ; with enough room along the way
_alloc_need_scan:       ldy #1
                        sty BANKSEL::RAM
                        stz _alloc_roomybank

                        ; Search for slot chunk in this bank; shortcut is if bank is empty we know enough room and start
                        ; and no small blocks immediately, and it may be a match too
_alloc_scan_for_match:  lda #8
                        ldx BANK::RAM
                        cpx #248
                        bne _alloc_really_need_the_scan
                        cpx _alloc_numslots
                        beq _alloc_found_slot
                        ldy _alloc_roomybank
                        bne _alloc_scan_next_bank
                        ldy BANKSEL::RAM
                        sty _alloc_roomybank
                        sta _alloc_roomybankstart
                        stx _alloc_roomybanksize
                        bra _alloc_scan_next_bank

_alloc_really_need_the_scan:
                        tax
_alloc_scan_reset:      ldy #0
                        sty _alloc_inused
                        stx _alloc_chunkstart
_alloc_scan_next:       lda BANK::RAM,x
                        beq _alloc_scan_in_free

                        ; We're in a used chunk now; just step through if we were already in it
_alloc_scan_in_used:    inc _alloc_inused
                        cpy #0
                        beq _alloc_check_if_at_end

                        ; Check the size of the free block we just ended to see if it's an exact match for what
                        ; we're scanning for; if it's exact, we can just allocate there
_alloc_check_free_slot_size:
                        cpy _alloc_numslots
                        bne _alloc_check_max_chunk
                        tya
                        tax
                        lda _alloc_chunkstart
                        bra _alloc_found_slot

                        ; Return NULL
_alloc_failed:          plp
_realloc_failed:        lda #0
                        tax
                        tay
                        clc

                        ; Restore bank and return
_alloc_done:            pla
                        sta BANKSEL::RAM
                        pla
                        rts

                        ; If it's greater than we're scanning for, save as roomy bank if we don't have one yet
_alloc_check_max_chunk: bcc _alloc_check_if_at_end
                        lda _alloc_roomybank
                        bne _alloc_check_if_at_end
                        lda _alloc_chunkstart
                        sta _alloc_roomybankstart
                        sty _alloc_roomybanksize
                        lda BANKSEL::RAM
                        sta _alloc_roomybank

                        ; If we're at the end, step to the next bank; otherwise just step to the next slot
_alloc_check_if_at_end: cpx #0
                        beq _alloc_scan_next_bank
                        .byte $24 ; skip next 1-byte instruction

                        ; Count a free slot
_alloc_scan_in_free:    iny

                        ; Step to the next slot, unless we're at the end, in which case we should check one more
                        ; free slot
_alloc_scan_step:       inx
                        beq _alloc_scan_in_used
                        lda _alloc_inused
                        bne _alloc_scan_reset
                        bra _alloc_scan_next

                        ; Step to the next bank
_alloc_scan_next_bank:  inc BANKSEL::RAM
                        ldy BANKSEL::RAM
                        cpy ULM_numbanks
                        bne _alloc_scan_for_match

                        ; If we get here, there was no exact match, so take a chunk from the biggest free chunk,
                        ; unless it's not big enough, in which case fail
                        ldy _alloc_roomybank
                        bne _alloc_take_chunk
                        jmp _alloc_failed

                        ; Take chunk from start of bank with room
_alloc_take_chunk:      lda _alloc_roomybankstart
                        ldx _alloc_roomybanksize
                        sty BANKSEL::RAM

                        ; Found a slot in a bank we can use, so mark it as allocated (marked with length so it's
                        ; easy to free later); when we get here, slot # is in A and free chunk length is in X; if
                        ; free chunk length is a small one, remove it from the small chunk list
_alloc_found_slot:      pha
                        cpx #8
                        bcs :+
                        stz BANK::RAM,x
:                       tax
                        lda _alloc_numslots
                        tay
:                       sta BANK::RAM,x
                        lda #$ff ; just want the first slot to have the length so we can detect wrong pointers on free
                        inx
                        dey
                        bne :-

                        ; If we're not at the end, see if there's empty space past us that will fit in the short table
                        cpx #0
                        beq _alloc_adjust_free_count
                        stx _alloc_freestart
:                       lda BANK::RAM,x
                        bne :+
                        iny
                        inx
                        beq :+
                        cpy #8
                        bcc :-
                        bra _alloc_adjust_free_count

                        ; Small block end, so update short table entry with start of this free block
:                       cpy #0
                        beq _alloc_adjust_free_count
                        cpy #8
                        bcs _alloc_adjust_free_count
                        lda _alloc_freestart
                        sta BANK::RAM,y

                        ; Decrement the free count for this page
_alloc_adjust_free_count:
                        lda BANK::RAM
                        sec
                        sbc _alloc_numslots
                        sta BANK::RAM

                        ; If carry was set on entry, clear the allocated memory
                        plx
                        plp
                        stx _alloc_reloadslot+1
                        bcc _alloc_return_brp

                        ; Save r0/r1 so we can use memory_fill
                        PUSHREGS 2

                        ; Calculate address
_alloc_reloadslot:      ldx #$00
                        jsr ULM_slot2addr
                        stx gREG::r0L
                        sty gREG::r0H

                        ; Calculate length
                        ldx _alloc_numslots
                        jsr UL_mulxby32
                        stx gREG::r1L
                        sty gREG::r1H

                        ; Clear allocated memory
                        lda #0
                        jsr MEMORY_FILL

                        ; Restore r0/r1
                        POPREGS 2

                        ; Return bank in Y and slot in X
_alloc_return_brp:      ldx _alloc_reloadslot+1
                        ldy BANKSEL::RAM
                        sec
                        jmp _alloc_done

; ulmem_free - Free an allocated banked RAM pointer
;   In: YX              - BRP to free
.proc ulmem_free
@savedstart = ULM_scratchspace
@savedend = ULM_scratchspace+1
@savedsize = ULM_scratchspace+2
@beforestart = ULM_scratchspace+3
@beforesize = ULM_scratchspace+4
@aftersize = ULM_scratchspace+5
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

.proc ULM_init
                        ; Initialize the banked RAM so it's ready for memory allocations; see how many RAM banks we have to work with
                        sec
                        jsr MEMTOP
                        sta ULM_numbanks

                        ; First page of each bank is slot tracking. First byte is # of free slots, then the next 7 are
                        ; the index of the first free entry that is exactly 1 slot, 2 slots, etc., or 0 if there is no
                        ; exact match. Since there isn't to begin with, the whole first page gets set to 0, and the first
                        ; byte is set to 248 (since the slots for the first page are in use for the bitmap).
@init_bank:             lda #0
                        tax
:                       inx
                        sta BANK::RAM,x
                        bne :-
                        lda #248
                        sta BANK::RAM
                        inc BANKSEL::RAM
                        lda BANKSEL::RAM
                        cmp ULM_numbanks
                        bne @init_bank
                        rts
.endproc

.bss

ULM_numbanks:           .res    1
ULM_scratchspace:       .res    6
