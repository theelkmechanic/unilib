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

                        ; TODO: If force redraw flag is set, repaint all windows to the backbuffer

                        ; Swap the backbuffer onto the display
                        jsr ULV_swap

                        ; Restore A/X/Y/bank
                        pla
                        sta BANKSEL::RAM
                        ply
                        plx
                        pla
                        rts
.endproc
