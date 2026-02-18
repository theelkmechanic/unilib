; ulwin_resize - Resize a window (content-preserving)

.include "unilib_impl.inc"

UL_CODE

; ulwin_resize - Resize a window
;   In: A               - Window handle
;       X               - New content area width (columns)
;       Y               - New content area height (lines)
;  Out: carry           - Set on error
;
; Preserves existing window content in the intersection of old and new sizes.
; New rows/columns are cleared; border is redrawn for new dimensions.
; Content is relayed through UL_SCRATCH_BASE ($0600) one row at a time.
.proc ulwin_resize
                        ; Don't resize the screen window
                        cmp #0
                        beq @error_exit

                        ; Save params
                        sta ULWRZ_handle
                        stx ULWRZ_new_ncol
                        sty ULWRZ_new_nlin
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Get window structure
                        lda ULWRZ_handle
                        jsr ULW_getwinstruct

                        ; Save old dimensions and buffer BRPs for content copy
                        lda ULWC_ncol
                        sta ULWRZ_old_ncol
                        lda ULWC_nlin
                        sta ULWRZ_old_nlin
                        lda ULWC_charbuf
                        sta ULWRZ_old_charbuf
                        lda ULWC_charbuf+1
                        sta ULWRZ_old_charbuf+1
                        lda ULWC_colorbuf
                        sta ULWRZ_old_colorbuf
                        lda ULWC_colorbuf+1
                        sta ULWRZ_old_colorbuf+1
                        lda ULWC_flags
                        sta ULWRZ_flags

                        ; Calculate new end column/line
                        lda ULWC_scol
                        clc
                        adc ULWRZ_new_ncol
                        sta ULWRZ_new_ecol
                        lda ULWC_slin
                        clc
                        adc ULWRZ_new_nlin
                        sta ULWRZ_new_elin

                        ; Validate new size fits on screen (including border)
                        lda ULWRZ_new_ecol
                        ldy ULWRZ_new_elin
                        bit ULWRZ_flags
                        bpl :+
                        inc
                        iny
:                       cmp ULW_screen_size
                        bcs @bad_params
                        cpy ULW_screen_size+1
                        bcc @params_ok
@bad_params:            lda #ULERR::INVALID_PARAMS
                        sta UL_lasterr
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
@error_exit:            sec
                        rts

@params_ok:             ; Mark old position dirty (before resize)
                        lda ULWC_scol
                        sta ULWR_dest
                        ldx ULWC_slin
                        ldy ULWC_ncol
                        lda ULWC_nlin
                        bit ULWC_flags
                        bpl :+
                        dec ULWR_dest
                        dex
                        iny
                        iny
                        inc
                        inc
:                       stx ULWR_dest+1
                        sty ULWR_destsize
                        sta ULWR_destsize+1
                        jsr ULW_set_dirty_rect

                        ; Calculate new color buffer size: total_cols * total_lines
                        ; (including border if present)
                        ldx ULWRZ_new_nlin
                        lda ULWRZ_new_ncol
                        bit ULWRZ_flags
                        bpl :+
                        inx
                        inx
                        inc
                        inc
:                       XCALL ulmath_umul8_8, UNILIB_BANK_A

                        ; Allocate new color buffer
                        clc
                        XCALL ulmem_alloc, UNILIB_BANK_A
                        bcc :+
                        jmp @alloc_fail
:                       stx ULWRZ_new_colorbuf
                        sty ULWRZ_new_colorbuf+1

                        ; Calculate new char buffer size: color_size * 3
                        ldx ULWRZ_new_nlin
                        lda ULWRZ_new_ncol
                        bit ULWRZ_flags
                        bpl :+
                        inx
                        inx
                        inc
                        inc
:                       XCALL ulmath_umul8_8, UNILIB_BANK_A
                        lda #3
                        XCALL ulmath_umul16_8, UNILIB_BANK_A
                        clc
                        XCALL ulmem_alloc, UNILIB_BANK_A
                        bcc :+
                        jmp @free_color_and_fail
