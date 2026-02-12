.include "unilib_impl.inc"

.code

; ulstr_release - Release a string object (free its BRP)
;   In: YX = string BRP
.proc ulstr_release
                        jmp ulmem_free
.endproc
