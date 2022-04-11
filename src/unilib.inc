; UniLib API table entries
ul_init         = $2000 ; returns A = window handle of screen (always 0), or $FF if initialization fails
ul_geterror     = $2003 ; returns A = last error code

; Banked RAM allocation functions - work on banked RAM "pointers", which are two bytes:
;  - High byte (in Y register) = RAM bank
;  - Low byte (in X register) = index of 32-byte slot in 8K RAM bank area
; To access memory:
;  - RAM bank selector <- Y
;  - 16-bit address    <- $A000 | (X * 32)
mem_alloc       = $2006 ; YX = allocation size (max 7,936 bytes)
mem_free        = $2009 ; YX = "pointer" to free
mem_access      = $200c ; YX "pointer" -> RAM bank selected, YX = 16-bit memory address of data

; Window functions
w_border        = $200f; A = window #; draws border around window
w_box           = $2012; A = window, g0 = top left, g1 = bottom right; draws box in window
w_busy          = $2015; display "Busy" window
w_changecolor   = $2018; A = window, X = foreground, Y = background; change color of entire window
w_clear         = $201b; A = window; clear the window contents
w_close         = $201e; A = window; close the window
w_delchar       = $2021; A = window; delete character current position
w_delline       = $2024; A = window; delete line at current position
w_eraseeol      = $2027; A = window; erase from current position to end of line
w_errorcfg      = $202a; X = foreground, Y = background; set error colors
w_error         = $202d; XY = text address; popup error window with message
w_flash         = $2030; g0 = message address, g1 = title address, X = foreground, Y = background; flash a message on the screen
w_flashwait     = $2033; g0 = message address, g1 = title address, X = foreground, Y = background, A = seconds to wait; flash a message on the screen and wait
w_force         = $2036; force complete refresh next call to w_refresh
w_getchar       = $2039; A = window; get character at current position in XY
w_getcolor      = $203c; A = window; get color being used for output (X = foreground, Y = background)
w_getcolumn     = $203f; A = window; get window column location in A
w_getcursor     = $2042; A = window; get window cursor location (X = column, Y = line)
w_gethit        = $2045; check if key is available (A nonzero if true)
w_getkey        = $2048; get a keystroke translated to UTF-16 in XY
w_getline       = $204b; A = window; get window line location in A
w_getloc        = $204e; A = window, g0 = text buffer, X = column, Y = line; get string at specified position
w_getsize       = $2051; A = window; get size of window (x = columns, Y = lines)
w_getstr        = $2054; A = window, g0 = text buffer; get string at current position into buffer, A = length
w_getwin        = $2057; get current window in A
w_idlecfg       = $205a; XY = idle function; configure function to call while waiting for keypress
w_inschar       = $205d; A = window, XY = UTF-16; insert character at current position
w_insline       = $2060; A = window; insert line at current position
w_move          = $2063; A = window, X = new start column, Y = new start line; move a window
w_open          = $2066; A = flags, X = foreground, Y = background, g0 = top left, g1 = size, g2 = title; open a new window, returns ID in A
w_putchar       = $2069; A = window, XY = UTF-16; put character at current position
w_putcolor      = $206c; A = window, X = foreground, Y = background; put color for future window output
w_putcursor     = $206f; A = window, X = column, Y = line; put window cursor at location
w_putloc        = $2072; A = window, g0 = UTF-16 string, X = column, Y = line; put string at specified position
w_putstr        = $2075; A = window, g0 = UTF-16 string; put string at current position
w_puttitle      = $2078; A = window, g0 = title address; update window title
w_refresh       = $207b; refresh the screen with any updated window contents
w_restore       = $207e; A = window; restore screen under window from buffer
w_save          = $2081; A = window; save screen under window to buffer
w_scroll        = $2084; A = window, X = number of columns (signed), Y = number of lines (signed)
w_select        = $2087; A = window; bring a window to the top
w_swap          = $208a; A = window; swap window contents with screen save buffer
w_winptr        = $208d; A = window, X = column, Y = line; return pointer to window backing store

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
