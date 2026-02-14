.include "unilib_impl.inc"

.segment "EXTZP" : zeropage

; These zero-page pointers are shared with ULW_utils (as UL_src_fptr/UL_dst_fptr)
; and other modules. They are scratch pointers, not preserved across calls.
ULI_ptr:
UL_dst_fptr:    .res 2          ; pointer to iterator state / destination pointer
ULI_cur:
UL_src_fptr:    .res 2          ; current target address / source pointer

UL_CODE

; Format step sizes indexed by (format >> 4)
; BYTE=1, WORD=2, TBYTE=3, DWORD=4, FLOAT=5, UTF8=0(variable), STRTBL=2
ULI_step_sizes: .byte 1, 2, 3, 4, 5, 0, 2, 0

; ULI_load - Load iterator state into working area
;   In: YX              - iterator BRP handle
;  Out: ULI_ptr         - pointer to iterator state in banked RAM
;       ULI_cur         - current target address (2 bytes in zp)
;       ULI_cur_bank    - current target bank
;       ULI_state_bank  - bank where iterator state lives
;       A               - type_format byte
;       BANKSEL::RAM    - set to iterator state bank
.proc ULI_load
                        jsr ulmem_access
                        stx ULI_ptr
                        sty ULI_ptr+1
                        lda BANKSEL::RAM
                        sta ULI_state_bank

                        ; Load current position
                        ldy #ULI_STATE_CUR
                        lda (ULI_ptr),y
                        sta ULI_cur
                        iny
                        lda (ULI_ptr),y
                        sta ULI_cur+1
                        iny
                        lda (ULI_ptr),y
                        sta ULI_cur_bank

                        ; Return type_format in A
                        lda (ULI_ptr)
                        rts
.endproc

; ULI_save_cur - Write current position back to iterator state
;   In: ULI_ptr valid, ULI_cur/ULI_cur_bank updated
;       BANKSEL::RAM    - must be set to iterator state bank
.proc ULI_save_cur
                        ldy #ULI_STATE_CUR
                        lda ULI_cur
                        sta (ULI_ptr),y
                        iny
                        lda ULI_cur+1
                        sta (ULI_ptr),y
                        iny
                        lda ULI_cur_bank
                        sta (ULI_ptr),y
                        rts
.endproc

; ULI_at_end - Check if current position equals end position
;   In: ULI_ptr valid, ULI_cur/ULI_cur_bank loaded
;       BANKSEL::RAM    - must be set to iterator state bank
;  Out: Z set if at end
.proc ULI_at_end
                        ldy #ULI_STATE_END
                        lda ULI_cur
                        cmp (ULI_ptr),y
                        bne @not_equal
                        iny
                        lda ULI_cur+1
                        cmp (ULI_ptr),y
                        bne @not_equal
                        iny
                        lda ULI_cur_bank
                        cmp (ULI_ptr),y
                        bne @not_equal

                        ; cur == end. Check if LIST/STRING type needs terminal MB verification
                        lda (ULI_ptr)           ; type_format
                        and #$0F
                        cmp #ULITYP::LIST
                        beq @check_term_mb
                        cmp #ULITYP::STRING
                        bne @is_at_end          ; not LIST/STRING -> truly at end

                        ; LIST/STRING: check if CUR_MB == TERM_MB
@check_term_mb:
                        ldy #ULI_STATE_CUR_MB
                        lda (ULI_ptr),y
                        tax                     ; X = CUR_MB lo
                        ldy #ULI_STATE_TERM_MB
                        txa
                        cmp (ULI_ptr),y         ; compare lo bytes
                        bne @not_at_end
                        ldy #ULI_STATE_CUR_MB+1
                        lda (ULI_ptr),y
                        ldy #ULI_STATE_TERM_MB+1
                        cmp (ULI_ptr),y         ; compare hi bytes
                        beq @is_at_end          ; CUR_MB == TERM_MB -> truly at end

@not_at_end:            lda #1                  ; clear Z flag
                        rts
@not_equal:             rts                     ; Z already clear from cmp
@is_at_end:             lda #0                  ; set Z flag
                        rts
