.include "unilib_impl.inc"

UL_CODE

; ul_geterror - Return the last UniLib error code
;  Out: A               - Last UniLib error code
.proc ul_geterror
                        lda UL_lasterr
                        rts
.endproc
