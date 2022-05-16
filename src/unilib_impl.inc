.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

; Utilities/data
.global UL_lasterr
.global UL_terminate
.global UL_temp_l
.global UL_temp_h

; File utilities
.global ULF_readblock
.global ULF_writeblock

; Font utilities
.global ULFT_initfontcache
.global ULFT_findcharinfo
.global ULFT_baseglyph
.global ULFT_extraglyph
.global ULFT_charflags

; Math utilities
.global ULM_multbl_init

; Memory utilities
.global ULM_init
.global ULM_slot2addr

; String utilities
.global ULS_length ; Get NUL-terminated UTF-8 sequence length
.global     ULS_bytelen ; resulting length (in bytes)
.global     ULS_charlen ; resulting length (in characters)
.global     ULS_printlen ; resulting length (in printable characters)
.global ULS_nextchar
.globalzp ULS_scratch_fptr

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
flags       .byte   ; Flags: 0x80 - border, 0x40 - occluded, 0x01 - completely covered
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
prev_addr   .word   ; Address of previous window structure (null if none)
prev_bank   .byte   ; Bank RAM page of previous window structure (0 if none)
status      .byte   ; Window status (0x80 - completely covered, 0x40 - partially occluded)
next_addr   .word   ; Address of next window structure (null if none)
next_bank   .byte   ; Bank RAM page of next window structure (0 if none)
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
prev_addr   .word   ; Address of previous window structure (null if none)
prev_bank   .byte   ; Bank RAM page of previous window structure (0 if none)
status      .byte   ; Window status (0x80 - completely covered, 0x40 - partially occluded)
next_addr   .word   ; Address of next window structure (null if none)
next_bank   .byte   ; Bank RAM page of next window structure (0 if none)
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

.global ULW_winlist_loop
.global ULW_winlist
.global ULW_screen_handle
.global ULW_current_handle

.global ULW_maprect_loop
.global ULW_update_occlusion
.global ULW_set_dirty_rect
.global ULW_dirty
.global ULW_dirtyrect
ULW_WINMAP = $AE00

.global ULW_getwinbufptr
.global ULW_linelen
.global ULW_linestride
.globalzp ULW_winbufptr
.globalzp ULW_winsrcptr

.globalzp ULW_screen_fptr
.globalzp ULW_current_fptr
.globalzp ULW_scratch_fptr
.global ULW_scratchtocurrent
