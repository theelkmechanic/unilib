.include "unilib_impl.inc"

.code

; ulitr_create - Create a new iterator
;   In: A               - type | format (e.g., ULITYP::BRP | ULIFMT::BYTE)
;       YX              - object to iterate over (BRP handle, memory address, or VRAM address)
;       r0              - byte count (0 = use full allocated capacity, BRP only)
;       carry           - for VRAM type: high bit (bit 16) of VRAM address
;  Out: YX              - iterator handle (BRP)
;       carry           - set on success, clear on failure
.proc ulitr_create
                        ; Save parameters
                        sta ULI_scratch         ; type_format
                        stx ULI_scratch+1       ; target lo
                        sty ULI_scratch+2       ; target hi

                        ; Save carry for VRAM type (before any flag-modifying ops)
                        stz ULI_scratch+6       ; clear carry storage
                        bcc :+
                        inc ULI_scratch+6       ; save carry bit
:
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Dispatch by type to get start address, bank, and capacity
                        lda ULI_scratch
                        and #$0F
                        cmp #ULITYP::BRP
                        beq @create_brp
                        cmp #ULITYP::MEM
                        beq @create_mem
                        cmp #ULITYP::LIST
                        bne :+
                        jmp ULI_list_create
:                       cmp #ULITYP::VRAM
                        beq @create_vram

                        ; Unsupported type
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

                        ; --- BRP type: get target address and capacity ---
@create_brp:            ldx ULI_scratch+1
                        ldy ULI_scratch+2
                        jsr ulmem_access
                        stx ULI_scratch+3       ; start_lo
                        sty ULI_scratch+4       ; start_hi
                        lda BANKSEL::RAM
                        sta ULI_scratch+5       ; start_bank

                        ; Use r0 as byte count if non-zero, else use full capacity
                        lda gREG::r0L
                        ora gREG::r0H
                        bne @use_r0

                        ; r0 == 0: get full allocated capacity
                        ldx ULI_scratch+1
                        ldy ULI_scratch+2
                        jsr ulmem_capacity      ; YX = capacity in bytes
                        bra @calc_end

@use_r0:                ldx gREG::r0L
                        ldy gREG::r0H

                        ; Calculate end = start + size
@calc_end:              txa
                        clc
                        adc ULI_scratch+3
                        sta ULI_scratch+6       ; end_lo
                        tya
                        adc ULI_scratch+4
                        sta ULI_scratch+7       ; end_hi
                        ; end_bank = start_bank (BRP is within one bank)
                        lda ULI_scratch+5
                        sta ULI_scratch+2       ; end_bank
                        bra @check_reverse

                        ; --- MEM type: direct memory address ---
@create_mem:            lda ULI_scratch+1
                        sta ULI_scratch+3       ; start_lo
                        lda ULI_scratch+2
                        sta ULI_scratch+4       ; start_hi

                        ; Determine bank: $A0-$BF hi byte = caller's bank, else 0
                        cmp #$A0
                        bcc @mem_bank0
                        cmp #$C0
                        bcs @mem_bank0
                        ; In banked RAM range - peek caller's bank from stack
                        tsx
                        lda $101,x
                        sta ULI_scratch+5       ; bank = caller's bank
                        bra @mem_calc_end

@mem_bank0:             stz ULI_scratch+5       ; bank = 0

@mem_calc_end:          ; size from r0 (required for MEM)
                        lda gREG::r0L
                        clc
                        adc ULI_scratch+3
                        sta ULI_scratch+6       ; end_lo
                        lda gREG::r0H
                        adc ULI_scratch+4
                        sta ULI_scratch+7       ; end_hi
                        lda ULI_scratch+5
                        sta ULI_scratch+2       ; end_bank = start_bank
                        bra @check_reverse

                        ; --- VRAM type: VERA video RAM ---
