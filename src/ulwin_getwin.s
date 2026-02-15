; ulwin_getwin - Get the current window handle

.include "unilib_impl.inc"

UL_CODE

; ulwin_getwin - Get current window handle
;   Out: A               - Current window handle
.proc ulwin_getwin
                        lda ULW_current_handle
                        rts
.endproc
