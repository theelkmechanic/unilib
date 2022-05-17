.include "unilib_impl.inc"

.code

; ulwin_putchar - Write a character to a window at the current cursor
;   In: A               - Window handle
;       r0/r1L          - Unicode character to write
;  Out: carry           - Set if character was printed
.proc ulwin_putchar
                        ; Save A/X/Y/RAM bank
                        sta @get_handle+1
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; See if the character is printable
                        ldx gREG::r0L
                        ldy gREG::r0H
                        lda gREG::r1L
                        jsr ul_isprint
                        bcc @exit
                        stx ULWR_char
                        sty ULWR_char+1
                        sta ULWR_char+2

                        ; Access the window structure
@get_handle:            lda #$00
                        jsr ULW_getwinstruct

                        ; If we're at the very end of the window, eventually we want to do scrolling;
                        ; for now just don't print
                        ldx ULW_WINDOW_COPY::ccol
                        ldy ULW_WINDOW_COPY::clin
                        cpx ULW_WINDOW_COPY::ncol
                        bcc :+
                        cpy ULW_WINDOW_COPY::nlin
                        bcs @exit

                        ; Set the position/color
:                       stx ULWR_dest
                        sty ULWR_dest+1
                        lda ULW_WINDOW_COPY::color
                        sta ULWR_color

                        ; Draw the character and advance the cursor if it printed
                        jsr ULW_drawchar
                        bcc @exit
                        ldx ULW_WINDOW_COPY::ccol
                        inx
                        cpx ULW_WINDOW_COPY::ncol
                        bcc :+
                        ldy ULW_WINDOW_COPY::clin
                        iny
                        cpy ULW_WINDOW_COPY::nlin
                        bcs @exit
                        ldx #0

                        ; Store the new cursor position
                        tya
                        ldy #ULW_WINDOW::clin
                        sta (ULW_scratch_fptr),y
:                       txa
                        ldy #ULW_WINDOW::ccol
                        sta (ULW_scratch_fptr),y
                        sec

                        ; Exit
@exit:                  ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda @get_handle+1
                        rts
.endproc
