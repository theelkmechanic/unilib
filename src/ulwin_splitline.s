; ulwin_splitline - Split a window into two at specified line

.include "unilib_impl.inc"

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
                        cmp ULW_WINDOW_COPY::nlin
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
                        ; Bottom window: starts at slin+splitline, height = nlin-splitline
                        lda ULW_WINDOW_COPY::nlin
                        sec
                        sbc ULWSL_splitline
                        sta ULWSL_bot_nlin

                        lda ULW_WINDOW_COPY::slin
                        clc
                        adc ULWSL_splitline
                        sta ULWSL_bot_slin

                        ; Save original window properties for the new window
                        lda ULW_WINDOW_COPY::scol
                        sta ULWSL_scol
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWSL_ncol
                        lda ULW_WINDOW_COPY::flags
                        sta ULWSL_flags
                        lda ULW_WINDOW_COPY::color
                        sta ULWSL_color

                        ; Resize original window to top portion (splitline lines)
                        lda ULWSL_handle
                        ldx ULW_WINDOW_COPY::ncol
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

                        ; Restore and return new window handle
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULWSL_new_handle
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

ULWSL_handle:           .res 1
ULWSL_splitline:        .res 1
ULWSL_bot_nlin:         .res 1
ULWSL_bot_slin:         .res 1
ULWSL_scol:             .res 1
ULWSL_ncol:             .res 1
ULWSL_flags:            .res 1
ULWSL_color:            .res 1
ULWSL_new_handle:       .res 1
