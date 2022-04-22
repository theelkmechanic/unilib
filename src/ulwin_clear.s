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

                        ; Get a copy of the window fields
                        jsr ULW_getwinstructcopy

                        ; Restore A/X/Y/bank
                        ply
                        sty BANKSEL::RAM
                        ply
                        plx
                        pla
                        rts
.endproc
