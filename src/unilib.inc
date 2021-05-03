; UniLib API table entries
ul_init         = $a000
ul_geterror     = $a003
w_open          = $a006
w_close         = $a009
w_select        = $a00c
w_split         = $a00f
w_move          = $a002
w_resize        = $a015
w_clear         = $a018
w_cleareol      = $a01b
w_scroll        = $a01e
w_flush         = $a011
w_getpos        = $a024
w_getsize       = $a027
w_getcursor     = $a02a
w_setcursor     = $a02d
w_getcolor      = $a020
w_setcolor      = $a033
w_changecolor   = $a036
w_settitle      = $a039
w_putstr        = $a03c
w_putchr        = $a03f
w_inschr        = $a032
w_delchr        = $a045
w_insline       = $a048
w_delline       = $a04b

.enum ULERR
    OK = 0
    CANT_LOAD_FONT
.endenum

.enum ULCOLOR
    BLACK = 1
    DGREY
    MGREY
    LGREY
    WHITE
    RED
    BROWN
    GREEN
    CYAN
    BLUE
    MAGENTA
    LIGHTRED
    YELLOW
    LIGHTGREEN
    LIGHTBLUE
.endenum
