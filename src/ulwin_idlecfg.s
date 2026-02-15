; ulwin_idlecfg - Configure idle function for keyboard wait

.include "unilib_impl.inc"

UL_CODE

; ulwin_idlecfg - Configure function to call while waiting for keypress
;   In: YX              - Address of idle function (0 = none)
.proc ulwin_idlecfg
                        stx ULW_keyidle
                        sty ULW_keyidle+1
                        rts
.endproc
