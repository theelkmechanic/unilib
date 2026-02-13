.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

; Utilities/data
.global UL_getrng
.global UL_chkrng
.global UL_adc16
.global UL_sbc16
.global UL_mulxby32
.global UL_divyxby32
.global UL_terminate

.global UL_lasterr
.globalzp UL_temp_l
.globalzp UL_temp_h
.globalzp UL_varptr
.globalzp UL_var2ptr
.globalzp UL_src_fptr
.globalzp UL_dst_fptr

; File utilities
.global ULF_readblock
.global ULF_writeblock

; Font utilities
.global ULFT_initfontcache
.global ULFT_findcharinfo
.global ULFT_baseglyph
.global ULFT_extraglyph
.global ULFT_charflags

; Pool allocator types
.enum ULPOOL
    DATABLOCK   = 0
    BLOCKLIST   = 1
    MSGBLOCK    = 2
.endenum

; Message block types
.enum ULMBT
    LIST_ENTRY  = 0
    STRING_FRAG = 1
.endenum

; Message block flags
.enum ULMBF
    READONLY    = $80
.endenum

; Data blocks (8 bytes, in ULPOOL::DATABLOCK)
.struct ULDATA_BLOCK
refcount    .word       ; reference count (0 = free)
size        .word       ; logical data size
brp         .word       ; data BRP (heap allocation)
dataptr     .word       ; resolved data address (bank in brp high byte)
.endstruct

; Blocklists (8 bytes, in ULPOOL::BLOCKLIST)
.struct ULBLOCK_LIST
refcount    .word       ; reference count (0 = free)
size        .word       ; number of entries
head        .word       ; first message block handle ($0000 = empty)
tail        .word       ; last message block handle ($0000 = empty)
.endstruct

; Message blocks (16 bytes, in ULPOOL::MSGBLOCK)
.struct ULMSG_BLOCK
refcount    .word       ; 0-1:   reference count (0 = free)
data_block  .word       ; 2-3:   data block pool handle
start       .word       ; 4-5:   start offset into data block's data
end         .word       ; 6-7:   end offset (exclusive)
cont        .word       ; 8-9:   continuation msg block ($0000 = none)
next        .word       ; 10-11: next in list/queue ($0000 = none)
prev        .word       ; 12-13: prev in list/queue ($0000 = none)
type        .byte       ; 14:    block type
flags       .byte       ; 15:    flags
.endstruct

; Pool allocator API
.global ULPOOL_init
.global ulpool_alloc
.global ulpool_free
.global ulpool_access

; Iterator internals
.global ULI_load
.global ULI_save_cur
.global ULI_at_end
.global ULI_at_start
.global ULI_get_step
.global ULI_inc_cur
.global ULI_dec_cur
.global ULI_scratch
.globalzp ULI_ptr
.globalzp ULI_cur
.global ULI_cur_bank
.global ULI_state_bank
.global ULI_type_format
.global ULI_step_forward
.global ULI_step_backward
.global ULI_do_fetch
.global ULI_do_store
.global ULI_utf8_step_forward
.global ULI_utf8_step_backward
.global ULI_utf8_fetch
.global ULI_utf8_store

; Iterator state layout (stored in a BRP, 10 bytes)
ULI_STATE_TYPE    = 0   ; type_format: bits 7=reverse, 6-4=format, 3-0=type
ULI_STATE_CUR     = 1   ; current address lo, hi, bank (3 bytes)
ULI_STATE_START   = 4   ; start address lo, hi, bank (3 bytes)
ULI_STATE_END     = 7   ; end address lo, hi, bank (3 bytes)
ULI_STATE_SIZE    = 10

; LIST-specific extended state (appended after standard 10 bytes)
ULI_STATE_TERM_MB     = 10  ; terminal MB handle (2 bytes) - tail for fwd, head for rev
ULI_STATE_CUR_MB      = 12  ; current message block handle (2 bytes, pool index)
ULI_STATE_BLK_START   = 14  ; current block data start (3 bytes: lo, hi, bank)
ULI_STATE_BLK_END     = 17  ; current block data end (3 bytes: lo, hi, bank)
ULI_LIST_STATE_SIZE   = 20

.global ULI_list_create
.global ULI_list_boundary_check
.global ULI_list_scratch

; Math utilities
.global ULM_multbl_init

; Memory utilities
.global ULM_init
.global ULM_slot2addr

; String utilities
.global ulstr_addref
.global ULS_access
.global ULS_str_scratch
.global ULS_length ; Get NUL-terminated UTF-8 sequence length
.global     ULS_bytelen ; resulting length (in bytes)
.global     ULS_charlen ; resulting length (in characters)
.global     ULS_printlen ; resulting length (in printable characters)
.global ULS_nextchar
.global ULS_copystrdata
.globalzp ULS_scratch_fptr
.globalzp ULS_scratch_char

