; UL_petscii - Shared PETSCII to Unicode codepoint conversion helper

.include "unilib_impl.inc"

UL_CODE

; UL_petscii_to_codepoint - Convert PETSCII byte to Unicode codepoint
;   In: X               - PETSCII byte value
;  Out: X               - Codepoint low byte
;       Y               - Codepoint high byte
;       carry            - Clear if valid, set if skip ($0000)
.proc UL_petscii_to_codepoint
                        lda petscii_lo,x
                        pha
                        lda petscii_hi,x
                        tay
                        pla
                        tax

                        ; Check for skip ($0000)
                        txa
                        bne @valid
                        tya
                        bne @valid

                        ; Skip character
                        sec
                        rts

@valid:                 clc
                        rts
.endproc

UL_RODATA

; PETSCII-to-Unicode lookup tables (unshifted mode)
; Indexed by PETSCII byte value, returns 16-bit Unicode codepoint (lo/hi)
; $0000 = skip character
;
; Ranges:
;   $00-$1F: control codes (skip, except $0D = CR)
;   $20-$3F: ASCII punctuation/digits (identity)
;   $40-$5A: @ and A-Z (identity)
;   $5B: [, $5C: GBP (U+00A3), $5D: ], $5E: up arrow (U+2191), $5F: left arrow (U+2190)
;   $60-$7E: graphic chars Set B (block elements, arcs, symbols)
;   $7F: skip (DEL)
;   $80-$9F: control codes (skip)
;   $A0-$BF: graphic chars (same as $60-$7F, always available in both modes)
;   $C0-$DA: graphic chars Set A (lines, card suits, symbols)
;   $DB-$DF: graphic chars Set A continued
;   $E0-$FE: duplicate of $A0-$BE
;   $FF: duplicate of $BF

petscii_lo:
    ; $00-$0F: control codes
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0D,$00,$00
    ; $10-$1F: control codes
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $20-$2F: ASCII identity
    .byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F
    ; $30-$3F: ASCII identity
    .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F
    ; $40-$4F: @ and A-N
    .byte $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
    ; $50-$5F: O-Z, [, GBP, ], up arrow, left arrow
    .byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$A3,$5D,$91,$90
    ; $60-$6F: graphics Set B
    .byte $A0,$8C,$84,$94,$81,$8E,$92,$95,$97,$69,$6A,$6E,$70,$6F,$6E,$6F
    ; $70-$7F: graphics Set B
    .byte $70,$CF,$72,$73,$74,$6D,$76,$77,$78,$9D,$7A,$3C,$7C,$02,$C0,$00
    ; $80-$8F: control codes
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $90-$9F: control codes
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $A0-$AF: same as $60-$6F
    .byte $A0,$8C,$84,$94,$81,$8E,$92,$95,$97,$69,$6A,$6E,$70,$6F,$6E,$6F
    ; $B0-$BF: same as $70-$7E, plus $BF graphic
    .byte $70,$CF,$72,$73,$74,$6D,$76,$77,$78,$9D,$7A,$3C,$7C,$02,$C0,$BF
    ; $C0-$CF: graphics Set A
    .byte $00,$60,$02,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF
    ; $D0-$DF: graphics Set A
    .byte $D0,$CF,$D2,$65,$D4,$D5,$D6,$D7,$63,$D9,$66,$DB,$DC,$DD,$DE,$DF
    ; $E0-$EF: same as $A0-$AF
    .byte $A0,$8C,$84,$94,$81,$8E,$92,$95,$97,$69,$6A,$6E,$70,$6F,$6E,$6F
    ; $F0-$FF: same as $B0-$BF
    .byte $70,$CF,$72,$73,$74,$6D,$76,$77,$78,$9D,$7A,$3C,$7C,$02,$C0,$BF

petscii_hi:
    ; $00-$0F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $10-$1F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $20-$2F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $30-$3F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $40-$4F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $50-$5F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$21,$21
    ; $60-$6F
    .byte $00,$25,$25,$25,$25,$25,$25,$25,$25,$E0,$E0,$25,$25,$25,$E0,$E0
    ; $70-$7F
    .byte $E0,$25,$E0,$E0,$E0,$25,$E0,$E0,$E0,$25,$E0,$25,$E0,$25,$03,$00
    ; $80-$8F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $90-$9F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $A0-$AF
    .byte $00,$25,$25,$25,$25,$25,$25,$25,$25,$E0,$E0,$25,$25,$25,$E0,$E0
    ; $B0-$BF
    .byte $E0,$25,$E0,$E0,$E0,$25,$E0,$E0,$E0,$25,$E0,$25,$E0,$25,$03,$E0
    ; $C0-$CF
    .byte $25,$26,$25,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0
    ; $D0-$DF
    .byte $E0,$25,$E0,$26,$E0,$E0,$E0,$E0,$26,$E0,$26,$E0,$E0,$E0,$E0,$E0
    ; $E0-$EF
    .byte $00,$25,$25,$25,$25,$25,$25,$25,$25,$E0,$E0,$25,$25,$25,$E0,$E0
    ; $F0-$FF
    .byte $E0,$25,$E0,$E0,$E0,$25,$E0,$E0,$E0,$25,$E0,$25,$E0,$25,$03,$E0
