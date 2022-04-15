; ulwin_error

.include "unilib_impl.inc"

.code

.proc ulwin_error
    rts
.endproc

.data

ULW_errorfg:    .byte   ULCOLOR::WHITE      ; error window foreground color
ULW_errorbg:    .byte   ULCOLOR::RED        ; error window background color

.bss

ULW_inerror:    .res    1                   ; in error display flag
