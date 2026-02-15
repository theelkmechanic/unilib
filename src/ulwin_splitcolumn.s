; ulwin_splitcolumn - Split a window into two at specified column

.include "unilib_impl.inc"

UL_CODE

; ulwin_splitcolumn - Split a window into two at specified column
;   In: A               - Window handle
;       X               - Split column (new window starts at this column)
;   Out: A              - New window handle (or $FF on error, carry set)
;   The original window keeps columns 0 through split-1.
;   The new window gets columns split through ncol-1.
;   New window is selected and returned.
;   Note: Content is not preserved; both windows are cleared.
.proc ulwin_splitcolumn
                        ; Don't split the screen window
                        cmp #0
                        beq @error_ret

                        ; Save params
                        sta ULWSC_handle
                        stx ULWSC_splitcol
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Get window structure
                        lda ULWSC_handle
                        jsr ULW_getwinstruct

                        ; Validate: split column must be > 0 and < ncol
                        lda ULWSC_splitcol
                        beq @bad_params
                        cmp ULW_WINDOW_COPY::ncol
                        bcc @params_ok

@bad_params:            lda #ULERR::INVALID_PARAMS
                        sta UL_lasterr
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
@error_ret:             lda #$FF
                        sec
                        rts

@params_ok:             ; Calculate new window dimensions
                        ; Right window: starts at scol+splitcol, width = ncol-splitcol
                        lda ULW_WINDOW_COPY::ncol
                        sec
                        sbc ULWSC_splitcol
                        sta ULWSC_right_ncol

                        lda ULW_WINDOW_COPY::scol
                        clc
                        adc ULWSC_splitcol
                        sta ULWSC_right_scol

                        ; Save original window properties for the new window
                        lda ULW_WINDOW_COPY::slin
                        sta ULWSC_slin
                        lda ULW_WINDOW_COPY::nlin
                        sta ULWSC_nlin
                        lda ULW_WINDOW_COPY::flags
                        sta ULWSC_flags
                        lda ULW_WINDOW_COPY::color
                        sta ULWSC_color

                        ; Resize original window to left portion (splitcol columns)
                        lda ULWSC_handle
                        ldx ULWSC_splitcol
                        ldy ULW_WINDOW_COPY::nlin
                        jsr ulwin_resize
                        bcc :+
                        jmp @alloc_fail
:
                        ; Open new window for the right portion
                        lda ULWSC_right_scol
                        sta gREG::r0L
                        lda ULWSC_slin
                        sta gREG::r0H
                        lda ULWSC_right_ncol
                        sta gREG::r1L
                        lda ULWSC_nlin
                        sta gREG::r1H

                        ; Color: split nibbles
                        lda ULWSC_color
                        and #$0F
                        sta gREG::r2L
                        lda ULWSC_color
                        lsr
                        lsr
                        lsr
                        lsr
                        sta gREG::r2H

                        ; No title
                        stz gREG::r3L
                        stz gREG::r3H

                        ; Same flags
                        lda ULWSC_flags
                        sta gREG::r4H

                        ; Open the new window
                        jsr ulwin_open
                        cmp #0
                        bne @open_ok

                        ; Open failed
                        jmp @alloc_fail

@open_ok:               sta ULWSC_new_handle

                        ; Restore and return new window handle
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULWSC_new_handle
                        clc
                        rts

@alloc_fail:            lda #ULERR::OUT_OF_MEMORY
                        sta UL_lasterr
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda #$FF
                        sec
                        rts
.endproc

UL_BSS

ULWSC_handle:           .res 1
ULWSC_splitcol:         .res 1
ULWSC_right_ncol:       .res 1
ULWSC_right_scol:       .res 1
ULWSC_slin:             .res 1
ULWSC_nlin:             .res 1
ULWSC_flags:            .res 1
ULWSC_color:            .res 1
ULWSC_new_handle:       .res 1
