; ULFT_plotchar - Draw a UTF-16 character at a specified screen location

.include "unilib_impl.inc"

.code

; ULFT_plotchar - Draw a UTF-16 character at a specified screen location
; In:   r0          - UTF-16 character (little-endian)
;       r1          - Screen location (column=low, row=high)
;       r2L         - Foreground color (1-15, undefined behavior if out of range)
;       r2H         - Background color (1-15, undefined behavior if out of range)
; Out:  carry       - Set if character plotted
.proc ULV_plotchar
    ; Check the screen coordinates are in range
    pha
    phx
    phy
    lda gREG::r1L
    cmp #80
    bcs @noplot
    lda gREG::r1H
    cmp #30
    bcc @lookup
@noplot:
    clc
    bra @exit

@lookup:
    ; Look up the character info
    ldx gREG::r0L
    ldy gREG::r0H
    jsr ULFT_findcharinfo
    bcs @gotchar

@exit:
    ply
    plx
    pla
    rts

@gotchar:
    ; Save the character info
    stx gREG::r11L
    sty gREG::r11H
    sta gREG::r12L

    ; Do we need to reverse the colors?
    ldx gREG::r2L
    ldy gREG::r2H
    bit #$80
    beq @draw_glyphs

    ; Swap the colors
    phx
    phy
    plx
    ply

@draw_glyphs:
    ; Put the foreground color in the flags high nibble so we can use it for the overlay (r12L),
    ; and merge the foreground and background colors for the base (r12H)
    lda gREG::r12L
    and #$0f
    sta gREG::r12L
    txa
    asl
    asl
    asl
    asl
    ora gREG::r12L
    sta gREG::r12L
    txa
    and #$0f
    sta gREG::r12H
    tya
    asl
    asl
    asl
    asl
    ora gREG::r12H
    sta gREG::r12H

    ; Set the location to write (base page)
    lda gREG::r1L
    asl
    tax
    lda gREG::r1H
    tay
    lda VERA::CTRL
    and #$fe
    sta VERA::CTRL
    lda #VERA::INC1
    sta VERA::ADDR+2
    sty VERA::ADDR+1
    stx VERA::ADDR

    ; Set the location to write (overlay page)
    lda VERA::CTRL
    ora #$01
    sta VERA::CTRL
    lda #VERA::INC1
    sta VERA::ADDR+2
    tya
    clc
    adc #$40
    sta VERA::ADDR+1
    stx VERA::ADDR

    ; Write the normal character glyph and color
    lda gREG::r11L
    sta VERA::DATA0
    lda gREG::r12H
    sta VERA::DATA0

    ; Write the extras character glyph and color
    lda gREG::r11H
    sta VERA::DATA1
    lda gREG::r12L
    sta VERA::DATA1
    sec
    bra @exit
.endproc
