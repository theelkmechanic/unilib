.include "unilib.inc"
.include "cx16.inc"

.global ULAPI_ul_init
.global ULAPI_ul_geterror
.global ULAPI_w_open
.global ULAPI_w_close
.global ULAPI_w_select
.global ULAPI_w_split
.global ULAPI_w_move
.global ULAPI_w_resize
.global ULAPI_w_clear
.global ULAPI_w_cleareol
.global ULAPI_w_scroll
.global ULAPI_w_flush
.global ULAPI_w_getpos
.global ULAPI_w_getsize
.global ULAPI_w_getcursor
.global ULAPI_w_setcursor
.global ULAPI_w_getcolor
.global ULAPI_w_setcolor
.global ULAPI_w_changecolor
.global ULAPI_w_settitle
.global ULAPI_w_putstr
.global ULAPI_w_putchar
.global ULAPI_w_inschar
.global ULAPI_w_delchar
.global ULAPI_w_insline
.global ULAPI_w_delline

; Utilities/data
.global UL_lasterr

; Font utilities
.global ULF_findcharinfo

; VERA utilities
.global ULV_init
.global ULV_blt
.global ULV_bltsrc
.global ULV_bltdst
.global ULV_bltlen
.global ULV_plotchar