@create_vram:           lda ULI_scratch+1
                        sta ULI_scratch+3       ; start_lo
                        lda ULI_scratch+2
                        sta ULI_scratch+4       ; start_hi
                        lda ULI_scratch+6       ; saved carry = VRAM bit 16
                        sta ULI_scratch+5       ; start_bank

                        ; size from r0 (required for VRAM)
                        lda gREG::r0L
                        clc
                        adc ULI_scratch+3
                        sta ULI_scratch+6       ; end_lo
                        lda gREG::r0H
                        adc ULI_scratch+4
                        sta ULI_scratch+7       ; end_hi
                        lda ULI_scratch+5       ; start_bank
                        adc #0                  ; + carry from 16-bit addition
                        sta ULI_scratch+2       ; end_bank
                        bra @check_reverse

                        ; --- Check REVERSE flag and swap start/end if set ---
@check_reverse:         lda ULI_scratch
                        bpl @allocate_state     ; bit 7 clear = not reverse

                        ; Get step size
                        jsr ULI_get_step
                        sta ULI_scratch+1       ; save step

                        ; new_start = old_end - step (save on stack temporarily)
                        lda ULI_scratch+6       ; end_lo
                        sec
                        sbc ULI_scratch+1
                        pha                     ; new_start_lo
                        lda ULI_scratch+7       ; end_hi
                        sbc #0
                        pha                     ; new_start_hi
                        lda ULI_scratch+2       ; end_bank
                        sbc #0
                        pha                     ; new_start_bank

                        ; new_end = old_start - step
                        lda ULI_scratch+3       ; start_lo
                        sec
                        sbc ULI_scratch+1
                        sta ULI_scratch+6       ; new end_lo
                        lda ULI_scratch+4       ; start_hi
                        sbc #0
                        sta ULI_scratch+7       ; new end_hi
                        lda ULI_scratch+5       ; start_bank
                        sbc #0
                        sta ULI_scratch+2       ; new end_bank

                        ; Pop new_start from stack into start slots
                        pla
                        sta ULI_scratch+5       ; new start_bank
                        pla
                        sta ULI_scratch+4       ; new start_hi
                        pla
                        sta ULI_scratch+3       ; new start_lo

                        ; --- Allocate iterator state BRP (ULI_STATE_SIZE = 10 bytes) ---
@allocate_state:        ldx #ULI_STATE_SIZE
                        ldy #0
                        sec                     ; clear the allocated memory
                        jsr ulmem_alloc
                        bcs @alloc_ok

                        ; Allocation failed
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

@alloc_ok:              ; Save iterator handle for return
                        phx
                        phy

                        ; Access the iterator state BRP to write initial state
                        jsr ulmem_access
                        stx ULI_ptr
                        sty ULI_ptr+1

                        ; Write type_format
                        lda ULI_scratch
                        sta (ULI_ptr)

                        ; Write cur = start
                        ldy #ULI_STATE_CUR
                        lda ULI_scratch+3
                        sta (ULI_ptr),y
                        iny
                        lda ULI_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_scratch+5
                        sta (ULI_ptr),y

                        ; Write start
                        ldy #ULI_STATE_START
                        lda ULI_scratch+3
                        sta (ULI_ptr),y
                        iny
                        lda ULI_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_scratch+5
                        sta (ULI_ptr),y

                        ; Write end
                        ldy #ULI_STATE_END
                        lda ULI_scratch+6
                        sta (ULI_ptr),y
                        iny
                        lda ULI_scratch+7
                        sta (ULI_ptr),y
                        iny
                        lda ULI_scratch+2       ; end_bank
                        sta (ULI_ptr),y

                        ; Return iterator handle
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        sec                     ; success
                        rts
.endproc

; ulitr_delete - Delete an iterator and free its state
;   In: YX              - iterator handle (BRP)
.proc ulitr_delete
                        jmp ulmem_free
.endproc

; ulitr_fetch - Read value at current iterator position
;   In: YX              - iterator handle
;  Out: A               - value (for BYTE format), r0/r1 for multi-byte
;       carry           - set if error (at end)
.proc ulitr_fetch
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Load iterator state
                        jsr ULI_load            ; A = type_format, state bank selected
                        sta ULI_type_format

                        ; Check if at end
                        jsr ULI_at_end
                        beq @at_end

                        ; Read value at current position
                        jsr ULI_do_fetch

                        ; Restore caller's bank and return success
                        pla
                        sta BANKSEL::RAM
                        lda ULI_scratch         ; value (BYTE format in A)
                        clc
                        rts

