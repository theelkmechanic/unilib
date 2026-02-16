.include "unilib_impl.inc"

UL_CODE

; ul_isprint - Check if Unicode character is printable (i.e., ulwin_putchar will advance cursor)
;   In: AYX             - Unicode character
;  Out: carry           - set if printable
.proc ul_isprint
                        ; ULFT_findcharinfo is in Bank B; must use XCALL from Bank A
                        pha
                        XCALL ULFT_findcharinfo, UNILIB_BANK_B
                        pla
                        rts
.endproc
