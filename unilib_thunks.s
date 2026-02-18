; unilib_thunks.s - Backward-compatible thin wrappers for ROM build
;
; Provides normal JSR entry points for all UniLib API functions.
; Each thunk calls through the KERNAL jsrfar ($FF6E) to the appropriate
; ROM bank's jump table entry.
;
; Include this object when linking applications that want to use plain
; "jsr ul_init" style calls with UniLib in ROM.
; Total size: ~707 bytes (101 thunks x 7 bytes each)

.include "unilib_rom.inc"

.code

; =============================================================================
; Thunk macros
; =============================================================================

; Thunk for a Bank A (Foundation + Data) function
.macro THUNK_A symbol, addr
    .export symbol
symbol:
    jsr $FF6E
    .word addr
    .byte UNILIB_BANK_A
    rts
.endmacro

; Thunk for a Bank B (Display) function
.macro THUNK_B symbol, addr
    .export symbol
symbol:
    jsr $FF6E
    .word addr
    .byte UNILIB_BANK_B
    rts
.endmacro

; =============================================================================
; Bank A thunks - Foundation + Data
; =============================================================================

; Core
THUNK_A ul_init,              UL_JT_INIT
THUNK_A ul_geterror,          UL_JT_GETERROR

; Memory
THUNK_A ulmem_alloc,          UL_JT_MEM_ALLOC
THUNK_A ulmem_realloc,        UL_JT_MEM_REALLOC
THUNK_A ulmem_free,           UL_JT_MEM_FREE
THUNK_A ulmem_access,         UL_JT_MEM_ACCESS
THUNK_A ulmem_capacity,       UL_JT_MEM_CAPACITY

; Data blocks
THUNK_A uldb_create,          UL_JT_DB_CREATE
THUNK_A uldb_fromBRP,         UL_JT_DB_FROMBRP
THUNK_A uldb_fromBuffer,      UL_JT_DB_FROMBUFFER
THUNK_A uldb_fromIter,        UL_JT_DB_FROMITER
THUNK_A uldb_getrefcount,     UL_JT_DB_GETREFCOUNT
THUNK_A uldb_addref,          UL_JT_DB_ADDREF
THUNK_A uldb_release,         UL_JT_DB_RELEASE
THUNK_A uldb_getsize,         UL_JT_DB_GETSIZE
THUNK_A uldb_getcapacity,     UL_JT_DB_GETCAPACITY
THUNK_A uldb_getbrp,          UL_JT_DB_GETBRP

; Blocklists
THUNK_A ullist_create,        UL_JT_LIST_CREATE
THUNK_A ullist_getrefcount,   UL_JT_LIST_GETREFCOUNT
THUNK_A ullist_addref,        UL_JT_LIST_ADDREF
THUNK_A ullist_release,       UL_JT_LIST_RELEASE
THUNK_A ullist_getsize,       UL_JT_LIST_GETSIZE
THUNK_A ullist_insert,        UL_JT_LIST_INSERT
THUNK_A ullist_delete,        UL_JT_LIST_DELETE
THUNK_A ullist_getat,         UL_JT_LIST_GETAT

; Iterators
THUNK_A ulitr_create,         UL_JT_ITR_CREATE
THUNK_A ulitr_delete,         UL_JT_ITR_DELETE
THUNK_A ulitr_fetch,          UL_JT_ITR_FETCH
THUNK_A ulitr_store,          UL_JT_ITR_STORE
THUNK_A ulitr_fetch_and_inc,  UL_JT_ITR_FETCH_AND_INC
THUNK_A ulitr_fetch_and_dec,  UL_JT_ITR_FETCH_AND_DEC
THUNK_A ulitr_inc,            UL_JT_ITR_INC
THUNK_A ulitr_dec,            UL_JT_ITR_DEC
THUNK_A ulitr_adv,            UL_JT_ITR_ADV
THUNK_A ulitr_rew,            UL_JT_ITR_REW
THUNK_A ulitr_atstart,        UL_JT_ITR_ATSTART
THUNK_A ulitr_atend,          UL_JT_ITR_ATEND

; Strings
THUNK_A ulstr_fromUtf8,       UL_JT_STR_FROMUTF8
THUNK_A ulstr_fromPETSCII,   UL_JT_STR_FROMPETSCII
THUNK_A ulstr_toPETSCII,    UL_JT_STR_TOPETSCII
THUNK_A ulstr_fromISO8859,  UL_JT_STR_FROMISO8859
THUNK_A ulstr_toISO8859,    UL_JT_STR_TOISO8859
THUNK_A ulstr_format,       UL_JT_STR_FORMAT
THUNK_A ulstr_getlen,         UL_JT_STR_GETLEN
THUNK_A ulstr_getprintlen,    UL_JT_STR_GETPRINTLEN
THUNK_A ulstr_getrawlen,      UL_JT_STR_GETRAWLEN
THUNK_A ulstr_compare,        UL_JT_STR_COMPARE
THUNK_A ulstr_find,           UL_JT_STR_FIND
THUNK_A ulstr_rfind,          UL_JT_STR_RFIND
THUNK_A ulstr_append,         UL_JT_STR_APPEND
THUNK_A ulstr_mid,            UL_JT_STR_MID
THUNK_A ulstr_toUtf8,         UL_JT_STR_TOUTF8
THUNK_A ulstr_addref,         UL_JT_STR_ADDREF
THUNK_A ulstr_release,        UL_JT_STR_RELEASE

