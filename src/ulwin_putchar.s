.include "unilib_impl.inc"

UL_CODE

; ulwin_putchar - Write a character to a window at the current cursor
;   In: A               - Window handle
;       r0/r1L          - Unicode character to write
;  Out: carry           - Set if character was printed
.proc ulwin_putchar
                        ; Save A/X/Y/RAM bank
                        sta ULWPC_handle
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; See if the character is printable
                        ldx gREG::r0L
                        ldy gREG::r0H
                        lda gREG::r1L
                        XCALL ul_isprint, UNILIB_BANK_A
                        bcc @exit
                        stx ULWR_char
                        sty ULWR_char+1
                        sta ULWR_char+2

                        ; Access the window structure
                        lda ULWPC_handle
                        jsr ULW_getwinstruct

                        ; If we're at the very end of the window, eventually we want to do scrolling;
                        ; for now just don't print
                        ldx ULWC_ccol
                        ldy ULWC_clin
                        cpx ULWC_ncol
                        bcc :+
                        cpy ULWC_nlin
                        bcs @exit

                        ; Set the position/color
:                       stx ULWR_dest
                        sty ULWR_dest+1
                        lda ULWC_color
                        sta ULWR_color

                        ; Draw the character and advance the cursor if it printed
                        jsr ULW_drawchar
                        bcc @exit
                        ldx ULWC_ccol
                        ldy ULWC_clin
                        inx
                        cpx ULWC_ncol
                        bcc :+
                        iny
                        cpy ULWC_nlin
                        bcs @exit
                        ldx #0

                        ; Store the new cursor position
:                       lda ULWPC_handle
                        jsr ulwin_putcursor
                        sec

                        ; Exit
@exit:                  ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULWPC_handle
                        rts
.endproc

UL_BSS

ULWPC_handle:           .res    1
