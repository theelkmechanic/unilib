.include "unilib_impl.inc"

.code

; ULV_setpaletteentry - Set palette entry
;   In: A               - Palette entry (0-15, 0 should be left black though)
;       YX              - Palette color
.proc ULV_setpaletteentry
                        ; We want to update palette entry A, and also palette entry A*16+3
                        pha
                        lda VERA::CTRL
                        and #$fe
                        sta VERA::CTRL
                        lda #$01 | VERA::INC1
                        sta VERA::ADDR+2
                        lda #$fa
                        sta VERA::ADDR+1
                        pla
                        pha
                        asl
                        sta VERA::ADDR
                        stx VERA::DATA0
                        sty VERA::DATA0
                        pla
                        pha
                        cmp #$08
                        lda #0
                        adc #$fa
                        sta VERA::ADDR+1
                        pla
                        pha
                        asl
                        asl
                        asl
                        asl
                        asl
                        clc
                        adc #6
                        sta VERA::ADDR
                        stx VERA::DATA0
                        sty VERA::DATA0
                        pla
                        rts
.endproc
