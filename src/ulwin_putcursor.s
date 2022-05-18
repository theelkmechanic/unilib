.include "unilib_impl.inc"

.code

; ulwin_putcolor - Set cursor position in window
;   In: A               - Window handle
;       X               - New cursor column
;       Y               - New cursor line
.proc ulwin_putcursor
@handle = gREG::r11L
                        ; Save bank/A/X/Y
                        sta @handle
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Access the window structure
                        lda @handle
                        phy
                        phx
                        jsr ULW_getwinstruct

                        ; Clip the new cursor position inside the window contents
                        plx
                        bpl :+
                        ldx #0
:                       cpx ULW_WINDOW_COPY::ncol
                        bcc :+
                        ldx ULW_WINDOW_COPY::ncol
                        dex
:                       ply
                        bpl :+
                        ldy #0
:                       cpy ULW_WINDOW_COPY::nlin
                        bcc :+
                        ldy ULW_WINDOW_COPY::nlin
                        dey

                        ; Use the internal helper
:                       jsr ULW_putcursor

                        ; Exit
@exit:                  ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda @handle
                        rts
.endproc
