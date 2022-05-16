; UniLib API - A UTF-8 Unicode Windowing Library for the Commander X-16
.global ul_init             ; r0 = font filename, r1L = font filename length, r1H = drive # to load from, r2 = screen colors (r2L = foreground, r2H = background); returns error code (ULERR::OK on success)
.global ul_geterror         ; returns A = last error code
.global ul_isprint          ; AYX = Unicode character; carry set if printable (i.e., ulwin_putchar will advance cursor)

; Integer math functions
.global ulmath_abs_8        ; A => |A|
.global ulmath_negate_8     ; A => -A
.global ulmath_scmp8_8      ; A < X => carry clear, A >= X => carry set
.global ulmath_udiv8_8      ; X / A => X, remainder => A
.global ulmath_udiv16_8     ; YX / A => YX, remainder => A
.global ulmath_umul8_8      ; X * A => YX
.global ulmath_umul16_8     ; YX * A => AYX

; Banked RAM allocation functions - work on banked RAM "pointers" (BRPs), which are two bytes:
;  - High byte = RAM bank
;  - Low byte = index of 32-byte slot in 8K RAM bank area
; To access memory:
;  - RAM bank selector <- hi
;  - 16-bit address    <- $A000 | (lo * 32)
.global ulmem_alloc         ; YX = allocation size (max 7,936 bytes), carry set will clear the allocated memory; returns BPR in YX
.global ulmem_free          ; YX = BRP to free
.global ulmem_access        ; YX BRP -> RAM bank selected, YX = 16-bit memory address of data

; Unicode string functions - Work on UTF-8 BRP immutable string objects (max length = 252 bytes)
.global ulstr_access        ; YX = string; returns address of UTF-8 string data in YX (copied to $400-4ff low RAM scratch buffer if in non-current RAM bank)
.global ulstr_fromPETSCII   ; YX = address of PETSCII character data, A=byte length (0=NUL-terminated); returns string in YX
.global ulstr_fromUtf8      ; YX = address of UTF-8 character data, A=char length (0=NUL-terminated); returns string in YX
.global ulstr_getlen        ; YX = string; returns length in characters in A
.global ulstr_getprintlen   ; YX = string; returns length in printable characters in A
.global ulstr_getrawlen     ; YX = string; returns length in bytes in A

; Unicode string iteration/manipulation functions - operate on ulstr_current
.global ulstr_current       ; carry set = set current string to YX; clear = get current string in YX
.global ulstr_append        ; YX = string to append to current
.global ulstr_begin         ; move iterator to beginning of current string
.global ulstr_char          ; get character at current iterator in AYX
.global ulstr_charnext      ; get character at current iterator in AYX and step iterator to next character; carry set if at end of string
.global ulstr_next          ; step iterator to next character; carry set if at end of string

