; UniLib API - A UTF-8 Unicode Windowing Library for the Commander X-16

; NOTE: UniLib functions may change the RAM bank. If you need it preserved, you should do it yourself. Or ignore
; it entirely and just use Unilib to deal with banked RAM.

.global ul_init             ; r0 = font filename, r1L = font filename length, r1H = drive # to load from, r2 = screen colors (r2L = foreground, r2H = background); returns error code (ULERR::OK on success)
.global ul_geterror         ; returns A = last error code
.global ul_isprint          ; AYX = Unicode character; carry set if printable (i.e., ulwin_putchar will advance cursor)

; Banked RAM allocation functions - work on banked RAM "pointers" (BRPs), which are two bytes:
;  - High byte = RAM bank
;  - Low byte = index of 32-byte slot in 8K RAM bank area
; To access memory:
;  - RAM bank selector <- hi
;  - 16-bit address    <- $A000 | (lo * 32)
.global ulmem_alloc         ; YX = allocation size (max 7,936 bytes), carry set will clear the allocated memory; returns BPR in YX
.global ulmem_free          ; YX = BRP to free
.global ulmem_access        ; YX BRP -> RAM bank selected, YX = 16-bit memory address of data

; Iterators - Let you step backward/forward through memory/strings/lists/stringtables/etc.

.global ulitr_create        ; A = iterator type | Iterator format, YX = object to iterate over; returns iterator handle in YX
.global ulitr_delete        ; YX = iterator; deletes iterator
.global ulitr_fetch         ; YX = iterator; returns value at iterator as specified in formats (carry set if error)
.global ulitr_store         ; YX = iterator, pass value as specified in formats; stores value at iterator (carry set if error)
.global ulitr_fetch_and_inc ; YX = iterator; returns value at iterator as specified in formats and steps to next value if successful (carry set if error, zero set if at end)
.global ulitr_fetch_and_dec ; YX = iterator; returns value at iterator as specified in formats and steps to previous value if successful (carry set if error, zero set if at start)
.global ulitr_inc           ; YX = iterator; steps to next value (carry set if error, zero set if at end)
.global ulitr_dec           ; YX = iterator; steps to previous value (carry set if error, zero set if at start)
.global ulitr_adv           ; A = number of entries to advance, YX = iterator; advances A entries (carry set if error, zero set if at end)
.global ulitr_rew           ; A = number of entries to rewind, YX = iterator; rewinds A entries (carry set if error, zero set if at start)

; Iterator type
.enum ULITYP
    ZPPTR           = $00   ; Special case: 16/24-bit zero-page pointer, little-endian (low, high, RAM bank if
                            ; high is $A0-$BF) byte iterator, cannot be combined with a format. This is generally
                            ; the fastest iterator type to use.
                            ;   - Don't need to explicitly create, but ulitr_create will accept it
                            ;   - The "object" to iterate over and the iterator handle will be the same:
                            ;       * X = zero-page address of the 24-bit pointer
                            ;       * Y = 0
                            ;   - When pointer high byte is $9F, iterator functions will NOT move the pointer
                            ;     (to facilitate reading/writing to VRAM)
                            ;   - When pointer high byte is $A0-BF, calling iterator functions will switch to
                            ;     the RAM bank in the pointer; otherwise pointer is treated as 16-bit and RAM
                            ;     bank will not be changed
                            ;   - Pointer increment/decrement will stop at the device region at $9Fxx and at the
                            ;     ROM boundary at $C000 (e.g., if pointer is $9E80 and is advanced 256 bytes, the
                            ;     iterator will stop at $9EFF; if it is $BF00 and is advanced 384 bytes, the new
                            ;     address will be $A080 and the RAM bank will be increased by 1, etc.)
                            ;   - atstart is true when iterator points to $0000, $1A000, $C000, or anywhere in $9Fxx
                            ;   - atend is true when iterator is at $9EFF, $3FBFFF (on 512MB machines) or $FFBFFF
                            ;     (on 2MB machines), $FFFF, or anywhere in $9Fxx
                            ;   - Fetches from $C000-$FFFF will read the current ROM bank; stores will do nothing
    MEM             = $01   ; Memory iterator
                            ;   - Call ulitr_create with the address in memory to start
                            ;   - Behaves like ZPPTR for the most part, except it allows you to use different
                            ;     iterator formats
    BRP             = $02   ; Banked RAM pointer iterator
                            ;   - Call ulitr_create with the BRP of the object you wish to iterate on
                            ;   - atstart is true when at the beginning of the BRP object
                            ;   - atend is true when one step past the last entry in the BRP object (fetch/store
                            ;     will fail when at end)
    VRAM            = $03   ; VERA video ram iterator
                            ;   - Call ulitr_create with the low 16 bits of the VERA address in YX, and the high
                            ;     bit in the carry flag
                            ;   - atstart is true when at the beginning of VRAM
                            ;   - atend is true when at the end of VRAM

    REVERSE         = $80   ; Reverse flag; if set, iterator is reversed (initialized to end of BRP instead of
                            ; start, inc/dec/adv/rew go in opposite directions, atstart/atend are at opposites)
