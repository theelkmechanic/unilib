; UniLib API jump table

.include "unilib_impl.inc"

.segment "JUMPTBL"

    jmp ULAPI_ul_init
    jmp ULAPI_w_open
    jmp ULAPI_w_close
    jmp ULAPI_w_select
    jmp ULAPI_w_split
    jmp ULAPI_w_move
    jmp ULAPI_w_resize
    jmp ULAPI_w_clear
    jmp ULAPI_w_cleareol
    jmp ULAPI_w_scroll
    jmp ULAPI_w_flush
    jmp ULAPI_w_getpos
    jmp ULAPI_w_getsize
    jmp ULAPI_w_getcursor
    jmp ULAPI_w_setcursor
    jmp ULAPI_w_getcolor
    jmp ULAPI_w_setcolor
    jmp ULAPI_w_changecolor
    jmp ULAPI_w_settitle
    jmp ULAPI_w_putstr
    jmp ULAPI_w_putchar
    jmp ULAPI_w_inschar
    jmp ULAPI_w_delchar
    jmp ULAPI_w_insline
    jmp ULAPI_w_delline
