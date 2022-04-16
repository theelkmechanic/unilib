.include "unilib_impl.inc"

.code

; ulwin_refresh - Refresh the screen
.proc ulwin_refresh
                        ; TODO: If force redraw flag is set, repaint all windows to the backbuffer

                        ; Swap the backbuffer onto the display
                        jmp ULV_swap
.endproc
