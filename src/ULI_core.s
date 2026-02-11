.include "unilib_impl.inc"

.segment "EXTZP" : zeropage

; These zero-page pointers are shared with ULW_utils (as UL_src_fptr/UL_dst_fptr)
; and other modules. They are scratch pointers, not preserved across calls.
ULI_ptr:
UL_dst_fptr:    .res 2          ; pointer to iterator state / destination pointer
ULI_cur:
UL_src_fptr:    .res 2          ; current target address / source pointer

.code

; Format step sizes indexed by (format >> 4)
; BYTE=1, WORD=2, TBYTE=3, DWORD=4, FLOAT=5, UTF8=0(variable), STRTBL=0(variable)
ULI_step_sizes: .byte 1, 2, 3, 4, 5, 0, 0, 0

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
@done:                  rts
.endproc

; ULI_dec_cur - Rewind current position by A bytes
;   In: A               - number of bytes to rewind
;       ULI_cur loaded
;  Out: ULI_cur updated
.proc ULI_dec_cur
                        sta ULI_scratch
                        lda ULI_cur
                        sec
                        sbc ULI_scratch
                        sta ULI_cur
                        bcs @done
                        dec ULI_cur+1
@done:                  rts
.endproc

.bss

ULI_cur_bank:   .res 1          ; current target bank
ULI_state_bank: .res 1          ; bank where iterator state BRP lives
ULI_scratch:    .res 8          ; scratch space for iterator operations
