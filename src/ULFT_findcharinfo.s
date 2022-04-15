; ULFT_findcharinfo - Find the base/overlay glyphs and flags for a given UTF-16 character

.include "unilib_impl.inc"

.code

; ULFT_findcharinfo - Find the character info table entry for the specified UTF-16 character
; In:   x/y         - UTF-16 character (x=lo, y=hi)
; Out:  a           - character flags
;       x           - base character glyph
;       y           - overlay character glyph
;       carry       - set if character info was found
.proc ULFT_findcharinfo
    ; Map starts at $11000 in VRAM. Each block starts with 3 bytes:
    ;   - Starting UTF-16 character in block (word, little-endian)
    ;   - Number of characters in block (byte)
    ; Each entry in the block is 3 bytes long:
    ;   - Base character glyph
    ;   - Overlay character glyph
    ;   - Character flags (top nibble) / Overlay character glyph color low nibble (bottom nibble)

    ; Use VERA::DATA1, start looking at $11000 with autoincrement 1
    lda VERA::CTRL
    ora #$01
    sta VERA::CTRL
    lda #VERA::INC1 | 1
    sta VERA::ADDR+2
    lda #$10
    sta VERA::ADDR+1
    stz VERA::ADDR

@scan_maps:
    ; Once we hit the $1F9xx portion of VRAM, we're done
    lda VERA::ADDR+1
    cmp #$f9
    bcs @not_found

    ; Read the map entry and store in r11/r12L
    lda VERA::DATA1
    sta gREG::r11L
    lda VERA::DATA1
    sta gREG::r11H

    ; If we get to a zero-length block, we're done
    lda VERA::DATA1
    beq @not_found
    sta gREG::r12L

    ; If we hit a block that's greater than our character, we're done, because our maps are in
    ; ascending order
    cpy gREG::r11H
    bne :+
    cpx gREG::r11L
:   bcs @in_range_low

@not_found:
    clc
    rts

@in_range_low:
    ; Check that starting char + size > our char (calcuate last char in r13)
    lda gREG::r11L
    clc
    adc gREG::r12L
    sta gREG::r13L
    lda gREG::r11H
    adc #0
    sta gREG::r13H
    cpy gREG::r13H
    bne :+
    cpx gREG::r13L

    ; If we're past the end, skip to the next map
:   bcs @next_map

    ; We found the right map. The font entry address is at:
    ;   VERA::ADDR1 + (our char - starting char) * 3
    ; which is the same as:
    ;   map_base + (our char - starting char) * 2 + (our char - starting char).

    ; Subtract our char - starting char and store it twice (overwrite r11 and r12)
    txa
    sec
    sbc gREG::r11L
    sta gREG::r11L
    sta gREG::r12L
    tya
    sbc gREG::r11H
    sta gREG::r11H
    sta gREG::r12H

    ; Multiply one of them by 2
    asl gREG::r12L
    rol gREG::r12H

    ; And add them
    lda gREG::r11L
    clc
    adc gREG::r12L
    sta gREG::r11L
    lda gREG::r11H
    adc gREG::r12H
    sta gREG::r11H

    ; Move the VERA::ADDR1 ahead
    lda VERA::ADDR
    clc
    adc gREG::r11L
    sta VERA::ADDR
    lda VERA::ADDR+1
    adc gREG::r11H
    sta VERA::ADDR+1

    ; Read the character info
    ldx VERA::DATA1
    ldy VERA::DATA1
    lda VERA::DATA1

    ; And we're done--is it a valid glyph?
    bit #$40
    bne @not_found
    sec
    rts

    ; Jump to the next map (advance r12L*3 bytes)
@next_map:
    lda gREG::r12L
    sta gREG::r11L
    stz gREG::r11H
    asl gREG::r11L
    rol gREG::r11H
    clc
    adc gREG::r11L
    sta gREG::r11L
    lda gREG::r11H
    adc #0
    sta gREG::r11H
    lda VERA::ADDR
    clc
    adc gREG::r11L
    sta VERA::ADDR
    lda VERA::ADDR+1
    adc gREG::r11H
    sta VERA::ADDR+1
    jmp @scan_maps
.endproc
