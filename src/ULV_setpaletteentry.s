; ULV_setpaletteentry - Set palette entries based on our color table

.include "unilib_impl.inc"

.code

.proc ULV_setpaletteentry
    ; Read appropriate color entry from our table
    txa
    dec
    asl
    tay
    lda ULV_colors,y
    sta gREG::r11L
    iny
    lda ULV_colors,y
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
    lda #$fa
    cpx #$08
    adc #0
    sta VERA::ADDR+1
    txa
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

ULV_colors:
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
