; unilib_rom.inc - Application-facing header for UniLib ROM builds
;
; Include this file in applications that call UniLib from ROM banks.
; Use UL_CALL_A / UL_CALL_B macros to invoke UniLib functions through
; the KERNAL jsrfar mechanism.

; ROM bank assignments
UNILIB_BANK_A = $10     ; Foundation + Data (memory, pools, lists, iterators, math, strings, core)
UNILIB_BANK_B = $11     ; Display (windows, VERA, font, string rendering)
UNILIB_BANK_C = $12     ; Font data (LZSA2 compressed)

; Call a function in Bank A via KERNAL jsrfar
.macro UL_CALL_A addr
    jsr $FF6E
    .word addr
    .byte UNILIB_BANK_A
.endmacro

; Call a function in Bank B via KERNAL jsrfar
.macro UL_CALL_B addr
    jsr $FF6E
    .word addr
    .byte UNILIB_BANK_B
.endmacro

; =============================================================================
; Jump table addresses (Bank A - Foundation + Data)
; Each entry is a 3-byte jmp instruction at the start of the bank.
; =============================================================================
UL_JT_INIT              = $C000  ; ul_init
UL_JT_GETERROR          = $C003  ; ul_geterror
UL_JT_MEM_ALLOC         = $C006  ; ulmem_alloc
UL_JT_MEM_REALLOC       = $C009  ; ulmem_realloc
UL_JT_MEM_FREE          = $C00C  ; ulmem_free
UL_JT_MEM_ACCESS        = $C00F  ; ulmem_access
UL_JT_MEM_CAPACITY      = $C012  ; ulmem_capacity
UL_JT_DB_CREATE         = $C015  ; uldb_create
UL_JT_DB_FROMBRP        = $C018  ; uldb_fromBRP
UL_JT_DB_FROMBUFFER     = $C01B  ; uldb_fromBuffer
UL_JT_DB_FROMITER       = $C01E  ; uldb_fromIter
UL_JT_DB_GETREFCOUNT    = $C021  ; uldb_getrefcount
UL_JT_DB_ADDREF         = $C024  ; uldb_addref
UL_JT_DB_RELEASE        = $C027  ; uldb_release
UL_JT_DB_GETSIZE        = $C02A  ; uldb_getsize
UL_JT_DB_GETCAPACITY    = $C02D  ; uldb_getcapacity
UL_JT_DB_GETBRP         = $C030  ; uldb_getbrp
UL_JT_LIST_CREATE       = $C033  ; ullist_create
UL_JT_LIST_GETREFCOUNT  = $C036  ; ullist_getrefcount
UL_JT_LIST_ADDREF       = $C039  ; ullist_addref
UL_JT_LIST_RELEASE      = $C03C  ; ullist_release
UL_JT_LIST_GETSIZE      = $C03F  ; ullist_getsize
UL_JT_LIST_INSERT       = $C042  ; ullist_insert
UL_JT_LIST_DELETE       = $C045  ; ullist_delete
UL_JT_LIST_GETAT        = $C048  ; ullist_getat
UL_JT_ITR_CREATE        = $C04B  ; ulitr_create
UL_JT_ITR_DELETE        = $C04E  ; ulitr_delete
UL_JT_ITR_FETCH         = $C051  ; ulitr_fetch
UL_JT_ITR_STORE         = $C054  ; ulitr_store
UL_JT_ITR_FETCH_AND_INC = $C057  ; ulitr_fetch_and_inc
UL_JT_ITR_FETCH_AND_DEC = $C05A  ; ulitr_fetch_and_dec
UL_JT_ITR_INC           = $C05D  ; ulitr_inc
UL_JT_ITR_DEC           = $C060  ; ulitr_dec
UL_JT_ITR_ADV           = $C063  ; ulitr_adv
UL_JT_ITR_REW           = $C066  ; ulitr_rew
UL_JT_ITR_ATSTART       = $C069  ; ulitr_atstart
UL_JT_ITR_ATEND         = $C06C  ; ulitr_atend
UL_JT_STR_FROMUTF8      = $C06F  ; ulstr_fromUtf8
UL_JT_STR_GETLEN        = $C072  ; ulstr_getlen
UL_JT_STR_GETPRINTLEN   = $C075  ; ulstr_getprintlen
UL_JT_STR_GETRAWLEN     = $C078  ; ulstr_getrawlen
UL_JT_STR_COMPARE       = $C07B  ; ulstr_compare
UL_JT_STR_FIND          = $C07E  ; ulstr_find
UL_JT_STR_RFIND         = $C081  ; ulstr_rfind
UL_JT_STR_APPEND        = $C084  ; ulstr_append
UL_JT_STR_MID           = $C087  ; ulstr_mid
UL_JT_STR_TOUTF8        = $C08A  ; ulstr_toUtf8
UL_JT_STR_ADDREF        = $C08D  ; ulstr_addref
UL_JT_STR_RELEASE       = $C090  ; ulstr_release
UL_JT_STB_CREATE        = $C093  ; ulstb_create
UL_JT_STB_DELETE        = $C096  ; ulstb_delete
UL_JT_STB_GET           = $C099  ; ulstb_get
UL_JT_STB_PUT           = $C09C  ; ulstb_put
UL_JT_STB_BUILD         = $C09F  ; ulstb_build
UL_JT_STB_LOAD          = $C0A2  ; ulstb_load
UL_JT_MATH_ABS8         = $C0A5  ; ulmath_abs_8
UL_JT_MATH_NEG8         = $C0A8  ; ulmath_negate_8
UL_JT_MATH_SCMP8        = $C0AB  ; ulmath_scmp8_8
UL_JT_MATH_UDIV8        = $C0AE  ; ulmath_udiv8_8
UL_JT_MATH_UDIV16       = $C0B1  ; ulmath_udiv16_8
UL_JT_MATH_UMUL8        = $C0B4  ; ulmath_umul8_8
UL_JT_MATH_UMUL16       = $C0B7  ; ulmath_umul16_8
UL_JT_ISPRINT           = $C0BA  ; ul_isprint
UL_JT_ULS_ACCESS        = $C0BD  ; ULS_access (internal, exposed for test)

