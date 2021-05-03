; ULV_init - Initialize the VERA for UniLib

.include "unilib_impl.inc"
.include "cbm_kernal.inc"

.code

; ULV_init - Initializes the VERA to display 80x30 Unicode text:
;   - Map size = 128x32, tile size = 8x16
;   - Layer 0 (base) text mode:
;       - 1bpp, T256C=0
;       - map is at $00000 (8k)
;       - line stride is 256
;       - tile set is at $04000 (4k)
;   - Layer 1 (overlay) text mode
;       - 2bpp (allows 1024 glyphs plus transforms)
;       - map is from $02000 (8k)
;       - line stride is 256
;       - tile set is at $05000 (32k)
;
; In:   r0          Font filename
;       r1L         Font filename length
;       r1H         Drive # to load from
; Out:  a           Error code (0=success)

.proc ULV_init
    ; Load font to $04000 in VRAM (4K layer 0 base glyphs, 32K layer 1 overlay
    ; glyphs, up to 12k of glyph maps)
    lda #1
    ldx gREG::r1H
    ldy #2
    jsr SETLFS
    lda gREG::r1L
    ldx gREG::r0L
    ldy gREG::r0H
    jsr SETNAM
    lda #2
    ldx #0
    ldy #$40
    jsr LOAD
    bcc :+
    lda #ULERR::CANT_LOAD_FONT
    sta UL_lasterr
    rts

    ; Configure the display compositor
:   lda VERA::CTRL
    and #<(~VERA::DISP::SELECT1)
    sta VERA::CTRL
    lda VERA::DISP::VIDEO
    and #<(~VERA::DISP::ENABLE::SPRITES)
    ora #(VERA::DISP::ENABLE::LAYER0 | VERA::DISP::ENABLE::LAYER1)
    sta VERA::DISP::VIDEO
    lda #$80
    sta VERA::DISP::HSCALE
    sta VERA::DISP::VSCALE
    stz VERA::DISP::FRAME
    lda VERA::CTRL
    ora #VERA::DISP::SELECT1
    sta VERA::CTRL
    stz VERA::DISP::HSTART
    stz VERA::DISP::VSTART
    lda #160
    sta VERA::DISP::HSTOP
    lda #240
    sta VERA::DISP::VSTOP

    ; Configure layer 0
    lda #VERA::MAP::WIDTH128 | VERA::MAP::HEIGHT32 | VERA::TILE1BPP
    sta VERA::L0::CONFIG
    stz VERA::L0::MAP_BASE
    lda #VERA::TILE::WIDTH8 | VERA::TILE::HEIGHT16 | ($040 >> 1)
    sta VERA::L0::TILE_BASE
    stz VERA::L0::HSCROLL
    stz VERA::L0::HSCROLL+1
    stz VERA::L0::VSCROLL
    stz VERA::L0::VSCROLL+1

    ; Configure layer 1
    lda #VERA::MAP::WIDTH128 | VERA::MAP::HEIGHT32 | VERA::TILE2BPP
    sta VERA::L1::CONFIG
    lda #($020 >> 1)
    sta VERA::L1::MAP_BASE
    lda #VERA::TILE::WIDTH8 | VERA::TILE::HEIGHT16 | ($050 >> 1)
    sta VERA::L1::TILE_BASE
    stz VERA::L1::HSCROLL
    stz VERA::L1::HSCROLL+1
    stz VERA::L1::VSCROLL
    stz VERA::L1::VSCROLL+1

    ; Setup palette colors
    ldx #15
:   jsr ULV_setpaletteentry
    dex
    bne :-

    ; Clear layer 0 with 8K of white-on-black spaces and layer 1 with 8K of 0s
    lda VERA::CTRL
    and #$fe
    sta VERA::CTRL
    stz VERA::ADDR
    stz VERA::ADDR+1
    lda #$10
    sta VERA::ADDR+2
    lda VERA::CTRL
    ora #$01
    sta VERA::CTRL
    stz VERA::ADDR
    lda #$20
    sta VERA::ADDR+1
    lda #$10
    sta VERA::ADDR+2
    ldy #(ULCOLOR::BLACK << 4)  | ULCOLOR::WHITE
    lda #' '
:   stz VERA::DATA1
    stz VERA::DATA1
    sta VERA::DATA0
    sty VERA::DATA0
    bit VERA::ADDR+1
    bvc :-
    rts
.endproc

.proc ULV_setpaletteentry
    ; Read appropriate color
    txa
    dec
    asl
    tay
    lda ulv_colors,y
    sta gREG::r11L
    iny
    lda ulv_colors,y
    sta gREG::r11H

    ; We want to update palette entry x, and also palette entry x*16+3
    lda VERA::CTRL
    and #$fe
    sta VERA::CTRL
    lda #$01 | VERA::INC1
    sta VERA::ADDR+2
    lda #$fa
    sta VERA::ADDR+1
    txa
    asl
    sta VERA::ADDR
    lda gREG::r11L
    sta VERA::DATA0
    lda gREG::r11H
    sta VERA::DATA0
    txa
    cmp #$08
    bcc :+
    ldy #$fb
    .byte $2c
:   ldy #$fa
    sty VERA::ADDR+1
    asl
    asl
    asl
    asl
    asl
    clc
    adc #6
    sta VERA::ADDR
    lda gREG::r11L
    sta VERA::DATA0
    lda gREG::r11H
    sta VERA::DATA0
    rts
.endproc

.rodata

ulv_colors:
    .word   $000    ; black
    .word   $444    ; dark grey
    .word   $888    ; medium grey
    .word   $ccc    ; light grey
    .word   $fff    ; white
    .word   $a10    ; red
    .word   $850    ; brown
    .word   $1d7    ; green
    .word   $cfe    ; cyan
    .word   $03b    ; blue
    .word   $d6d    ; magenta
    .word   $f99    ; light red (pink)
    .word   $ee9    ; yellow
    .word   $bf8    ; light green
    .word   $1af    ; light blue
