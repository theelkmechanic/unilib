.include "unilib.inc"
.include "cx16.inc"

; Unilib implementations
.global ULAPI_ul_init
.global ULAPI_ul_geterror

; Banked RAM memory implementations
.global ULAPI_mem_alloc
.global ULAPI_mem_free
.global ULAPI_mem_access
.global ULM_init

; Windowing implementations
.struct w_window
slin    .byte
scol    .byte
elin    .byte
ecol    .byte
clin    .byte
ccol    .byte
flags   .byte
bgcolor .byte
fgcolor .byte
emcolor .byte
title   .word
save    .word
prev    .byte
next    .byte
.endstruct

.global ULAPI_w_border      ; A = window #; draws border around window
.global ULAPI_w_box         ; A = window, g0 = top left, g1 = bottom right; draws box in window
.global ULAPI_w_busy        ; display "Busy" window
.global ULAPI_w_changecolor ; A = window, X = foreground, Y = background; change color of entire window
.global ULAPI_w_clear       ; A = window; clear the window contents
.global ULAPI_w_close       ; A = window; close the window
.global ULAPI_w_delchar     ; A = window; delete character current position
.global ULAPI_w_delline     ; A = window; delete line at current position
.global ULAPI_w_eraseeol    ; A = window; erase from current position to end of line
.global ULAPI_w_errorcfg    ; X = foreground, Y = background; set error colors
.global ULAPI_w_error       ; XY = text address; popup error window with message
.global ULAPI_w_flash       ; g0 = message address, g1 = title address, X = foreground, Y = background; flash a message on the screen
.global ULAPI_w_flashwait   ; g0 = message address, g1 = title address, X = foreground, Y = background, A = seconds to wait; flash a message on the screen and wait
.global ULAPI_w_force       ; force complete refresh next call to w_refresh
.global ULAPI_w_getchar     ; A = window; get character at current position in XY
.global ULAPI_w_getcolor    ; A = window; get color being used for output (X = foreground, Y = background)
.global ULAPI_w_getcolumn   ; A = window; get window column location in A
.global ULAPI_w_getcursor   ; A = window; get window cursor location (X = column, Y = line)
.global ULAPI_w_gethit      ; check if key is available (A nonzero if true)
.global ULAPI_w_getkey      ; get a keystroke translated to UTF-16 in XY
.global ULAPI_w_getline     ; A = window; get window line location in A
.global ULAPI_w_getloc      ; A = window, g0 = text buffer, X = column, Y = line; get string at specified position
.global ULAPI_w_getsize     ; A = window; get size of window (x = columns, Y = lines)
.global ULAPI_w_getstr      ; A = window, g0 = text buffer; get string at current position into buffer, A = length
.global ULAPI_w_getwin      ; get current window in A
.global ULAPI_w_idlecfg     ; XY = idle function; configure function to call while waiting for keypress
.global ULAPI_w_inschar     ; A = window, XY = UTF-16; insert character at current position
.global ULAPI_w_insline     ; A = window; insert line at current position
.global ULAPI_w_move        ; A = window, X = new start column, Y = new start line; move a window
.global ULAPI_w_open        ; A = flags, X = foreground, Y = background, g0 = top left, g1 = size, g2 = title; open a new window, returns ID in A
.global ULAPI_w_putchar     ; A = window, XY = UTF-16; put character at current position
.global ULAPI_w_putcolor    ; A = window, X = foreground, Y = background; put color for future window output
.global ULAPI_w_putcursor   ; A = window, X = column, Y = line; put window cursor at location
.global ULAPI_w_putloc      ; A = window, g0 = UTF-16 string, X = column, Y = line; put string at specified position
.global ULAPI_w_putstr      ; A = window, g0 = UTF-16 string; put string at current position
.global ULAPI_w_puttitle    ; A = window, g0 = title address; update window title
.global ULAPI_w_refresh     ; refresh the screen with any updated window contents
.global ULAPI_w_restore     ; A = window; restore screen under window from buffer
.global ULAPI_w_save        ; A = window; save screen under window to buffer
.global ULAPI_w_scroll      ; A = window, X = number of columns (signed), Y = number of lines (signed)
.global ULAPI_w_select      ; A = window; bring a window to the top
.global ULAPI_w_swap        ; A = window; swap window contents with screen save buffer
.global ULAPI_w_winptr      ; A = window, X = column, Y = line; return pointer to window backing store

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

; RAM banking
BANK_RAM = $00
BANK_BASE = $A000
