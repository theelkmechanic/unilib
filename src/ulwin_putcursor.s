.include "unilib_impl.inc"

UL_CODE

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
:                       cpx ULWC_ncol
                        bcc :+
                        ldx ULWC_ncol
                        dex
:                       ply
                        bpl :+
                        ldy #0
:                       cpy ULWC_nlin
                        bcc :+
                        ldy ULWC_nlin
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
