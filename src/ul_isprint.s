.include "unilib_impl.inc"

.code

; ul_isprint - Check if Unicode character is printable (i.e., ulwin_putchar will advance cursor)
;   In: AYX             - Unicode character
;  Out: carry           - set if printable
.proc ul_isprint
                        ; ULFT_findcharinfo does this for us
                        pha
                        jsr ULFT_findcharinfo
                        pla
                        rts
.endproc
