; ulwin_splitcolumn - Split a window into two at specified column

.include "unilib_impl.inc"

.define ULWSC_handle      ULW_sj_scratch+0
.define ULWSC_splitcol    ULW_sj_scratch+1
.define ULWSC_right_ncol  ULW_sj_scratch+2
.define ULWSC_right_scol  ULW_sj_scratch+3
.define ULWSC_slin        ULW_sj_scratch+4
.define ULWSC_nlin        ULW_sj_scratch+5
.define ULWSC_flags       ULW_sj_scratch+6
.define ULWSC_color       ULW_sj_scratch+7
.define ULWSC_new_handle  ULW_sj_scratch+8

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

                        ; Save caller's r0-r4 (KERNAL convention)
                        lda gREG::r0L
                        pha
                        lda gREG::r0H
                        pha
                        lda gREG::r1L
                        pha
                        lda gREG::r1H
                        pha
                        lda gREG::r2L
                        pha
                        lda gREG::r2H
                        pha
                        lda gREG::r3L
                        pha
                        lda gREG::r3H
                        pha
                        lda gREG::r4L
                        pha
                        lda gREG::r4H
                        pha

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
                        cmp ULWC_ncol
                        bcc @params_ok

@bad_params:            lda #ULERR::INVALID_PARAMS
                        sta UL_lasterr
                        lda #$FF
                        sta ULWSC_new_handle
                        jmp @exit_common

@error_ret:             lda #$FF
                        sec
                        rts

@params_ok:             ; Calculate new window dimensions
                        ; Right window: starts at scol+splitcol, width = ncol-splitcol
                        lda ULWC_ncol
                        sec
                        sbc ULWSC_splitcol
                        sta ULWSC_right_ncol

                        lda ULWC_scol
                        clc
                        adc ULWSC_splitcol
                        sta ULWSC_right_scol

                        ; Save original window properties for the new window
                        lda ULWC_slin
                        sta ULWSC_slin
                        lda ULWC_nlin
                        sta ULWSC_nlin
                        lda ULWC_flags
                        sta ULWSC_flags
                        lda ULWC_color
                        sta ULWSC_color

                        ; Resize original window to left portion (splitcol columns)
                        lda ULWSC_handle
                        ldx ULWSC_splitcol
                        ldy ULWC_nlin
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
                        bra @exit_common

@alloc_fail:            lda #ULERR::OUT_OF_MEMORY
                        sta UL_lasterr
                        lda #$FF
                        sta ULWSC_new_handle

@exit_common:           ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        ; Restore caller's r0-r4
                        pla
                        sta gREG::r4H
                        pla
                        sta gREG::r4L
                        pla
                        sta gREG::r3H
                        pla
                        sta gREG::r3L
                        pla
                        sta gREG::r2H
                        pla
                        sta gREG::r2L
                        pla
                        sta gREG::r1H
                        pla
                        sta gREG::r1L
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        ; Return: A = handle, carry = error if $FF
                        lda ULWSC_new_handle
                        cmp #$FF
                        bne @ret_ok
                        sec
                        rts
@ret_ok:                clc
                        rts
.endproc

