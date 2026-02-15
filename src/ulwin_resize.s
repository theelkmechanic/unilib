; ulwin_resize - Resize a window

.include "unilib_impl.inc"

UL_CODE

; ulwin_resize - Resize a window
;   In: A               - Window handle
;       X               - New content area width (columns)
;       Y               - New content area height (lines)
;  Out: carry           - Set on error
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

                        ; Calculate new end column/line
                        lda ULW_WINDOW_COPY::scol
                        clc
                        adc ULWRZ_new_ncol
                        sta ULWRZ_new_ecol
                        lda ULW_WINDOW_COPY::slin
                        clc
                        adc ULWRZ_new_nlin
                        sta ULWRZ_new_elin

                        ; Validate new size fits on screen (including border)
                        lda ULWRZ_new_ecol
                        ldy ULWRZ_new_elin
                        bit ULW_WINDOW_COPY::flags
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
                        lda ULW_WINDOW_COPY::scol
                        sta ULWR_dest
                        ldx ULW_WINDOW_COPY::slin
                        ldy ULW_WINDOW_COPY::ncol
                        lda ULW_WINDOW_COPY::nlin
                        bit ULW_WINDOW_COPY::flags
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
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        inx
                        inx
                        inc
                        inc
:                       XCALL ulmath_umul8_8, UNILIB_BANK_A

                        ; Allocate new color buffer
                        clc                     ; don't clear (we'll copy/fill)
                        XCALL ulmem_alloc, UNILIB_BANK_A
                        bcc :+
                        jmp @alloc_fail
:                       stx ULWRZ_new_colorbuf
                        sty ULWRZ_new_colorbuf+1

                        ; Calculate new char buffer size: color_size * 3
                        ldx ULWRZ_new_nlin
                        lda ULWRZ_new_ncol
                        bit ULW_WINDOW_COPY::flags
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

                        ; Clear new buffers (fill with spaces/default color)
                        ; We don't copy old content for simplicity - just clear and redraw border
                        ; (Content copying across different widths is very complex)

                        ; Update window struct: free old buffers, install new ones
                        lda ULWRZ_handle
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Free old char buffer
                        ldy #ULW_WINDOW::charbuf
                        jsr ULW_freebuf
                        ; Free old color buffer
                        lda ULWRZ_handle
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        ldy #ULW_WINDOW::colorbuf
                        jsr ULW_freebuf

                        ; Install new buffers
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
                        ; Get fresh window copy and clear/redraw
                        lda ULWRZ_handle
                        jsr ULW_getwinstruct
                        jsr ULW_clear
                        jsr ULW_drawborder

                        ; Update occlusion and mark new region dirty
                        jsr ULW_update_occlusion

                        lda ULW_WINDOW_COPY::scol
                        sta ULWR_dest
                        ldx ULW_WINDOW_COPY::slin
                        ldy ULW_WINDOW_COPY::ncol
                        lda ULW_WINDOW_COPY::nlin
                        bit ULW_WINDOW_COPY::flags
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