@at_end:                pla
                        sta BANKSEL::RAM
                        sec
                        rts
.endproc

; ulitr_store - Write value at current iterator position
;   In: YX              - iterator handle
;       A               - value to store (for BYTE format), r0/r1 for multi-byte
;  Out: carry           - set if error (at end)
.proc ulitr_store
                        ; Save the value to store (BYTE format)
                        sta ULI_scratch

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Load iterator state
                        jsr ULI_load
                        sta ULI_type_format

                        ; Check if at end
                        jsr ULI_at_end
                        beq @at_end

                        ; Write value at current position
                        jsr ULI_do_store

                        ; Restore caller's bank and return success
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

@at_end:                pla
                        sta BANKSEL::RAM
                        sec
                        rts
.endproc

; ulitr_inc - Advance iterator to next entry
;   In: YX              - iterator handle
;  Out: carry           - set if at end (cannot advance)
.proc ulitr_inc
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Load iterator state
                        jsr ULI_load            ; A = type_format
                        sta ULI_type_format

                        ; Check if at end
                        jsr ULI_at_end
                        beq @at_end

                        ; Get step size and advance (direction-aware)
                        lda ULI_type_format
                        jsr ULI_get_step        ; A = step size
                        jsr ULI_step_forward

                        ; LIST boundary check
                        lda ULI_type_format
                        and #$0F
                        cmp #ULITYP::LIST
                        bne :+
                        jsr ULI_list_boundary_check
:
                        ; Save updated position back to state
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        jsr ULI_save_cur

                        ; Restore and return success
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

@at_end:                pla
                        sta BANKSEL::RAM
                        sec
                        rts
.endproc

; ulitr_dec - Rewind iterator to previous entry
;   In: YX              - iterator handle
;  Out: carry           - set if at start (cannot rewind)
.proc ulitr_dec
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Load iterator state
                        jsr ULI_load            ; A = type_format
                        sta ULI_type_format

                        ; Check if at start
                        jsr ULI_at_start
                        beq @at_start

                        ; Get step size and rewind (direction-aware)
                        lda ULI_type_format
                        jsr ULI_get_step        ; A = step size
                        jsr ULI_step_backward

                        ; LIST boundary check
                        lda ULI_type_format
                        and #$0F
                        cmp #ULITYP::LIST
                        bne :+
                        jsr ULI_list_boundary_check
:
                        ; Save updated position back to state
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        jsr ULI_save_cur

                        ; Restore and return success
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

@at_start:              pla
                        sta BANKSEL::RAM
                        sec
                        rts
.endproc

; ulitr_fetch_and_inc - Read value and advance iterator
;   In: YX              - iterator handle
;  Out: A               - value (for BYTE format), r0/r1 for multi-byte
;       carry           - set if at end (no data, no advance)
.proc ulitr_fetch_and_inc
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Load iterator state
                        jsr ULI_load            ; A = type_format
                        sta ULI_type_format

                        ; Check if at end
                        jsr ULI_at_end
                        beq @at_end

                        ; Read value at current position
                        jsr ULI_do_fetch

                        ; Advance current position (direction-aware)
                        lda ULI_type_format
                        jsr ULI_get_step
                        jsr ULI_step_forward

                        ; LIST boundary check
                        lda ULI_type_format
                        and #$0F
                        cmp #ULITYP::LIST
                        bne :+
                        jsr ULI_list_boundary_check
:
                        ; Switch back to state bank and save updated position
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        jsr ULI_save_cur

                        ; Restore caller's bank, return value and success
                        pla
                        sta BANKSEL::RAM
                        lda ULI_scratch         ; fetched value
                        clc
                        rts

@at_end:                pla
                        sta BANKSEL::RAM
                        sec
                        rts
.endproc

