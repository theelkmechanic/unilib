; ulwin_joinlines - Join two windows vertically

.include "unilib_impl.inc"

.define ULWJL_first          ULW_sj_scratch+0
.define ULWJL_second         ULW_sj_scratch+1
.define ULWJL_ncol           ULW_sj_scratch+2
.define ULWJL_first_nlin     ULW_sj_scratch+3
.define ULWJL_second_nlin    ULW_sj_scratch+4
.define ULWJL_combined_nlin  ULW_sj_scratch+5

UL_CODE

; ulwin_joinlines - Join two windows vertically
;   In: X               - First window (top)
;       Y               - Second window (bottom)
;   Out: A              - Joined window handle (first window, carry clear)
;                         or $FF on error (carry set)
;   First window is resized to combined height, second window is closed.
;   Windows must be same width and result must fit on screen.
;   Note: Content is not preserved; joined window is cleared.
.proc ulwin_joinlines
                        ; Don't join screen window
                        cpx #0
                        beq @error_ret
                        cpy #0
                        beq @error_ret

                        ; Save params
                        stx ULWJL_first
                        sty ULWJL_second
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Get first window info
                        lda ULWJL_first
                        jsr ULW_getwinstruct
                        lda ULWC_ncol
                        sta ULWJL_ncol
                        lda ULWC_nlin
                        sta ULWJL_first_nlin

                        ; Get second window info
                        lda ULWJL_second
                        jsr ULW_getwinstruct
                        lda ULWC_nlin
                        sta ULWJL_second_nlin

                        ; Validate: same width
                        lda ULWC_ncol
                        cmp ULWJL_ncol
                        bne @bad_params

                        ; Calculate combined height
                        lda ULWJL_first_nlin
                        clc
                        adc ULWJL_second_nlin
                        sta ULWJL_combined_nlin
                        bcs @bad_params           ; overflow

                        ; Close the second window first
                        lda ULWJL_second
                        jsr ulwin_close

                        ; Select the first window
                        lda ULWJL_first
                        jsr ulwin_select

                        ; Resize first window to combined height
                        lda ULWJL_first
                        ldx ULWJL_ncol
                        ldy ULWJL_combined_nlin
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
                        lda ULWJL_first
                        clc
                        rts
.endproc

