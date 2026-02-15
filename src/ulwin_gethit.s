; ulwin_gethit - Check if a key is available

.include "unilib_impl.inc"

UL_CODE

; ulwin_gethit - Check if key is available (non-destructive)
;  Out: carry            - Set if key available, clear if not
.proc ulwin_gethit
                        ; Save A/X/Y
                        pha
                        phx
                        phy

                        ; KBDBUF_PEEK: returns carry set if key available, A = key, X = count
                        jsr KBDBUF_PEEK

                        ; Save carry state
                        php

                        ; Restore A/X/Y, then pull flags to restore carry
                        ply
                        plx
                        pla
                        plp
                        rts
.endproc