; ulitr_fetch_and_dec - Read value and rewind iterator
;   In: YX              - iterator handle
;  Out: A               - value (for BYTE format), r0/r1 for multi-byte
;       carry           - set if at end (no data)
.proc ulitr_fetch_and_dec
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Load iterator state
                        jsr ULI_load            ; A = type_format
                        sta ULI_type_format

                        ; Check if at end (can't fetch from end)
                        jsr ULI_at_end
                        beq @at_end

                        ; Read value at current position
                        jsr ULI_do_fetch

                        ; Rewind current position (only if not at start)
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        jsr ULI_at_start
                        beq @done               ; at start, skip decrement

                        lda ULI_type_format
                        jsr ULI_get_step
                        jsr ULI_step_backward

                        ; LIST boundary check
                        lda ULI_type_format
                        and #$0F
                        cmp #ULITYP::LIST
                        bne :+
                        jsr ULI_list_boundary_check
:
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        jsr ULI_save_cur

@done:                  pla
                        sta BANKSEL::RAM
                        lda ULI_scratch         ; fetched value
                        clc
                        rts

@at_end:                pla
                        sta BANKSEL::RAM
                        sec
                        rts
.endproc

; ulitr_adv - Advance iterator by A entries
;   In: YX              - iterator handle
;       A               - number of entries to advance
;  Out: carry           - set if error
.proc ulitr_adv
                        ; Save count and caller's bank
                        sta ULI_scratch+2       ; count
                        lda BANKSEL::RAM
                        pha

                        ; Load iterator state
                        jsr ULI_load            ; A = type_format
                        sta ULI_type_format

                        ; Get step size
                        jsr ULI_get_step        ; A = step per entry

                        ; Multiply step * count via repeated stepping
                        sta ULI_scratch+1       ; step size
                        ldx ULI_scratch+2       ; count
                        beq @done
@loop:                  lda ULI_scratch+1
                        jsr ULI_step_forward

                        ; LIST boundary check (preserve X loop counter)
                        lda ULI_type_format
                        and #$0F
                        cmp #ULITYP::LIST
                        bne :+
                        phx
                        jsr ULI_list_boundary_check
                        plx
:
                        dex
                        bne @loop

                        ; Save updated position
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        jsr ULI_save_cur

@done:                  pla
                        sta BANKSEL::RAM
                        clc
                        rts
.endproc

; ulitr_rew - Rewind iterator by A entries
;   In: YX              - iterator handle
;       A               - number of entries to rewind
;  Out: carry           - set if error
.proc ulitr_rew
                        ; Save count and caller's bank
                        sta ULI_scratch+2       ; count
                        lda BANKSEL::RAM
                        pha

                        ; Load iterator state
                        jsr ULI_load            ; A = type_format
                        sta ULI_type_format

                        ; Get step size
                        jsr ULI_get_step        ; A = step per entry

                        ; Multiply step * count via repeated stepping
                        sta ULI_scratch+1       ; step size
                        ldx ULI_scratch+2       ; count
                        beq @done
@loop:                  lda ULI_scratch+1
                        jsr ULI_step_backward

                        ; LIST boundary check (preserve X loop counter)
                        lda ULI_type_format
                        and #$0F
                        cmp #ULITYP::LIST
                        bne :+
                        phx
                        jsr ULI_list_boundary_check
                        plx
:
                        dex
                        bne @loop

                        ; Save updated position
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        jsr ULI_save_cur

@done:                  pla
                        sta BANKSEL::RAM
                        clc
                        rts
.endproc

; ulitr_atstart - Check if iterator is at start of range
;   In: YX              - iterator handle
;  Out: Z set if at start
.proc ulitr_atstart
                        lda BANKSEL::RAM
                        pha                     ; stack: [bank]
                        jsr ULI_load
                        jsr ULI_at_start        ; Z = result
                        php                     ; stack: [bank][flags]
                        pla                     ; A = flags
                        plx                     ; X = saved bank
                        stx BANKSEL::RAM
                        pha                     ; push flags back
                        plp                     ; restore Z
                        rts
.endproc

; ulitr_atend - Check if iterator is at end of range
;   In: YX              - iterator handle
;  Out: Z set if at end
.proc ulitr_atend
                        lda BANKSEL::RAM
                        pha                     ; stack: [bank]
                        jsr ULI_load
                        jsr ULI_at_end          ; Z = result
                        php                     ; stack: [bank][flags]
                        pla                     ; A = flags
                        plx                     ; X = saved bank
                        stx BANKSEL::RAM
                        pha                     ; push flags back
                        plp                     ; restore Z
                        rts
.endproc
