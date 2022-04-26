.include "unilib_impl.inc"

.code

; ulwin_clear - Clear the contents of a window and put the cursor at top left
;   In: A               - Handle of window to clear
.proc ulwin_clear
                        ; Save A/X/Y/bank
                        pha
                        phx
                        phy
                        ldy BANKSEL::RAM
                        phy

                        ; Access the window structure
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Call the internal helper
                        jsr ULW_clear

                        ; Restore A/X/Y/bank
                        ply
                        sty BANKSEL::RAM
                        ply
                        plx
                        pla
.endproc
a_nearby_rts:           rts

.proc ULW_clear
                        ; Copy the window structure
                        jsr ULW_copywinstruct

                        ; Put the cursor at 0,0
                        ldx #0
                        ldy #0
                        jsr ULW_putcursor

                        ; Clear the window contents
                        stz ULWR_dest
                        stz ULWR_dest+1
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWR_size
                        lda ULW_WINDOW_COPY::nlin
                        sta ULWR_size+1
                        lda ULW_WINDOW_COPY::color
                        sta ULWR_color
                        jmp ULW_clearrect
.endproc