; VERA utilities
.global ULV_init
.global ULV_setpaletteentry

.global ULV_blt
.global ULV_bltsrc
.global ULV_bltdst
.global ULV_bltlen

.global ULV_swap
.global ULV_setdirtylines
.global ULV_backbuf_offset
.global ULV_dirtylines

.global ULV_calcglyphcolors
.global ULV_basecolor
.global ULV_extracolor

.global ULV_plotchar
.global ULV_copyrect
.global ULV_clearrect
.global ULV_fillrect
.global ULVR_srcpos
.global ULVR_destpos
.global ULVR_size
.global ULVR_color

; Windowing utilities
.struct ULW_WINDOW
handle      .byte   ; Window handle
flags       .byte   ; Flags: 0x80 - border
scol        .byte   ; Start screen column of the inside of the window
slin        .byte   ; Start screen line of the inside of the window
ncol        .byte   ; Number of columns in the window
nlin        .byte   ; Number of lines in the window
ecol        .byte   ; Start screen column of the inside of the window + number of columns in the window
elin        .byte   ; Start screen line of the inside of the window + number of lines in the window
ccol        .byte   ; Current cursor column inside the window
clin        .byte   ; Current cursor line inside the window
color       .byte   ; Normal text color (low nibble = foreground, high nibble = background)
emcolor     .byte   ; Emphasis text color (low nibble = foreground, high nibble = background)
charbuf     .word   ; BRP to window character buffer (3 bytes for each tile in the window)
colorbuf    .word   ; BRP to window color buffer (1 byte for each tile in the window)
title       .word   ; Title string
next_handle .byte   ; Next window handle ($FF if none)
prev_handle .byte   ; Previous window handle ($FF if none)
status      .byte   ; Window status (0x80 - completely covered, 0x40 - partially occluded)
.endstruct

.global ULW_getwinentryptr
.global ULW_getwinptr
.global ULW_getwinstruct
.global ULW_copywinstruct
.struct ULW_WINDOW_COPY
            .org $06e0
handle      .byte   ; Window handle
flags       .byte   ; Flags: 0x80 - border
scol        .byte   ; Start screen column of the inside of the window
slin        .byte   ; Start screen line of the inside of the window
ncol        .byte   ; Number of columns in the window
nlin        .byte   ; Number of lines in the window
ecol        .byte   ; Start screen column of the inside of the window + number of columns in the window
elin        .byte   ; Start screen line of the inside of the window + number of lines in the window
ccol        .byte   ; Current cursor column inside the window
clin        .byte   ; Current cursor line inside the window
color       .byte   ; Normal text color (low nibble = foreground, high nibble = background)
emcolor     .byte   ; Emphasis text color (low nibble = foreground, high nibble = background)
charbuf     .word   ; BRP to window character buffer (3 bytes for each tile in the window)
colorbuf    .word   ; BRP to window color buffer (1 byte for each tile in the window)
title       .word   ; Title string
next_handle .byte   ; Next window handle ($FF if none)
prev_handle .byte   ; Previous window handle ($FF if none)
status      .byte   ; Window status (0x80 - completely covered, 0x40 - partially occluded)
.endstruct

ULWS_OCCLUDED   = $40
ULWS_COVERED    = $80

.global ULW_inerror
.global ULW_errorfg
.global ULW_errorbg
.global ULW_keyfg
.global ULW_keybg
.global ULW_keyidle

.global ULW_drawchar
.global ULW_drawstring
.global ULW_fillrect
.global ULW_clearrect
.global ULW_copyrect
.global ULWR_src
.global ULWR_srcsize
.global ULWR_dest
.global ULWR_destsize
.global ULWR_char
.global ULWR_color

.global ULW_intersectsrc
.global ULW_intersectdest
.global ULW_intersectrect

.global ULW_box
.global ULW_boxtop
.global ULW_boxbottom
.global ULW_boxleft
.global ULW_boxright

.global ULW_clear
.global ULW_drawborder
.global ULW_getpos
.global ULW_getsize
.global ULW_getcursor
.global ULW_putcolor
.global ULW_putcursor
.global ULW_freebuf

.global ULW_winlist_loop
.global ULW_winlist
.global ULW_current_handle

.global ULW_screen_handle
.global ULW_screen_size

.global ULW_maprect_loop
.global ULW_update_occlusion
.global ULW_set_dirty_rect
.global ULW_dirty
.global ULW_dirtyrect
ULW_WINMAP = $AE00

.global ULW_getwinbufptr
.global ULW_linelen
.global ULW_linestride

.globalzp ULW_scratch_fptr

.macro PUSHREGS numregs
    ldx #0
:   lda gREG::r0L,x
    pha
    inx
    cpx #(numregs*2)
    bne :-
.endmacro

.macro POPREGS numregs
    ldx #(numregs*2)-1
:   pla
    sta gREG::r0L,x
    dex
    bpl :-
.endmacro
