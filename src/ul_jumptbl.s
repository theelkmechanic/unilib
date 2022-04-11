; UniLib API jump table

.include "unilib_impl.inc"

.segment "JUMPTBL"

    jmp ULAPI_ul_init
    jmp ULAPI_ul_geterror

    jmp ULAPI_mem_alloc
    jmp ULAPI_mem_free
    jmp ULAPI_mem_access

    jmp ULAPI_w_border      ; A = window #; draws border around window
    jmp ULAPI_w_box         ; A = window, g0 = top left, g1 = bottom right; draws box in window
    jmp ULAPI_w_busy        ; display "Busy" window
    jmp ULAPI_w_changecolor ; A = window, X = foreground, Y = background; change color of entire window
    jmp ULAPI_w_clear       ; A = window; clear the window contents
    jmp ULAPI_w_close       ; A = window; close the window
    jmp ULAPI_w_delchar     ; A = window; delete character current position
    jmp ULAPI_w_delline     ; A = window; delete line at current position
    jmp ULAPI_w_eraseeol    ; A = window; erase from current position to end of line
    jmp ULAPI_w_errorcfg    ; X = foreground, Y = background; set error colors
    jmp ULAPI_w_error       ; XY = text address; popup error window with message
    jmp ULAPI_w_flash       ; g0 = message address, g1 = title address, X = foreground, Y = background; flash a message on the screen
    jmp ULAPI_w_flashwait   ; g0 = message address, g1 = title address, X = foreground, Y = background, A = seconds to wait; flash a message on the screen and wait
    jmp ULAPI_w_force       ; force complete refresh next call to w_refresh
    jmp ULAPI_w_getchar     ; A = window; get character at current position in XY
    jmp ULAPI_w_getcolor    ; A = window; get color being used for output (X = foreground, Y = background)
    jmp ULAPI_w_getcolumn   ; A = window; get window column location in A
    jmp ULAPI_w_getcursor   ; A = window; get window cursor location (X = column, Y = line)
    jmp ULAPI_w_gethit      ; check if key is available (A nonzero if true)
    jmp ULAPI_w_getkey      ; get a keystroke translated to UTF-16 in XY
    jmp ULAPI_w_getline     ; A = window; get window line location in A
    jmp ULAPI_w_getloc      ; A = window, g0 = text buffer, X = column, Y = line; get string at specified position
    jmp ULAPI_w_getsize     ; A = window; get size of window (x = columns, Y = lines)
    jmp ULAPI_w_getstr      ; A = window, g0 = text buffer; get string at current position into buffer, A = length
    jmp ULAPI_w_getwin      ; get current window in A
    jmp ULAPI_w_idlecfg     ; XY = idle function; configure function to call while waiting for keypress
    jmp ULAPI_w_inschar     ; A = window, XY = UTF-16; insert character at current position
    jmp ULAPI_w_insline     ; A = window; insert line at current position
    jmp ULAPI_w_move        ; A = window, X = new start column, Y = new start line; move a window
    jmp ULAPI_w_open        ; A = flags, X = foreground, Y = background, g0 = top left, g1 = size, g2 = title; open a new window, returns ID in A
    jmp ULAPI_w_putchar     ; A = window, XY = UTF-16; put character at current position
    jmp ULAPI_w_putcolor    ; A = window, X = foreground, Y = background; put color for future window output
    jmp ULAPI_w_putcursor   ; A = window, X = column, Y = line; put window cursor at location
    jmp ULAPI_w_putloc      ; A = window, g0 = UTF-16 string, X = column, Y = line; put string at specified position
    jmp ULAPI_w_putstr      ; A = window, g0 = UTF-16 string; put string at current position
    jmp ULAPI_w_puttitle    ; A = window, g0 = title address; update window title
    jmp ULAPI_w_refresh     ; refresh the screen with any updated window contents
    jmp ULAPI_w_restore     ; A = window; restore screen under window from buffer
    jmp ULAPI_w_save        ; A = window; save screen under window to buffer
    jmp ULAPI_w_scroll      ; A = window, X = number of columns (signed), Y = number of lines (signed)
    jmp ULAPI_w_select      ; A = window; bring a window to the top
    jmp ULAPI_w_swap        ; A = window; swap window contents with screen save buffer
    jmp ULAPI_w_winptr      ; A = window, X = column, Y = line; return pointer to window backing store
