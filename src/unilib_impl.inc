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
.global ULM_access
.global ULM_alloc
.global ULM_free
.global ULM_numbanks
.global ULM_slot2addr

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
.global ULV_changerectcolor
.global ULVR_srcpos
.global ULVR_destpos
.global ULVR_size
.global ULVR_color

; Windowing utilities
.struct ULW_WINDOW
handle      .byte   ; Window handle
flags       .byte   ; Flags: 0x80 - border, 0x40 - occluded, 0x01 - completely covered
slin        .byte   ; Start screen line of the inside of the window
nlin        .byte   ; Number of lines in the window
elin        .byte   ; Start screen line of the inside of the window + number of lines in the window
clin        .byte   ; Current cursor line inside the window
scol        .byte   ; Start screen column of the inside of the window
ncol        .byte   ; Number of columns in the window
ecol        .byte   ; Start screen column of the inside of the window + number of columns in the window
ccol        .byte   ; Current cursor column inside the window
color       .byte   ; Normal text color (low nibble = foreground, high nibble = background)
emcolor     .byte   ; Emphasis text color (low nibble = foreground, high nibble = background)
buf_ptr     .word   ; BRP to window contents buffer (3 bytes for each character in the inside of the window)
title_addr  .word   ; Address of title text (UTF-16, null if none)
title_bank  .byte   ; Bank RAM page for title text (0 if none/not needed)
prev_addr   .word   ; Address of previous window structure (null if none)
prev_bank   .byte   ; Bank RAM page of previous window structure (0 if none)
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
flags       .byte   ; Flags: 0x80 - border, 0x40 - occluded, 0x01 - completely covered
slin        .byte   ; Start screen line of the inside of the window
nlin        .byte   ; Number of lines in the window
elin        .byte   ; Start screen line of the inside of the window + number of lines in the window
clin        .byte   ; Current cursor line inside the window
scol        .byte   ; Start screen column of the inside of the window
ncol        .byte   ; Number of columns in the window
ecol        .byte   ; Start screen column of the inside of the window + number of columns in the window
ccol        .byte   ; Current cursor column inside the window
color       .byte   ; Normal text color (low nibble = foreground, high nibble = background)
emcolor     .byte   ; Emphasis text color (low nibble = foreground, high nibble = background)
buf_ptr     .word   ; BRP to window contents buffer (3 bytes for each character in the inside of the window)
title_addr  .word   ; Address of title text (UTF-16, null if none)
title_bank  .byte   ; Bank RAM page for title text (0 if none/not needed)
prev_addr   .word   ; Address of previous window structure (null if none)
prev_bank   .byte   ; Bank RAM page of previous window structure (0 if none)
next_addr   .word   ; Address of next window structure (null if none)
next_bank   .byte   ; Bank RAM page of next window structure (0 if none)
.endstruct

ULWF_BORDER     = $80
ULWF_OCCLUDED   = $40
ULWF_COVERED    = $01

.global ULW_inerror
.global ULW_errorfg
.global ULW_errorbg
.global ULW_keyfg
.global ULW_keybg
.global ULW_keyidle

.global ULW_border
.global ULW_clear
.global ULW_getloc
.global ULW_getsize
.global ULW_putcolor
.global ULW_putcursor

.global ULW_winlist_loop
.global ULW_winlist
.global ULW_screen_handle
.global ULW_current_handle

.global ULW_maprect_loop
.global ULW_update_occlusion
.global ULW_set_dirty_rect
ULW_WINMAP = $AD00

.globalzp ULW_screen_fptr
.globalzp ULW_current_fptr
.globalzp ULW_scratch_fptr
