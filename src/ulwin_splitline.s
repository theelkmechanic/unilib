; ulwin_splitline - Split a window into two at specified line

.include "unilib_impl.inc"

.define ULWSL_handle      ULW_sj_scratch+0
.define ULWSL_splitline   ULW_sj_scratch+1
.define ULWSL_bot_nlin    ULW_sj_scratch+2
.define ULWSL_bot_slin    ULW_sj_scratch+3
.define ULWSL_scol        ULW_sj_scratch+4
.define ULWSL_ncol        ULW_sj_scratch+5
.define ULWSL_flags       ULW_sj_scratch+6
.define ULWSL_color       ULW_sj_scratch+7
.define ULWSL_new_handle  ULW_sj_scratch+8

UL_CODE

; ulwin_splitline - Split a window into two at specified line
;   In: A               - Window handle
;       Y               - Split line (new window starts at this line)
;   Out: A              - New window handle (or $FF on error, carry set)
;   The original window keeps lines 0 through split-1.
;   The new window gets lines split through nlin-1.
;   New window is selected and returned.
;   Note: Content is not preserved; both windows are cleared.
.proc ulwin_splitline
                        ; Don't split the screen window
                        cmp #0
                        beq @error_ret

                        ; Save params
                        sta ULWSL_handle
                        sty ULWSL_splitline

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
                        lda ULWSL_handle
                        jsr ULW_getwinstruct

                        ; Validate: split line must be > 0 and < nlin
                        lda ULWSL_splitline
                        beq @bad_params
                        cmp ULWC_nlin
                        bcc @params_ok

@bad_params:            lda #ULERR::INVALID_PARAMS
                        sta UL_lasterr
                        lda #$FF
                        sta ULWSL_new_handle
                        jmp @exit_common

@error_ret:             lda #$FF
                        sec
                        rts

@params_ok:             ; Calculate new window dimensions
                        ; Bottom window: starts at slin+splitline, height = nlin-splitline
                        lda ULWC_nlin
                        sec
                        sbc ULWSL_splitline
                        sta ULWSL_bot_nlin

                        lda ULWC_slin
                        clc
                        adc ULWSL_splitline
                        sta ULWSL_bot_slin

                        ; Save original window properties for the new window
                        lda ULWC_scol
                        sta ULWSL_scol
                        lda ULWC_ncol
                        sta ULWSL_ncol
                        lda ULWC_flags
                        sta ULWSL_flags
                        lda ULWC_color
                        sta ULWSL_color

                        ; Resize original window to top portion (splitline lines)
                        lda ULWSL_handle
                        ldx ULWC_ncol
                        ldy ULWSL_splitline
                        jsr ulwin_resize
                        bcc :+
                        jmp @alloc_fail
:
                        ; Open new window for the bottom portion
                        lda ULWSL_scol
                        sta gREG::r0L
                        lda ULWSL_bot_slin
                        sta gREG::r0H
                        lda ULWSL_ncol
                        sta gREG::r1L
                        lda ULWSL_bot_nlin
                        sta gREG::r1H

                        ; Color: split nibbles
                        lda ULWSL_color
                        and #$0F
                        sta gREG::r2L
                        lda ULWSL_color
                        lsr
                        lsr
                        lsr
                        lsr
                        sta gREG::r2H

                        ; No title
                        stz gREG::r3L
                        stz gREG::r3H

                        ; Same flags
                        lda ULWSL_flags
                        sta gREG::r4H

                        ; Open the new window
                        jsr ulwin_open
                        cmp #0
                        bne @open_ok

                        ; Open failed
                        jmp @alloc_fail

@open_ok:               sta ULWSL_new_handle
                        bra @exit_common

@alloc_fail:            lda #ULERR::OUT_OF_MEMORY
                        sta UL_lasterr
                        lda #$FF
                        sta ULWSL_new_handle

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
                        lda ULWSL_new_handle
                        cmp #$FF
                        bne @ret_ok
                        sec
                        rts
@ret_ok:                clc
                        rts
.endproc

UL_BSS

; Split/Join shared scratch (9 bytes, non-reentrant)
; Used by: splitline, splitcolumn, joinlines, joincolumns
ULW_sj_scratch:         .res 9

