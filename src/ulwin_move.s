; ulwin_move - Move a window to a new position

.include "unilib_impl.inc"

UL_CODE

; ulwin_move - Move a window
;   In: A               - Window handle
;       X               - New screen start column of window content area
;       Y               - New screen start line of window content area
;  Out: carry           - Set on error (off-screen)
.proc ulwin_move
                        ; Don't move the screen window
                        cmp #0
                        beq @error

                        ; Save params
                        sta ULWMV_handle
                        stx ULWMV_new_col
                        sty ULWMV_new_lin
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Get window structure
                        lda ULWMV_handle
                        jsr ULW_getwinstruct

                        ; Calculate new end column/line
                        lda ULWMV_new_col
                        clc
                        adc ULW_WINDOW_COPY::ncol
                        sta ULWMV_new_ecol
                        lda ULWMV_new_lin
                        clc
                        adc ULW_WINDOW_COPY::nlin
                        sta ULWMV_new_elin

                        ; Validate new position fits on screen (including border)
                        lda ULWMV_new_col
                        ldx ULWMV_new_lin
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        dec                     ; border starts 1 earlier
                        dex
:                       cmp #0
                        bmi @bad_params
                        cpx #0
                        bmi @bad_params

                        lda ULWMV_new_ecol
                        ldy ULWMV_new_elin
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        inc                     ; border extends 1 further
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
@error:                 sec
                        rts

@params_ok:             ; Mark old position dirty
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

                        ; Update window struct with new position
                        lda ULWMV_handle
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ldy #ULW_WINDOW::scol
                        lda ULWMV_new_col
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULWMV_new_lin
                        sta (ULW_scratch_fptr),y
                        ldy #ULW_WINDOW::ecol
                        lda ULWMV_new_ecol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULWMV_new_elin
                        sta (ULW_scratch_fptr),y

                        ; Update occlusion
                        jsr ULW_update_occlusion

                        ; Mark new position dirty
                        lda ULWMV_handle
                        jsr ULW_getwinstruct
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
                        lda ULWMV_handle
                        clc
                        rts
.endproc

UL_BSS

ULWMV_handle:           .res 1
ULWMV_new_col:          .res 1
ULWMV_new_lin:          .res 1
ULWMV_new_ecol:         .res 1
ULWMV_new_elin:         .res 1
