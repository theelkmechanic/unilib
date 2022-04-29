.include "unilib_impl.inc"

ULFT_CACHE_SIZE = 256
ULFT_fontcache = $A900

ULFT_fontcache_hi       = ULFT_fontcache + (ULFT_CACHE_SIZE * 0)
ULFT_fontcache_plane    = ULFT_fontcache + (ULFT_CACHE_SIZE * 1)
ULFT_fontcache_base     = ULFT_fontcache + (ULFT_CACHE_SIZE * 2)
ULFT_fontcache_overlay  = ULFT_fontcache + (ULFT_CACHE_SIZE * 3)
ULFT_fontcache_flags    = ULFT_fontcache + (ULFT_CACHE_SIZE * 4)

.code

.proc ULFT_initfontcache
                        ; Allocate 5 pages for cache (256 entries) and clear
                        ldx #<(ULFT_CACHE_SIZE * 5)
                        ldy #>(ULFT_CACHE_SIZE * 5)
                        sec
                        jsr ULM_alloc

                        ; Clear the flags page with #$10 to indicate empty cache slots
                        lda #$10
                        ldx #0
:                       sta ULFT_fontcache_flags,x
                        inx
                        bne :-
                        rts
.endproc

; ULFT_findcharinfo - Find the character info table entry for the specified Unicode character
;   In: AYX              - Unicode character (X=lo, Y=hi, A=plane)
;  Out: A/ULFT_charflags - character flags
;       ULFT_baseglyph   - base layer character glyph
;       ULFT_extraglyph  - overlay layer character glyph
;       carry            - set if character info was found
.proc ULFT_findcharinfo
                        ; Save the character we're scanning for
                        stx ULFT_scanchar
                        sty ULFT_scanchar+1
                        sta ULFT_scanchar+2

                        ; Check cache for match
                        lda BANKSEL::RAM
                        pha
                        lda #1
                        sta BANKSEL::RAM
                        lda ULFT_fontcache_flags,x
                        bit #$10
                        bne @need_scan
                        tya
                        cmp ULFT_fontcache_hi,x
                        bne @need_scan
                        lda ULFT_scanchar+2
                        cmp ULFT_fontcache_plane,x
                        bne @need_scan

                        ; Found match, so just return it
                        sta ULFT_charflags
                        lda ULFT_fontcache_base,x
                        sta ULFT_baseglyph
                        lda ULFT_fontcache_overlay,x
                        sta ULFT_extraglyph
                        lda ULFT_charflags
                        jmp @have_glyph

                        ; Map starts at $11000 in VRAM. Each block starts with 4 bytes:
                        ;   - Starting UTF-16 character in block (three bytes, little-endian)
                        ;   - Number of characters in block (byte)
                        ; Each entry in the block is 3 bytes long:
                        ;   - Base character glyph
                        ;   - Overlay character glyph
                        ;   - Character flags (top nibble) / Overlay character glyph color low nibble (bottom nibble)
                        ;       * $80 = reverse character colors
                        ;       * $40 = no glyph (do not print)
                        ;       * $10 = (not a character flag--indicates empty cache slot)
                        ;       * $08 = flip overlay vertical
                        ;       * $04 = flip overlay horizontal
                        ;       * $03 = overlay index bits 9:8

                        ; Use VERA::DATA1, start looking at $11000 with autoincrement 1
@need_scan:             lda VERA::CTRL
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

                        ; Read the map entry and store in r11/r12
                        lda VERA::DATA1
                        sta ULFT_mapstart
                        lda VERA::DATA1
                        sta ULFT_mapstart+1
                        lda VERA::DATA1
                        sta ULFT_mapstart+2

                        ; If we get to a zero-length block, we're done
                        lda VERA::DATA1
                        beq @not_found
                        sta ULFT_maplen

                        ; For blocks where hi/plane are less than our character, we can skip to the next block.
                        ; If we hit a block that's greater than our character, we're done, because our maps are in
                        ; ascending order.
                        lda ULFT_scanchar+2
                        cmp ULFT_mapstart+2
                        bcc @next_map
                        bne @not_found
                        bcc @next_map
                        cpy ULFT_mapstart+1
                        bne @not_found
                        cpx ULFT_mapstart
                        bcs @in_range_low

                        ; Cache that character wasn't found/non-printing
@not_found:             lda #$40
                        clc
@restoreandexit:        sta ULFT_fontcache_flags,x
                        tya
                        sta ULFT_fontcache_hi,x
                        lda ULFT_scanchar+2
                        sta ULFT_fontcache_plane,x
                        pla
                        sta BANKSEL::RAM
                        lda ULFT_fontcache_flags,x
                        rts

                        ; Check that starting char + size > our char
@in_range_low:          lda ULFT_mapstart
                        clc
                        adc ULFT_maplen
                        sta ULFT_mapchar
                        lda ULFT_mapstart+1
                        adc #0
                        sta ULFT_mapchar+1
                        lda ULFT_mapstart+2
                        adc #0
                        sta ULFT_mapchar+2
                        cmp ULFT_scanchar+2
                        bne :+
                        cpy ULFT_mapchar+1
                        bne :+
                        cpx ULFT_mapchar

                        ; If we're past the end, skip to the next map
:                       bcs @next_map

                        ; We found the right map. The font entry address is at:
                        ;   VERA::ADDR1 + (our char - starting char) * 3
                        phx
                        phy
                        txa
                        sec
                        sbc ULFT_mapstart
                        ldx #3
                        jsr ulmath_umul8_8
                        stx ULFT_mapstart
                        sty ULFT_mapstart+1
                        ply
                        plx

                        ; Move the VERA::ADDR1 ahead
                        lda VERA::ADDR
                        clc
                        adc ULFT_mapstart
                        sta VERA::ADDR
                        lda VERA::ADDR+1
                        adc ULFT_mapstart+1
                        sta VERA::ADDR+1

                        ; Read the character info
                        lda VERA::DATA1
                        sta ULFT_baseglyph
                        lda VERA::DATA1
                        sta ULFT_extraglyph
                        lda VERA::DATA1
                        sta ULFT_charflags

                        ; And we're done--is it a valid glyph?
@have_glyph:            bit #$40
                        bne @not_found
                        pha
                        lda ULFT_baseglyph
                        sta ULFT_fontcache_base,x
                        lda ULFT_extraglyph
                        sta ULFT_fontcache_overlay,x
                        pla
                        sec
                        bra @restoreandexit

                        ; Jump to the next map (advance len*3 bytes)
@next_map:              phx
                        phy
                        lda ULFT_maplen
                        ldx #3
                        jsr ulmath_umul8_8
                        stx ULFT_mapstart
                        sty ULFT_mapstart+1
                        ply
                        plx
                        lda VERA::ADDR
                        clc
                        adc ULFT_mapstart
                        sta VERA::ADDR
                        lda VERA::ADDR+1
                        adc ULFT_mapstart+1
                        sta VERA::ADDR+1
                        jmp @scan_maps
.endproc

.bss

ULFT_scanchar:          .res    3
ULFT_mapstart:          .res    3
ULFT_mapchar:           .res    3
ULFT_maplen:            .res    1
ULFT_baseglyph:         .res    1
ULFT_extraglyph:        .res    1
ULFT_charflags:         .res    1