:                       stx ULWRZ_new_charbuf
                        sty ULWRZ_new_charbuf+1

                        ; Install new buffers in window struct (don't free old yet)
                        lda ULWRZ_handle
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ldy #ULW_WINDOW::charbuf
                        lda ULWRZ_new_charbuf
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULWRZ_new_charbuf+1
                        sta (ULW_scratch_fptr),y

                        ldy #ULW_WINDOW::colorbuf
                        lda ULWRZ_new_colorbuf
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULWRZ_new_colorbuf+1
                        sta (ULW_scratch_fptr),y

                        ; Update size fields
                        ldy #ULW_WINDOW::ncol
                        lda ULWRZ_new_ncol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULWRZ_new_nlin
                        sta (ULW_scratch_fptr),y
                        ldy #ULW_WINDOW::ecol
                        lda ULWRZ_new_ecol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULWRZ_new_elin
                        sta (ULW_scratch_fptr),y

                        ; Clip cursor to new bounds
                        ldy #ULW_WINDOW::ccol
                        lda (ULW_scratch_fptr),y
                        cmp ULWRZ_new_ncol
                        bcc :+
                        lda ULWRZ_new_ncol
                        dec
                        sta (ULW_scratch_fptr),y
:                       iny
                        lda (ULW_scratch_fptr),y
                        cmp ULWRZ_new_nlin
                        bcc :+
                        lda ULWRZ_new_nlin
                        dec
                        sta (ULW_scratch_fptr),y
:
                        ; Clear new buffers and draw border on new dimensions
                        lda ULWRZ_handle
                        jsr ULW_getwinstruct
                        jsr ULW_clear
                        jsr ULW_drawborder

                        ; --- Content preservation: copy from old to new buffers ---

                        ; Compute copy dimensions = intersection of old and new
                        lda ULWRZ_old_ncol
                        cmp ULWRZ_new_ncol
                        bcc :+
                        lda ULWRZ_new_ncol
:                       sta ULWRZ_copy_cols
                        lda ULWRZ_old_nlin
                        cmp ULWRZ_new_nlin
                        bcc :+
                        lda ULWRZ_new_nlin
:                       sta ULWRZ_copy_lines

                        ; Skip copy if nothing to copy
                        lda ULWRZ_copy_cols
                        bne :+
                        jmp @copy_done
:                       lda ULWRZ_copy_lines
                        bne :+
                        jmp @copy_done
:

                        ; --- Copy color buffer (1 byte per cell) ---

                        ; Access old color buffer base address
                        ldx ULWRZ_old_colorbuf
                        ldy ULWRZ_old_colorbuf+1
                        XCALL ulmem_access, UNILIB_BANK_A
                        stx ULWRZ_src_ptr
                        sty ULWRZ_src_ptr+1
                        lda BANKSEL::RAM
                        sta ULWRZ_src_bank

                        ; Compute old color stride and content start
                        lda ULWRZ_old_ncol
                        bit ULWRZ_flags
                        bpl @col_old_nb
                        clc
                        adc #2                  ; bordered: stride = ncol + 2
                        sta ULWRZ_old_stride
                        ; src_ptr += stride + 1 (skip top border row + left border col)
                        clc
                        adc ULWRZ_src_ptr
                        sta ULWRZ_src_ptr
                        bcc :+
                        inc ULWRZ_src_ptr+1
:                       inc ULWRZ_src_ptr
                        bne :+
                        inc ULWRZ_src_ptr+1
:                       bra @col_old_done
@col_old_nb:            sta ULWRZ_old_stride    ; non-bordered: stride = ncol
@col_old_done:
                        ; Access new color buffer base address
                        ldx ULWRZ_new_colorbuf
                        ldy ULWRZ_new_colorbuf+1
                        XCALL ulmem_access, UNILIB_BANK_A
                        stx ULWRZ_dst_ptr
                        sty ULWRZ_dst_ptr+1
                        lda BANKSEL::RAM
                        sta ULWRZ_dst_bank

                        ; Compute new color stride and content start
                        lda ULWRZ_new_ncol
                        bit ULWRZ_flags
                        bpl @col_new_nb
                        clc
                        adc #2
                        sta ULWRZ_new_stride
                        clc
                        adc ULWRZ_dst_ptr
                        sta ULWRZ_dst_ptr
                        bcc :+
                        inc ULWRZ_dst_ptr+1
:                       inc ULWRZ_dst_ptr
                        bne :+
                        inc ULWRZ_dst_ptr+1
:                       bra @col_new_done
@col_new_nb:            sta ULWRZ_new_stride
@col_new_done:
                        ; Copy bytes per row = copy_cols (bpc=1)
                        lda ULWRZ_copy_cols
                        sta ULWRZ_copy_bytes
                        jsr @copy_buffer

                        ; --- Copy char buffer (3 bytes per cell) ---

                        ; Access old char buffer base address
                        ldx ULWRZ_old_charbuf
                        ldy ULWRZ_old_charbuf+1
                        XCALL ulmem_access, UNILIB_BANK_A
                        stx ULWRZ_src_ptr
                        sty ULWRZ_src_ptr+1
                        lda BANKSEL::RAM
                        sta ULWRZ_src_bank

                        ; Compute old char stride = total_cols * 3
                        lda ULWRZ_old_ncol
                        bit ULWRZ_flags
                        bpl :+
                        clc
                        adc #2
:                       sta ULWRZ_old_stride    ; temp = total_cols
                        asl                     ; *2
                        clc
                        adc ULWRZ_old_stride    ; *3
                        sta ULWRZ_old_stride

                        ; Bordered: src_ptr += stride + 3 (skip border row + left border col)
                        bit ULWRZ_flags
                        bpl @chr_old_nb
                        lda ULWRZ_src_ptr
                        clc
                        adc ULWRZ_old_stride
                        sta ULWRZ_src_ptr
                        bcc :+
                        inc ULWRZ_src_ptr+1
:                       lda ULWRZ_src_ptr
                        clc
                        adc #3
                        sta ULWRZ_src_ptr
                        bcc :+
                        inc ULWRZ_src_ptr+1
:
@chr_old_nb:
                        ; Access new char buffer base address
                        ldx ULWRZ_new_charbuf
                        ldy ULWRZ_new_charbuf+1
                        XCALL ulmem_access, UNILIB_BANK_A
                        stx ULWRZ_dst_ptr
                        sty ULWRZ_dst_ptr+1
                        lda BANKSEL::RAM
                        sta ULWRZ_dst_bank

                        ; Compute new char stride = total_cols * 3
                        lda ULWRZ_new_ncol
                        bit ULWRZ_flags
                        bpl :+
                        clc
                        adc #2
:                       sta ULWRZ_new_stride
                        asl
                        clc
                        adc ULWRZ_new_stride
                        sta ULWRZ_new_stride

                        ; Bordered: dst_ptr += stride + 3
                        bit ULWRZ_flags
                        bpl @chr_new_nb
                        lda ULWRZ_dst_ptr
                        clc
                        adc ULWRZ_new_stride
                        sta ULWRZ_dst_ptr
                        bcc :+
                        inc ULWRZ_dst_ptr+1
:                       lda ULWRZ_dst_ptr
                        clc
                        adc #3
                        sta ULWRZ_dst_ptr
                        bcc :+
                        inc ULWRZ_dst_ptr+1
:
@chr_new_nb:
                        ; Copy bytes per row = copy_cols * 3
                        lda ULWRZ_copy_cols
                        asl                     ; *2
                        clc
                        adc ULWRZ_copy_cols     ; *3
                        sta ULWRZ_copy_bytes
                        jsr @copy_buffer

@copy_done:
                        ; Free old buffers (now safe - content has been copied)
                        ldx ULWRZ_old_charbuf
                        ldy ULWRZ_old_charbuf+1
                        XCALL ulmem_free, UNILIB_BANK_A
                        ldx ULWRZ_old_colorbuf
                        ldy ULWRZ_old_colorbuf+1
                        XCALL ulmem_free, UNILIB_BANK_A

                        ; Refresh window copy (char relay may have trashed ULW_WINDOW_COPY)
                        lda ULWRZ_handle
                        jsr ULW_getwinstruct

                        ; Update occlusion and mark new region dirty
                        jsr ULW_update_occlusion

                        lda ULWC_scol
                        sta ULWR_dest
                        ldx ULWC_slin
                        ldy ULWC_ncol
                        lda ULWC_nlin
                        bit ULWC_flags
                        bpl :+
                        dec ULWR_dest
                        dex
                        iny
                        iny
                        inc
                        inc
:                       stx ULWR_dest+1
                        sty ULWR_destsize
                        sta ULWR_destsize+1
                        jsr ULW_set_dirty_rect

                        ; Restore and return success
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULWRZ_handle
                        clc
                        rts

; --- Subroutine: copy content rows through $0600 relay buffer ---
; Copies ULWRZ_copy_lines rows, each ULWRZ_copy_bytes wide, from
; old buffer (src_ptr/src_bank) to new buffer (dst_ptr/dst_bank).
; Advances src/dst pointers by old/new stride after each row.
; Clobbers: A, X, Y, UL_varptr
@copy_buffer:
                        lda ULWRZ_copy_lines
                        sta ULWRZ_cur_row

@cb_row:                ; Copy row from source to $0600 relay
                        lda ULWRZ_src_bank
                        sta BANKSEL::RAM
                        lda ULWRZ_src_ptr
                        sta UL_varptr
                        lda ULWRZ_src_ptr+1
                        sta UL_varptr+1
                        ldy #0
@cb_src:                lda (UL_varptr),y
                        sta UL_SCRATCH_BASE,y
                        iny
                        cpy ULWRZ_copy_bytes
                        bne @cb_src

                        ; Copy from $0600 relay to dest
                        lda ULWRZ_dst_bank
                        sta BANKSEL::RAM
                        lda ULWRZ_dst_ptr
                        sta UL_varptr
                        lda ULWRZ_dst_ptr+1
                        sta UL_varptr+1
                        ldy #0
@cb_dst:                lda UL_SCRATCH_BASE,y
                        sta (UL_varptr),y
                        iny
                        cpy ULWRZ_copy_bytes
                        bne @cb_dst

                        ; Advance source ptr by old stride
                        lda ULWRZ_src_ptr
                        clc
                        adc ULWRZ_old_stride
                        sta ULWRZ_src_ptr
                        bcc :+
                        inc ULWRZ_src_ptr+1
:
                        ; Advance dest ptr by new stride
                        lda ULWRZ_dst_ptr
                        clc
                        adc ULWRZ_new_stride
                        sta ULWRZ_dst_ptr
                        bcc :+
                        inc ULWRZ_dst_ptr+1
:
                        dec ULWRZ_cur_row
                        bne @cb_row
                        rts

@free_color_and_fail:   ldx ULWRZ_new_colorbuf
                        ldy ULWRZ_new_colorbuf+1
                        XCALL ulmem_free, UNILIB_BANK_A
@alloc_fail:            lda #ULERR::OUT_OF_MEMORY
                        sta UL_lasterr
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts
.endproc

UL_BSS

ULWRZ_handle:           .res 1
ULWRZ_new_ncol:         .res 1
ULWRZ_new_nlin:         .res 1
ULWRZ_new_ecol:         .res 1
ULWRZ_new_elin:         .res 1
ULWRZ_new_charbuf:      .res 2
ULWRZ_new_colorbuf:     .res 2
ULWRZ_old_ncol:         .res 1
ULWRZ_old_nlin:         .res 1
ULWRZ_old_charbuf:      .res 2
ULWRZ_old_colorbuf:     .res 2
ULWRZ_flags:            .res 1
ULWRZ_copy_cols:        .res 1
ULWRZ_copy_lines:       .res 1
ULWRZ_copy_bytes:       .res 1
ULWRZ_old_stride:       .res 1
ULWRZ_new_stride:       .res 1
ULWRZ_src_ptr:          .res 2
ULWRZ_dst_ptr:          .res 2
ULWRZ_src_bank:         .res 1
ULWRZ_dst_bank:         .res 1
ULWRZ_cur_row:          .res 1