; =============================================================================
; Jump table addresses (Bank B - Display)
; Unimplemented functions omitted; will be added at end when ready.
; =============================================================================
UL_JT_WIN_BOX           = $C000  ; ulwin_box
UL_JT_WIN_BUSY          = $C003  ; ulwin_busy
UL_JT_WIN_CLEAR         = $C006  ; ulwin_clear
UL_JT_WIN_CLOSE         = $C009  ; ulwin_close
UL_JT_WIN_DELCHAR       = $C00C  ; ulwin_delchar
UL_JT_WIN_DELLINE       = $C00F  ; ulwin_delline
UL_JT_WIN_ERASEEOL      = $C012  ; ulwin_eraseeol
UL_JT_WIN_ERRORCFG      = $C015  ; ulwin_errorcfg
UL_JT_WIN_ERROR         = $C018  ; ulwin_error
UL_JT_WIN_FLASH         = $C01B  ; ulwin_flash
UL_JT_WIN_FLASHWAIT     = $C01E  ; ulwin_flashwait
UL_JT_WIN_FORCE         = $C021  ; ulwin_force
UL_JT_WIN_GETCHAR       = $C024  ; ulwin_getchar
UL_JT_WIN_GETCOLOR      = $C027  ; ulwin_getcolor
UL_JT_WIN_GETCOLUMN     = $C02A  ; ulwin_getcolumn
UL_JT_WIN_GETCURSOR     = $C02D  ; ulwin_getcursor
UL_JT_WIN_GETHIT        = $C030  ; ulwin_gethit
UL_JT_WIN_GETKEY        = $C033  ; ulwin_getkey
UL_JT_WIN_GETLINE       = $C036  ; ulwin_getline
UL_JT_WIN_GETPOS        = $C039  ; ulwin_getpos
UL_JT_WIN_GETSIZE       = $C03C  ; ulwin_getsize
UL_JT_WIN_GETSTR        = $C03F  ; ulwin_getstr
UL_JT_WIN_GETWIN        = $C042  ; ulwin_getwin
UL_JT_WIN_IDLECFG       = $C045  ; ulwin_idlecfg
UL_JT_WIN_INSCHAR       = $C048  ; ulwin_inschar
UL_JT_WIN_INSLINE       = $C04B  ; ulwin_insline
UL_JT_WIN_MOVE          = $C04E  ; ulwin_move
UL_JT_WIN_OPEN          = $C051  ; ulwin_open
UL_JT_WIN_PUTCHAR       = $C054  ; ulwin_putchar
UL_JT_WIN_PUTCOLOR      = $C057  ; ulwin_putcolor
UL_JT_WIN_PUTCURSOR     = $C05A  ; ulwin_putcursor
UL_JT_WIN_PUTLOC        = $C05D  ; ulwin_putloc
UL_JT_WIN_PUTSTR        = $C060  ; ulwin_putstr
UL_JT_WIN_PUTTITLE      = $C063  ; ulwin_puttitle
UL_JT_WIN_REFRESH       = $C066  ; ulwin_refresh
UL_JT_WIN_SCROLL        = $C069  ; ulwin_scroll
UL_JT_WIN_SELECT        = $C06C  ; ulwin_select
