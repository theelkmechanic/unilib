; ul_init - Initialize UniLib

.include "unilib_impl.inc"

.code

.proc ULAPI_ul_init
    ; Initialize stuff our library depends on (VERA, banked RAM, etc.)
    jsr ULV_init
    jmp ULM_init
.endproc
