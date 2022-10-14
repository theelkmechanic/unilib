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
.globalzp UL_src_rng
.globalzp UL_dst_fptr
.globalzp UL_dst_rng
.globalzp UL_len

; File utilities
.global ULF_readblock
.global ULF_writeblock

; Font utilities
.global ULFT_initfontcache
.global ULFT_findcharinfo
.global ULFT_baseglyph
.global ULFT_extraglyph
.global ULFT_charflags

; Data blocks
.struct ULDATA_BLOCK
refcount    .word       ; reference count
size        .word       ; size
brp         .word       ; BRP
dataptr     .word       ; actual data pointer (bank is high byte of brp)
.endstruct

; Blocklists
.struct ULBLOCK_LIST
refcount    .word       ; reference count
size        .word       ; size
capacity    .word       ; capacity (>= size)
brps        .word       ; array of data block handles
.endstruct

; Iterators
.global ULI_adv
.global ULI_rew


; Math utilities
.global ULM_multbl_init

; Memory utilities
.global ULM_init
.global ULM_slot2addr

; String utilities
.global ULS_access
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