.endenum

; Iterator format (determines how far iterator inc/dec/adv/rew move and how values are passed/returned with fetch/store)
.enum ULIFMT
    BYTE            = $00   ; Byte iterator
                            ;   - Fetch/store values passed/returned in A
                            ;   - Increment/decrement move one byte
                            ;   - Advance/rewind move n bytes
    WORD            = $10   ; Word iterator
                            ;   - Fetch/store values passed/returned in r0
                            ;   - Increment/decrement move two bytes
                            ;   - Advance/rewind move n*2 bytes
    WORD            = $20   ; Word iterator
                            ;   - Fetch/store values passed/returned in r0
                            ;   - Increment/decrement move two bytes
                            ;   - Advance/rewind move n*2 bytes
    TBYTE           = $30   ; Triple-byte iterator
                            ;   - Fetch/store values passed/returned in r0/r1L
                            ;   - Increment/decrement move three bytes
                            ;   - Advance/rewind move n*3 bytes
    DWORD           = $40   ; Doubleword iterator
                            ;   - Fetch/store values passed/returned in r0/r1
                            ;   - Increment/decrement move four bytes
                            ;   - Advance/rewind move n*4 bytes
    FLOAT           = $50   ; Floating-point iterator (40-bit values as used by FP math routines)
                            ;   - Fetch/store values passed/returned in FACC
                            ;   - Increment/decrement move five bytes
                            ;   - Advance/rewind move n*5 bytes
    UTF8            = $60   ; UTF-8 string iterator
                            ;   - Fetch/store values passed/returned in r0/r1L (Unicode character)
                            ;   - Increment/decrement move one UTF-8 character
                            ;   - Advance/rewind move n characters
                            ;   - Note that hitting an invalid UTF-8 byte or a NUL will be treated as start/
                            ;     end when iterating, so be careful when using MEM/VRAM iterators with this
    STRINGTABLE     = $70   ; Stringtable iterator
                            ;   - Can only fetch values (returned in YX), table must be created/modified with
                            ;     stringtable methods
                            ;   - Returned strings are still owned by the stringtable, so don't free them
.endenum

; Unicode string functions - Work on UTF-8 BRP immutable, reference-counted string objects (max length = 7,926 bytes)
.global ulstr_fromUtf8      ; YX = address of NUL-terminated UTF-8 character data; creates new string object and returns in YX
.global ulstr_fromPETSCII   ; YX = address of NUL-terminated PETSCII character data; creates new string object and returns in YX

.global ulstr_getlen        ; YX = string; returns length in characters in YX
.global ulstr_getprintlen   ; YX = string; returns length in printable characters in YX
.global ulstr_getrawlen     ; YX = string; returns length in bytes in YX
.global ulstr_find          ; r0 = string, r1 = start index, AYX = Unicode character to find; returns index of first occurrence of character in YX (-1 if not found)
.global ulstr_rfind         ; r0 = string, r1 = start index, AYX = Unicode character to find; returns index of last occurrence of character in YX (-1 if not found)

.global ulstr_append        ; r0 = first string, r1 = second string; creates new string by appending second to first and returns in YX
.global ulstr_mid           ; r0 = string, r1 = start index, r2 = length; extracts substring and returns in YX
.global ulstr_format        ; r0 = format string, r1 = stringtable; creates new string from format string and returns in YX, carry set on error
                            ;   - {} will be replaced with successive entries in the stringtable
                            ;   - {#} will be replaced with that indexed entry in the stringtable

; Unicode stringtable functions - Manage tables of Unicode strings
.global ulstb_create        ; A = # of string slots (1-255); return stringtable BRP in YX
.global ulstb_delete        ; YX = stringtable BRP, will free all strings and stringtable
.global ulstb_get           ; A = string index to retrieve (1-based), r0 = stringtable BRP; returns string BRP in YX, carry set if error
.global ulstb_put           ; A = string index to set (1-based), YX = string BRP, r0 = stringtable BRP; carry set if error
.global ulstb_build         ; YX = address of list of NUL-terminated UTF-8 strings; creates stringtable of up to 255 strings, stops at empty string
.global ulstb_load          ; A = device number, YX = address of filename of NUL-terminated UTF-8 strings; reads from file and creates stringtable of up to 255 strings, stops at empty string or EOF

; Integer math functions
.global ulmath_abs_8        ; A => |A|
.global ulmath_negate_8     ; A => -A
.global ulmath_scmp8_8      ; A < X => carry clear, A >= X => carry set
.global ulmath_udiv8_8      ; X / A => X, remainder => A
.global ulmath_udiv16_8     ; YX / A => YX, remainder => A
.global ulmath_umul8_8      ; X * A => YX
.global ulmath_umul16_8     ; YX * A => AYX

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
.global ulwin_picklist      ; A = window, YX = stringtable to choose from; displays scrollable list in window, pressing ENTER returns choice index (1-n) in A
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
