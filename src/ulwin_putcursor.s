.include "unilib_impl.inc"

.code

; ulwin_putcolor - Set cursor position in window
;   In: A               - Window handle
;       X               - New cursor column
;       Y               - New cursor line
.proc ulwin_putcursor
@handle = gREG::r11L
                        ; Save bank
                        sta @handle
                        lda BANKSEL::RAM
                        pha

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
@exit:                  pla
                        sta BANKSEL::RAM
                        lda @handle
                        rts
.endproc

.proc ULW_putcursor
                        ; Set cursor line
                        tya
                        ldy #ULW_WINDOW::clin
                        sta (ULW_scratch_fptr),y

                        ; Set cursor column
                        txa
                        ldy #ULW_WINDOW::ccol
                        sta (ULW_scratch_fptr),y
                        rts
.endproc
