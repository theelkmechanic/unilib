; UniLib API
.global ul_init             ; r0 = font filename, r1L = font filename length, r1H = drive # to load from, r2 = screen colors (r2L = foreground, r2H = background); returns error code (ULERR::OK on success)
.global ul_geterror         ; returns A = last error code

; Integer math functions
.global ulmath_udiv8_8        ; X / A => X, remainder => A
.global ulmath_udiv16_8       ; YX / A => YX, remainder => A
.global ulmath_umul8_8        ; X * A => YX
.global ulmath_umul16_8       ; YX * A => AYX

; Banked RAM allocation functions - work on banked RAM "pointers" (BRPs), which are two bytes:
;  - High byte = RAM bank
;  - Low byte = index of 32-byte slot in 8K RAM bank area
; To access memory:
;  - RAM bank selector <- hi
;  - 16-bit address    <- $A000 | (lo * 32)
.global ulmem_alloc         ; r0 = allocation size (max 7,936 bytes), carry set will clear the allocated memory; returns BPR in r0
.global ulmem_free          ; r0 = BRP to free
.global ulmem_access        ; r0 BRP -> RAM bank selected, r0 = 16-bit memory address of data

; Window functions
.global ulwin_border        ; A = window #; draws border around window
.global ulwin_box           ; A = window, r0 = top left, r1 = bottom right; draws box in window
.global ulwin_busy          ; display "Busy" window
.global ulwin_changecolor   ; A = window, X = foreground, Y = background; change color of entire window
.global ulwin_clear         ; A = window; clear the window contents
.global ulwin_close         ; A = window; close the window
.global ulwin_delchar       ; A = window; delete character at current position
.global ulwin_delline       ; A = window; delete line at current position
.global ulwin_eraseeol      ; A = window; erase from current position to end of line
.global ulwin_errorcfg      ; X = foreground, Y = background; set error colors
.global ulwin_error         ; YX = text address; popup error window with message
.global ulwin_flash         ; r0 = message address, r1 = title address, X = foreground, Y = background; flash a message on the screen
.global ulwin_flashwait     ; r0 = message address, r1 = title address, X = foreground, Y = background, A = seconds to wait; flash a message on the screen and wait
.global ulwin_force         ; force complete refresh next call to w_refresh
.global ulwin_getchar       ; A = window; get character at current position in YX
.global ulwin_getcolor      ; A = window; get color being used for output (X = foreground, Y = background)
.global ulwin_getcolumn     ; A = window; get window column location in A
.global ulwin_getcursor     ; A = window; get window cursor location (X = column, Y = line)
.global ulwin_gethit        ; check if key is available (carry set if true)
.global ulwin_getkey        ; get a keystroke translated to UTF-16 in YX
.global ulwin_getline       ; A = window; get window line location in A
.global ulwin_getloc        ; A = window, r0 = text buffer, X = column, Y = line; get string at specified position
.global ulwin_getsize       ; A = window; get size of window (X = columns, Y = lines)
.global ulwin_getstr        ; A = window, r0 = text buffer; get string at current position into buffer, A = length
.global ulwin_getwin        ; get current window in A
.global ulwin_idlecfg       ; YX = idle function; configure function to call while waiting for keypress
.global ulwin_inschar       ; A = window, YX = UTF-16; insert character at current position
.global ulwin_insline       ; A = window; insert line at current position
.global ulwin_joinlines     ; X = first window, Y = second window; join two windows, first window will be top, second will be bottom; windows must be same width and must fit on screen when combined; carry set and joined window handle in A on success
.global ulwin_joincolumns   ; X = first window, Y = second window; join two windows, first window will be left, second will be right; windows must be same height and must fit on screen when combined; carry set and joined window handle in A on success
.global ulwin_move          ; A = window, X = new screen start column of window content area, Y = new screen start line of window content area; move a window (must be fully onscreen including border, carry set on success)
.global ulwin_open          ; r0 = top left of window content area, r1 = size of window content area, r2 = colors (r2L = foreground, r2H = background), r3/r4L = title pointer, r4H = flags (0x80 = has border); open a new window, returns handle in A
.global ulwin_putchar       ; A = window, YX = UTF-16; put character at current position
.global ulwin_putcolor      ; A = window, X = foreground, Y = background; put color for future window output
.global ulwin_putcursor     ; A = window, X = column, Y = line; put window cursor at location
.global ulwin_putloc        ; A = window, r0 = UTF-16 string, X = column, Y = line; put string at specified position
.global ulwin_putstr        ; A = window, r0 = UTF-16 string; put string at current position
.global ulwin_puttitle      ; A = window, r0/r1L = title pointer; update window title
.global ulwin_refresh       ; refresh the screen with any updated window contents
.global ulwin_resize        ; A = window, X = new content area width, Y = new content area height; resize a window (must be fully onscreen including border, carry set on success)
.global ulwin_scroll        ; A = window, X = number of columns (signed), Y = number of lines (signed); scroll window contents in desired direction
.global ulwin_select        ; A = window; bring a window to the top
.global ulwin_splitline     ; A = window, Y = split line; split into two windows at specified line (window passed in A = lines 0 through split-1, new window selected and returned in A = lines split through #lines-1)
.global ulwin_splitcolumn   ; A = window, X = split column; split into two windows at specified column (window passed in A = columns 0 through split-1, new window selected and returned in A = columns split through #lines-1)

.enum ULERR
    OK = 0
    INVALID_PARAMS
    INVALID_HANDLE
    INVALID_BRP
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