; Window functions
.global ulwin_box           ; A = window, r0 = top left, r1 = bottom right; draws box in window
.global ulwin_busy          ; YX = Busy string to display (0 = default "Busy..."); display "Busy" window
.global ulwin_clear         ; A = window; clear the window contents
.global ulwin_close         ; A = window; close the window
.global ulwin_delchar       ; A = window; delete character at current position
.global ulwin_delline       ; A = window; delete line at current position
.global ulwin_eraseeol      ; A = window; erase from current position to end of line
.global ulwin_errorcfg      ; X = foreground, Y = background; set error colors
.global ulwin_error         ; r0 = text string; popup error window with message
.global ulwin_flash         ; r0 = message string, r1 = title string, X = foreground, Y = background; flash a message on the screen
.global ulwin_flashwait     ; r0 = message string, r1 = title string, X = foreground, Y = background, A = seconds to wait; flash a message on the screen and wait
.global ulwin_force         ; force complete refresh next call to w_refresh
.global ulwin_getchar       ; A = window; get character at current position in AYX
.global ulwin_getcolor      ; A = window; get color being used for output (X = foreground, Y = background)
.global ulwin_getcolumn     ; A = window; get window cursor column in A
.global ulwin_getcursor     ; A = window; get window cursor location (X = column, Y = line)
.global ulwin_gethit        ; check if key is available (carry set if true)
.global ulwin_getkey        ; get a keystroke translated to Unicode in AYX
.global ulwin_getline       ; A = window; get window cursor line in A
.global ulwin_getloc        ; A = window, X = column, Y = line; return remainder of line at specified position as string in YX
.global ulwin_getpos        ; A = window; get position of window (X = start column, Y = start line)
.global ulwin_getsize       ; A = window; get size of window (X = columns, Y = lines)
.global ulwin_getstr        ; A = window; return remainder of line at current position as string in YX
.global ulwin_getwin        ; get current window in A
.global ulwin_idlecfg       ; YX = idle function; configure function to call while waiting for keypress
.global ulwin_inschar       ; A = window, r0/r1L = Unicode character; insert character at current position
.global ulwin_insline       ; A = window; insert line at current position
.global ulwin_joinlines     ; X = first window, Y = second window; join two windows, first window will be top, second will be bottom; windows must be same width and must fit on screen when combined; carry set and joined window handle in A on success
.global ulwin_joincolumns   ; X = first window, Y = second window; join two windows, first window will be left, second will be right; windows must be same height and must fit on screen when combined; carry set and joined window handle in A on success
.global ulwin_move          ; A = window, X = new screen start column of window content area, Y = new screen start line of window content area; move a window (must be fully onscreen including border, carry set on success)
.global ulwin_open          ; r0 = top left of window content area, r1 = size of window content area, r2 = colors (r2L = foreground, r2H = background), r3/r4L = title pointer, r4H = flags (0x80 = has border); open a new window, returns handle in A
.global ulwin_putchar       ; A = window, r0/r1L = Unicode character; put character at current position
.global ulwin_putcolor      ; A = window, X = foreground, Y = background, carry set updates entire window immediately; put color for future window output
.global ulwin_putcursor     ; A = window, X = column, Y = line; put window cursor at location
.global ulwin_putloc        ; A = window, r0 = string, X = column, Y = line, carry set for autowrap/scroll; put string at specified position (updates cursor position)
.global ulwin_putstr        ; A = window, r0 = string, carry set for autowrap/scroll; put string at current position
.global ulwin_puttitle      ; A = window, r0 = title string; update window title
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
    STRING_TOO_LONG
    INVALID_UTF8
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

.enum ULWIN_FLAGS
    BORDER     = $80
.endenum

; Undo any PETSCII character maps
.charmap $20, $20
.charmap $21, $21
.charmap $22, $22
.charmap $23, $23
.charmap $24, $24
.charmap $25, $25
.charmap $26, $26
.charmap $27, $27
.charmap $28, $28
.charmap $29, $29
.charmap $2a, $2a
.charmap $2b, $2b
.charmap $2c, $2c
.charmap $2d, $2d
.charmap $2e, $2e
.charmap $2f, $2f
.charmap $30, $30
.charmap $31, $31
.charmap $32, $32
.charmap $33, $33
.charmap $34, $34
.charmap $35, $35
.charmap $36, $36
.charmap $37, $37
.charmap $38, $38
.charmap $39, $39
.charmap $3a, $3a
.charmap $3b, $3b
.charmap $3c, $3c
.charmap $3d, $3d
.charmap $3e, $3e
.charmap $3f, $3f
.charmap $40, $40
.charmap $41, $41
.charmap $42, $42
.charmap $43, $43
.charmap $44, $44
.charmap $45, $45
.charmap $46, $46
.charmap $47, $47
.charmap $48, $48
.charmap $49, $49
.charmap $4a, $4a
.charmap $4b, $4b
.charmap $4c, $4c
.charmap $4d, $4d
.charmap $4e, $4e
.charmap $4f, $4f
.charmap $50, $50
.charmap $51, $51
.charmap $52, $52
.charmap $53, $53
.charmap $54, $54
.charmap $55, $55
.charmap $56, $56
.charmap $57, $57
.charmap $58, $58
.charmap $59, $59
.charmap $5a, $5a
.charmap $5b, $5b
.charmap $5c, $5c
.charmap $5d, $5d
.charmap $5e, $5e
.charmap $5f, $5f
.charmap $60, $60
.charmap $61, $61
.charmap $62, $62
.charmap $63, $63
.charmap $64, $64
.charmap $65, $65
.charmap $66, $66
.charmap $67, $67
.charmap $68, $68
.charmap $69, $69
.charmap $6a, $6a
.charmap $6b, $6b
.charmap $6c, $6c
.charmap $6d, $6d
.charmap $6e, $6e
.charmap $6f, $6f
.charmap $70, $70
.charmap $71, $71
.charmap $72, $72
.charmap $73, $73
.charmap $74, $74
.charmap $75, $75
.charmap $76, $76
.charmap $77, $77
.charmap $78, $78
.charmap $79, $79
.charmap $7a, $7a
.charmap $7b, $7b
.charmap $7c, $7c
.charmap $7d, $7d
.charmap $7e, $7e
.charmap $7f, $7f
