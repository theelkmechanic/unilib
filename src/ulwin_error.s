; ulwin_error

.include "unilib_impl.inc"

.code

; ulwin_error - Display a popup window with an error message
;   In: r0              - error message string BRP
.proc ulwin_error
                        rts
.endproc

; ulwin_errorcfg - Set error/busy message colors
;   In: X               - Error foreground color
;       Y               - Error background color
.proc ulwin_errorcfg
                        stx ULW_errorfg
                        sty ULW_errorbg
                        rts
.endproc

.data

ULW_errorfg:    .byte   ULCOLOR::WHITE      ; error window foreground color
ULW_errorbg:    .byte   ULCOLOR::RED        ; error window background color

.bss

ULW_inerror:    .res    1                   ; in error display flag
