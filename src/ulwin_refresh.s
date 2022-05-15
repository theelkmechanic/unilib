.include "unilib_impl.inc"

.code

; ulwin_refresh - Refresh the screen
.proc ulwin_refresh
                        ; Save A/X/Y/bank
                        pha
                        phx
                        phy
                        lda BANKSEL::RAM
                        pha

                        ; If we have a dirty rect, then scan it and draw any cells that need it
                        lda ULW_dirty
                        beq :+
                        lda ULW_dirtyrect
                        sta ULWR_dest
                        lda ULW_dirtyrect+1
                        sta ULWR_dest+1
                        lda ULW_dirtyrect+2
                        inc
                        sec
                        sbc ULW_dirtyrect
                        sta ULWR_destsize
                        lda ULW_dirtyrect+3
                        inc
                        sec
                        sbc ULW_dirtyrect+1
                        sta ULWR_destsize+1
                        ldx #<ULW_drawdirty
                        ldy #>ULW_drawdirty
                        stz ULW_WINDOW_COPY::handle
                        dec ULW_WINDOW_COPY::handle
                        jsr ULW_maprect_loop

                        ; Clear the dirty rect
                        stz ULW_dirty
                        stz ULW_dirtyrect
                        stz ULW_dirtyrect+1
                        stz ULW_dirtyrect+2
                        stz ULW_dirtyrect+3

                        ; Swap the backbuffer onto the display
:                       jsr ULV_swap

                        ; Restore A/X/Y/bank
                        pla
                        sta BANKSEL::RAM
                        ply
                        plx
                        pla
                        rts
.endproc

; ULW_drawdirty - ULW_maprect_loop callback; draw dirty cells to screen backbuffer
;   In: A               - Cell map entry (high bit=dirty flag, low 6 bits=window handle)
;       X               - Cell column on screen
;       Y               - Cell row on screen
;  Out: A               - Return cell map entry with dirty bit cleared after painting it
.proc ULW_drawdirty
                        ; Skip entries that aren't dirty
                        bit #$80
                        beq @exit

                        ; Save the window handle, coordinates, and bank
                        and #$7f
                        sta ULW_dirty
                        stx ULW_dirtyrect
                        sty ULW_dirtyrect+1
                        lda BANKSEL::RAM
                        pha

                        ; Access the window information (can skip if we're still in the same window as last time)
                        lda ULW_dirty
                        cmp ULW_WINDOW_COPY::handle
                        beq :+
                        jsr ULW_getwinstruct

                        ; Convert screen coordinates to window coordinates
:                       lda ULW_dirtyrect
                        sec
                        sbc ULW_WINDOW_COPY::scol
                        sta ULW_dirtyrect+2
                        tax
                        lda ULW_dirtyrect+1
                        sec
                        sbc ULW_WINDOW_COPY::slin
                        sta ULW_dirtyrect+3
                        tay

                        ; Find the character/color inside the window buffers and draw it to the screen
                        clc
                        jsr ULW_getwinbufptr
                        lda (ULW_winbufptr)
                        pha
                        ldy #1
                        lda (ULW_winbufptr),y
                        pha
                        iny
                        lda (ULW_winbufptr),y
                        pha
                        ldx ULW_dirtyrect+2
                        ldy ULW_dirtyrect+3
                        sec
                        jsr ULW_getwinbufptr
                        lda (ULW_winbufptr)
                        sta ULVR_color
                        lda ULW_dirtyrect
                        sta ULVR_destpos
                        lda ULW_dirtyrect+1
                        sta ULVR_destpos+1
                        pla
                        ply
                        plx
                        jsr ULV_plotchar

                        ; Restore bank and return handle with dirty bit clear
                        pla
                        sta BANKSEL::RAM
                        lda ULW_WINDOW_COPY::handle
@exit:                  rts
.endproc
