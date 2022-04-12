.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

; Utilities/data
.global UL_lasterr

; File utilities
.global ULF_readblock
.global ULF_writeblock

; Font utilities
.global ULFT_findcharinfo

; Memory utilities
.global ULM_numbanks

; VERA utilities
.global ULV_init
.global ULV_blt
.global ULV_bltsrc
.global ULV_bltdst
.global ULV_bltlen
.global ULV_plotchar
.global ULV_setpaletteentry

; Windowing utilities
.struct ULW_window
slin        .byte
scol        .byte
elin        .byte
ecol        .byte
clin        .byte
ccol        .byte
flags       .byte
color       .byte
emcolor     .byte
title_bank  .byte
title_addr  .word
save        .word
prev        .byte
next        .byte
.endstruct
