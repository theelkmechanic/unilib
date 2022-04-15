; UniLib API
.global ul_init             ; A = font filename length; YX = font filename; returns A = window handle of screen (always 0), or $FF if initialization fails
.global ul_geterror         ; returns A = last error code

; Integer math functions
.global ulmath_udiv8_8        ; X / A => X, remainder => A
.global ulmath_udiv16_8       ; YX / A => YX, remainder => A
.global ulmath_umul8_8        ; X * A => YX
.global ulmath_umul16_8       ; YX * A => AYX

; Banked RAM allocation functions - work on banked RAM "pointers", which are two bytes:
;  - High byte (in Y register) = RAM bank
;  - Low byte (in X register) = index of 32-byte slot in 8K RAM bank area
; To access memory:
;  - RAM bank selector <- Y
;  - 16-bit address    <- $A000 | (X * 32)
.global ulmem_alloc         ; YX = allocation size (max 7,936 bytes), carry set will clear the allocated memory
.global ulmem_free          ; YX = "pointer" to free
.global ulmem_access        ; YX "pointer" -> RAM bank selected, YX = 16-bit memory address of data

; Window functions
.global ulwin_border        ; A = window #; draws border around window
.global ulwin_box           ; A = window, g0 = top left, g1 = bottom right; draws box in window
.global ulwin_busy          ; display "Busy" window
.global ulwin_changecolor   ; A = window, X = foreground, Y = background; change color of entire window
.global ulwin_clear         ; A = window; clear the window contents
.global ulwin_close         ; A = window; close the window
.global ulwin_delchar       ; A = window; delete character current position
.global ulwin_delline       ; A = window; delete line at current position
.global ulwin_eraseeol      ; A = window; erase from current position to end of line
.global ulwin_errorcfg      ; X = foreground, Y = background; set error colors
.global ulwin_error         ; XY = text address; popup error window with message
.global ulwin_flash         ; g0 = message address, g1 = title address, X = foreground, Y = background; flash a message on the screen
.global ulwin_flashwait     ; g0 = message address, g1 = title address, X = foreground, Y = background, A = seconds to wait; flash a message on the screen and wait
.global ulwin_force         ; force complete refresh next call to w_refresh
.global ulwin_getchar       ; A = window; get character at current position in XY
.global ulwin_getcolor      ; A = window; get color being used for output (X = foreground, Y = background)
.global ulwin_getcolumn     ; A = window; get window column location in A
.global ulwin_getcursor     ; A = window; get window cursor location (X = column, Y = line)
.global ulwin_gethit        ; check if key is available (A nonzero if true)
.global ulwin_getkey        ; get a keystroke translated to UTF-16 in XY
.global ulwin_getline       ; A = window; get window line location in A
.global ulwin_getloc        ; A = window, g0 = text buffer, X = column, Y = line; get string at specified position
.global ulwin_getsize       ; A = window; get size of window (X = columns, Y = lines)
.global ulwin_getstr        ; A = window, g0 = text buffer; get string at current position into buffer, A = length
.global ulwin_getwin        ; get current window in A
.global ulwin_idlecfg       ; XY = idle function; configure function to call while waiting for keypress
.global ulwin_inschar       ; A = window, XY = UTF-16; insert character at current position
.global ulwin_insline       ; A = window; insert line at current position
.global ulwin_move          ; A = window, X = new start column, Y = new start line; move a window
.global ulwin_open          ; A = flags, X = foreground, Y = background, g0 = top left, g1 = size, g2 = title; open a new window, returns ID in A
.global ulwin_putchar       ; A = window, XY = UTF-16; put character at current position
.global ulwin_putcolor      ; A = window, X = foreground, Y = background; put color for future window output
.global ulwin_putcursor     ; A = window, X = column, Y = line; put window cursor at location
.global ulwin_putloc        ; A = window, g0 = UTF-16 string, X = column, Y = line; put string at specified position
.global ulwin_putstr        ; A = window, g0 = UTF-16 string; put string at current position
.global ulwin_puttitle      ; A = window, g0 = title address; update window title
.global ulwin_refresh       ; refresh the screen with any updated window contents
.global ulwin_scroll        ; A = window, X = number of columns (signed), Y = number of lines (signed)
.global ulwin_select        ; A = window; bring a window to the top
.global ulwin_winptr        ; A = window, X = column, Y = line; return pointer to window backing store

.enum ULERR
    OK = 0
    INVALID_PARAMS
    INVALID_HANDLE
    OUT_OF_MEMORY
    OUT_OF_RESOURCES
    LOAD_FAILED
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
