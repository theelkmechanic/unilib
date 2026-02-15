; ulwin_joincolumns - Join two windows horizontally

.include "unilib_impl.inc"

UL_CODE

; ulwin_joincolumns - Join two windows horizontally
;   In: X               - First window (left)
;       Y               - Second window (right)
;   Out: A              - Joined window handle (first window, carry clear)
;                         or $FF on error (carry set)
;   First window is resized to combined width, second window is closed.
;   Windows must be same height and result must fit on screen.
;   Note: Content is not preserved; joined window is cleared.
.proc ulwin_joincolumns
                        ; Don't join screen window
                        cpx #0
                        beq @error_ret
                        cpy #0
                        beq @error_ret

                        ; Save params
                        stx ULWJC_first
                        sty ULWJC_second
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Get first window info
                        lda ULWJC_first
                        jsr ULW_getwinstruct
                        lda ULW_WINDOW_COPY::nlin
                        sta ULWJC_nlin
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWJC_first_ncol

                        ; Get second window info
                        lda ULWJC_second
                        jsr ULW_getwinstruct
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWJC_second_ncol

                        ; Validate: same height
                        lda ULW_WINDOW_COPY::nlin
                        cmp ULWJC_nlin
                        bne @bad_params

                        ; Calculate combined width
                        lda ULWJC_first_ncol
                        clc
                        adc ULWJC_second_ncol
                        sta ULWJC_combined_ncol
                        bcs @bad_params           ; overflow

                        ; Close the second window first
                        lda ULWJC_second
                        jsr ulwin_close

                        ; Select the first window
                        lda ULWJC_first
                        jsr ulwin_select

                        ; Resize first window to combined width
                        lda ULWJC_first
                        ldx ULWJC_combined_ncol
                        ldy ULWJC_nlin
                        jsr ulwin_resize
                        bcc @success

                        ; Resize failed
                        lda #ULERR::OUT_OF_MEMORY
                        sta UL_lasterr
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda #$FF
                        sec
                        rts

@bad_params:            lda #ULERR::INVALID_PARAMS
                        sta UL_lasterr
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
@error_ret:             lda #$FF
                        sec
                        rts

@success:               ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULWJC_first
                        clc
                        rts
.endproc

UL_BSS

ULWJC_first:            .res 1
ULWJC_second:           .res 1
ULWJC_nlin:             .res 1
ULWJC_first_ncol:       .res 1
ULWJC_second_ncol:      .res 1
ULWJC_combined_ncol:    .res 1
