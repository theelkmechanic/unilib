; ul_geterror - Return the last UniLib error

.include "unilib_impl.inc"

.code

; ul_geterror - Return the last UniLib error code
; Out:  a           - Last UniLib error code
.proc ULAPI_ul_geterror
    lda UL_lasterr
    rts
.endproc

.bss

UL_lasterr: .res 1