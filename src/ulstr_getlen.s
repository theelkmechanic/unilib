.include "unilib_impl.inc"

.code

; ulstr_getlen - Get the length of a string
;   In: YX              - String BRP
;  Out: YX              - UTF-8 string length (in characters)
.proc ulstr_getlen
.endproc

; ulstr_getprintlen - Get the printable length of a string
;   In: YX              - String BRP
;  Out: YX              - UTF-8 string length (in characters, only printable characters included)
.proc ulstr_getprintlen
.endproc

; ulstr_getrawlen - Get the raw length of a string
;   In: YX              - String BRP
;  Out: YX              - UTF-8 string length (in bytes)
.proc ulstr_getrawlen
                        rts
.endproc