.endproc

; ULI_at_start - Check if current position equals start position
;   In: ULI_ptr valid, ULI_cur/ULI_cur_bank loaded
;       BANKSEL::RAM    - must be set to iterator state bank
;  Out: Z set if at start
.proc ULI_at_start
                        ldy #ULI_STATE_START
                        lda ULI_cur
                        cmp (ULI_ptr),y
                        bne @done
                        iny
                        lda ULI_cur+1
                        cmp (ULI_ptr),y
                        bne @done
                        iny
                        lda ULI_cur_bank
                        cmp (ULI_ptr),y
@done:                  rts
.endproc

; ULI_get_step - Get step size for a format
;   In: A               - type_format byte
;  Out: A               - step size in bytes (0 for variable-length formats)
.proc ULI_get_step
                        and #$70
                        lsr
                        lsr
                        lsr
                        lsr
                        tax
                        lda ULI_step_sizes,x
                        rts
.endproc

; ULI_step_forward - Step in the forward direction (respects REVERSE flag)
;   In: A               - number of bytes to step
;       ULI_type_format  - cached type_format (bit 7 = REVERSE)
;  Out: ULI_cur updated
.proc ULI_step_forward
                        bit ULI_type_format
                        bmi ULI_dec_cur
                        bra ULI_inc_cur
.endproc

; ULI_step_backward - Step in the backward direction (respects REVERSE flag)
;   In: A               - number of bytes to step
;       ULI_type_format  - cached type_format (bit 7 = REVERSE)
;  Out: ULI_cur updated
.proc ULI_step_backward
                        bit ULI_type_format
                        bmi ULI_inc_cur
                        bra ULI_dec_cur
.endproc

; ULI_inc_cur - Advance current position by A bytes
;   In: A               - number of bytes to advance
;       ULI_cur loaded
;  Out: ULI_cur updated
.proc ULI_inc_cur
                        clc
                        adc ULI_cur
                        sta ULI_cur
                        bcc @done
                        inc ULI_cur+1
                        bne @done
                        inc ULI_cur_bank
@done:                  rts
.endproc

; ULI_dec_cur - Rewind current position by A bytes
;   In: A               - number of bytes to rewind
;       ULI_cur loaded
;  Out: ULI_cur updated
.proc ULI_dec_cur
                        eor #$FF                ; negate: ~step
                        sec
                        adc ULI_cur             ; ULI_cur + ~step + 1 = ULI_cur - step
                        sta ULI_cur
                        bcs @done               ; carry set = no borrow
                        dec ULI_cur+1
                        lda ULI_cur+1
                        cmp #$FF
                        bne @done
                        dec ULI_cur_bank
@done:                  rts
.endproc

; ULI_do_fetch - Read value at current position, dispatching by type and format
;   In: ULI_type_format  - cached type_format
;       ULI_cur/ULI_cur_bank - current address
;  Out: A/ULI_scratch    - value (BYTE), or r0/r1 (WORD+)
;       BANKSEL::RAM     - changed to target bank (BRP/MEM only)
.proc ULI_do_fetch
                        lda ULI_type_format
                        and #$0F
                        cmp #ULITYP::VRAM
                        beq @vram

                        ; --- BRP/MEM path ---
                        lda ULI_cur_bank
                        sta BANKSEL::RAM

                        lda ULI_type_format
                        and #$70
                        beq @brp_byte
                        cmp #ULIFMT::UTF8
                        beq @utf8_fetch

                        ; Multi-byte or FLOAT — shared path via indirect pointer
                        stz UL_temp_h           ; high byte = 0 (page 0 targets)
                        ldx #<gREG::r0L         ; default: r0L ($02)
                        cmp #ULIFMT::FLOAT
                        bne :+
                        ldx #FACEXP             ; FLOAT: FACEXP ($C3)
:                       stx UL_temp_l

                        lda ULI_type_format
                        jsr ULI_get_step
                        tax
                        ldy #0