; String tables
THUNK_A ulstb_create,         UL_JT_STB_CREATE
THUNK_A ulstb_delete,         UL_JT_STB_DELETE
THUNK_A ulstb_get,            UL_JT_STB_GET
THUNK_A ulstb_put,            UL_JT_STB_PUT
THUNK_A ulstb_build,          UL_JT_STB_BUILD
THUNK_A ulstb_load,           UL_JT_STB_LOAD

; Math
THUNK_A ulmath_abs_8,         UL_JT_MATH_ABS8
THUNK_A ulmath_negate_8,      UL_JT_MATH_NEG8
THUNK_A ulmath_scmp8_8,       UL_JT_MATH_SCMP8
THUNK_A ulmath_udiv8_8,       UL_JT_MATH_UDIV8
THUNK_A ulmath_udiv16_8,      UL_JT_MATH_UDIV16
THUNK_A ulmath_umul8_8,       UL_JT_MATH_UMUL8
THUNK_A ulmath_umul16_8,      UL_JT_MATH_UMUL16

; Character type
THUNK_A ul_isprint,           UL_JT_ISPRINT

; Internal (exposed for test)
THUNK_A ULS_access,           UL_JT_ULS_ACCESS

; =============================================================================
; Bank B thunks - Display
; =============================================================================

THUNK_B ulwin_box,            UL_JT_WIN_BOX
THUNK_B ulwin_busy,           UL_JT_WIN_BUSY
THUNK_B ulwin_clear,          UL_JT_WIN_CLEAR
THUNK_B ulwin_close,          UL_JT_WIN_CLOSE
THUNK_B ulwin_delchar,        UL_JT_WIN_DELCHAR
THUNK_B ulwin_delline,        UL_JT_WIN_DELLINE
THUNK_B ulwin_eraseeol,       UL_JT_WIN_ERASEEOL
THUNK_B ulwin_errorcfg,       UL_JT_WIN_ERRORCFG
THUNK_B ulwin_error,          UL_JT_WIN_ERROR
THUNK_B ulwin_flash,          UL_JT_WIN_FLASH
THUNK_B ulwin_flashwait,      UL_JT_WIN_FLASHWAIT
THUNK_B ulwin_force,          UL_JT_WIN_FORCE
THUNK_B ulwin_getchar,        UL_JT_WIN_GETCHAR
THUNK_B ulwin_getcolor,       UL_JT_WIN_GETCOLOR
THUNK_B ulwin_getcolumn,      UL_JT_WIN_GETCOLUMN
THUNK_B ulwin_getcursor,      UL_JT_WIN_GETCURSOR
THUNK_B ulwin_gethit,         UL_JT_WIN_GETHIT
THUNK_B ulwin_getkey,         UL_JT_WIN_GETKEY
THUNK_B ulwin_getline,        UL_JT_WIN_GETLINE
THUNK_B ulwin_getpos,         UL_JT_WIN_GETPOS
THUNK_B ulwin_getsize,        UL_JT_WIN_GETSIZE
THUNK_B ulwin_getstr,         UL_JT_WIN_GETSTR
THUNK_B ulwin_getwin,         UL_JT_WIN_GETWIN
THUNK_B ulwin_idlecfg,        UL_JT_WIN_IDLECFG
THUNK_B ulwin_inschar,        UL_JT_WIN_INSCHAR
THUNK_B ulwin_insline,        UL_JT_WIN_INSLINE
THUNK_B ulwin_move,           UL_JT_WIN_MOVE
THUNK_B ulwin_open,           UL_JT_WIN_OPEN
THUNK_B ulwin_putchar,        UL_JT_WIN_PUTCHAR
THUNK_B ulwin_putcolor,       UL_JT_WIN_PUTCOLOR
THUNK_B ulwin_putcursor,      UL_JT_WIN_PUTCURSOR
THUNK_B ulwin_putloc,         UL_JT_WIN_PUTLOC
THUNK_B ulwin_putstr,         UL_JT_WIN_PUTSTR
THUNK_B ulwin_puttitle,       UL_JT_WIN_PUTTITLE
THUNK_B ulwin_refresh,        UL_JT_WIN_REFRESH
THUNK_B ulwin_scroll,         UL_JT_WIN_SCROLL
THUNK_B ulwin_select,         UL_JT_WIN_SELECT
THUNK_B ulwin_getloc,         UL_JT_WIN_GETLOC
THUNK_B ulwin_resize,         UL_JT_WIN_RESIZE
THUNK_B ulwin_splitline,      UL_JT_WIN_SPLITLINE
THUNK_B ulwin_splitcolumn,    UL_JT_WIN_SPLITCOLUMN
THUNK_B ulwin_joinlines,      UL_JT_WIN_JOINLINES
THUNK_B ulwin_joincolumns,    UL_JT_WIN_JOINCOLUMNS
THUNK_B ulwin_picklist,       UL_JT_WIN_PICKLIST
THUNK_B ulwin_input,          UL_JT_WIN_INPUT