@brp_loop:              lda (ULI_cur),y
                        sta (UL_temp_l),y
                        iny
                        dex
                        bne @brp_loop
                        lda gREG::r0L           ; for ULI_scratch (harmless for FLOAT)
                        sta ULI_scratch
                        rts

@brp_byte:              lda (ULI_cur)
                        sta ULI_scratch
                        rts

@utf8_fetch:            jmp ULI_utf8_fetch

@vram:                  ; --- VRAM path ---
                        stz VERA::CTRL
                        lda ULI_cur
                        sta VERA::ADDR
                        lda ULI_cur+1
                        sta VERA::ADDR+1
                        lda ULI_cur_bank
                        ora #VERA::INC1
                        sta VERA::ADDR+2

                        lda ULI_type_format
                        and #$70
                        beq @vram_byte

                        ; Multi-byte VRAM or FLOAT
                        stz UL_temp_h
                        ldx #<gREG::r0L
                        cmp #ULIFMT::FLOAT
                        bne :+
                        ldx #FACEXP
:                       stx UL_temp_l

                        lda ULI_type_format
                        jsr ULI_get_step
                        tax
                        ldy #0
@vram_loop:             lda VERA::DATA0
                        sta (UL_temp_l),y
                        iny
                        dex
                        bne @vram_loop
                        lda gREG::r0L
                        sta ULI_scratch
                        rts

@vram_byte:             lda VERA::DATA0
                        sta ULI_scratch
                        rts
.endproc

; ULI_do_store - Write value at current position, dispatching by type and format
;   In: ULI_type_format  - cached type_format
;       ULI_cur/ULI_cur_bank - current address
;       ULI_scratch      - value (BYTE), or r0/r1 (WORD+)
;  Out: BANKSEL::RAM     - changed to target bank (BRP/MEM only)
.proc ULI_do_store
                        lda ULI_type_format
                        and #$0F
                        cmp #ULITYP::VRAM
                        beq @vram

                        ; --- BRP/MEM path ---
                        lda ULI_cur_bank
                        sta BANKSEL::RAM

                        lda ULI_type_format
                        and #$70
                        beq @brp_byte
                        cmp #ULIFMT::UTF8
                        beq @utf8_store

                        ; Multi-byte or FLOAT — shared path via indirect pointer
                        stz UL_temp_h
                        ldx #<gREG::r0L
                        cmp #ULIFMT::FLOAT
                        bne :+
                        ldx #FACEXP
:                       stx UL_temp_l

                        lda ULI_type_format
                        jsr ULI_get_step
                        tax
                        ldy #0
@brp_loop:              lda (UL_temp_l),y
                        sta (ULI_cur),y
                        iny
                        dex
                        bne @brp_loop
                        rts

@brp_byte:              lda ULI_scratch
                        sta (ULI_cur)
                        rts

@utf8_store:            jmp ULI_utf8_store

@vram:                  ; --- VRAM path ---
                        stz VERA::CTRL
                        lda ULI_cur
                        sta VERA::ADDR
                        lda ULI_cur+1
                        sta VERA::ADDR+1
                        lda ULI_cur_bank
                        ora #VERA::INC1
                        sta VERA::ADDR+2

                        lda ULI_type_format
                        and #$70
                        beq @vram_byte

                        ; Multi-byte VRAM or FLOAT
                        stz UL_temp_h
                        ldx #<gREG::r0L
                        cmp #ULIFMT::FLOAT
                        bne :+
                        ldx #FACEXP
:                       stx UL_temp_l

                        lda ULI_type_format
                        jsr ULI_get_step
                        tax
                        ldy #0
@vram_loop:             lda (UL_temp_l),y
                        sta VERA::DATA0
                        iny
                        dex
                        bne @vram_loop
                        rts

@vram_byte:             lda ULI_scratch
                        sta VERA::DATA0
                        rts
.endproc

UL_BSS

ULI_cur_bank:   .res 1          ; current target bank
ULI_state_bank: .res 1          ; bank where iterator state BRP lives
ULI_type_format:.res 1          ; cached type_format for current operation
ULI_scratch:    .res 8          ; scratch space for iterator operations
