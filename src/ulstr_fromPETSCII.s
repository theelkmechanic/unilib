.include "unilib_impl.inc"

UL_CODE

; ulstr_fromPETSCII - Create a string from NUL-terminated PETSCII data
;   In: A               - Flags: bit 0 clear (0) = shifted mode, bit 0 set (1) = unshifted mode
;       YX              - Pointer to NUL-terminated PETSCII character data
;  Out: YX              - String handle (MSGBLOCK pool index)
;       carry           - Set on error
.proc ulstr_fromPETSCII
                        ; Save flags
                        sta ULSFP_flags

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save source pointer
                        stx UL_varptr
                        sty UL_varptr+1

                        ; If source is in banked RAM ($A0-$BF), copy to SCRATCH ($0600)
                        cpy #$A0
                        bcc @setup
                        cpy #$C0
                        bcs @setup

                        ldy #0
@copy:                  lda (UL_varptr),y
                        sta UL_SCRATCH_BASE,y
                        beq @copy_done
                        iny
                        bne @copy
@copy_done:             lda #<UL_SCRATCH_BASE
                        sta UL_varptr
                        lda #>UL_SCRATCH_BASE
                        sta UL_varptr+1

@setup:                 stz ULSFP_outidx

                        ; Main conversion loop
@loop:                  lda (UL_varptr)
                        bne :+
                        jmp @done               ; NUL terminator
:
                        ; Check output overflow (need at most 3 bytes per char)
                        ldy ULSFP_outidx
                        cpy #250
                        bcc :+
                        jmp @done
:

                        ; Save source byte in X for table lookup
                        tax

                        ; Check shifted mode overrides
                        lda ULSFP_flags
                        and #$01
                        bne @table_lookup       ; unshifted → always use table

                        ; Shifted mode: check for letter override ranges
                        txa                     ; A = source byte

                        ; $41-$5A → lowercase a-z (byte + $20)
                        cmp #$41
                        bcc @table_lookup
                        cmp #$5B
                        bcc @shifted_lower

                        ; $61-$7A → uppercase A-Z (byte - $20)
                        cmp #$61
                        bcc @table_lookup
                        cmp #$7B
                        bcc @shifted_upper1

                        ; $C1-$DA → uppercase A-Z (byte - $80)
                        cmp #$C1
                        bcc @table_lookup
                        cmp #$DB
                        bcc @shifted_upper2
                        bra @table_lookup

@shifted_lower:         ; $41-$5A → a-z: codepoint = byte + $20 (1-byte UTF-8)
                        clc
                        adc #$20
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFP_outidx
                        jmp @next

@shifted_upper1:        ; $61-$7A → A-Z: codepoint = byte - $20 (1-byte UTF-8)
                        sec
                        sbc #$20
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFP_outidx
                        jmp @next

@shifted_upper2:        ; $C1-$DA → A-Z: codepoint = byte - $80 (1-byte UTF-8)
                        sec
                        sbc #$80
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFP_outidx
                        jmp @next

@table_lookup:          ; Look up Unicode codepoint from table (X = source byte)
                        lda petscii_lo,x
                        sta ULSFP_cp_lo
                        lda petscii_hi,x
                        sta ULSFP_cp_hi

                        ; Check for skip ($0000)
                        ora ULSFP_cp_lo
                        bne :+
                        jmp @next               ; skip this character
:

                        ; Encode codepoint as UTF-8
                        lda ULSFP_cp_hi
                        bne @multi_byte

                        ; hi = 0: codepoint $0001-$00FF
                        lda ULSFP_cp_lo
                        bmi @two_byte_00xx

                        ; 1-byte UTF-8 ($01-$7F)
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFP_outidx
                        jmp @next

@two_byte_00xx:         ; Codepoint $0080-$00FF → 2-byte UTF-8
                        ; lead = $C0 | (lo >> 6), cont = $80 | (lo & $3F)
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$C0
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        pla
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFP_outidx
                        jmp @next

@multi_byte:            ; hi byte nonzero
                        cmp #$08
                        bcs @three_byte

                        ; 2-byte UTF-8 ($0100-$07FF)
                        ; lead = $C0 | (cp >> 6)
                        ; cp >> 6 = (hi << 2) | (lo >> 6)
                        asl
                        asl
                        sta ULSFP_temp
                        lda ULSFP_cp_lo
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULSFP_temp
                        ora #$C0
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        ; cont = $80 | (lo & $3F)
                        pla
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFP_outidx
                        jmp @next

@three_byte:            ; 3-byte UTF-8 ($0800-$FFFF)
                        ; lead = $E0 | (hi >> 4)
                        lda ULSFP_cp_hi
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$E0
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny

                        ; cont1 = $80 | ((hi & $0F) << 2) | (lo >> 6)
                        lda ULSFP_cp_hi
                        and #$0F
                        asl
                        asl
                        sta ULSFP_temp
                        lda ULSFP_cp_lo
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULSFP_temp
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny

                        ; cont2 = $80 | (lo & $3F)
                        lda ULSFP_cp_lo
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFP_outidx
                        jmp @next

@next:                  ; Advance source pointer
                        inc UL_varptr
                        bne :+
                        inc UL_varptr+1
:                       jmp @loop

@done:                  ; NUL-terminate SCRATCH2
                        ldy ULSFP_outidx
                        lda #0
                        sta UL_SCRATCH2_BASE,y

                        ; Restore caller's bank and tail-call fromUtf8
                        pla
                        sta BANKSEL::RAM
                        ldx #<UL_SCRATCH2_BASE
                        ldy #>UL_SCRATCH2_BASE
                        jmp ulstr_fromUtf8

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
;   $5B: [, $5C: £ (U+00A3), $5D: ], $5E: ↑ (U+2191), $5F: ← (U+2190)
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
    ; $50-$5F: O-Z, [, £, ], ↑, ←
    .byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$A3,$5D,$91,$90
    ; $60-$6F: graphics Set B (screen codes $60-$6F)
    ;   $60=NBSP, $61=▌, $62=▄, $63=▔, $64=▁, $65=▎, $66=▒, $67=▕
    ;   $68=▗, $69=PUA, $6A=PUA, $6B=╮, $6C=╰, $6D=╯, $6E=PUA, $6F=PUA
    .byte $A0,$8C,$84,$94,$81,$8E,$92,$95,$97,$69,$6A,$6E,$70,$6F,$6E,$6F
    ; $70-$7F: graphics Set B (screen codes $70-$7F)
    ;   $70=PUA, $71=●, $72=PUA, $73=PUA, $74=PUA, $75=╭, $76=PUA, $77=PUA
    ;   $78=PUA, $79=▝, $7A=PUA, $7B=┼, $7C=PUA, $7D=│, $7E=π, $7F=skip
    .byte $70,$CF,$72,$73,$74,$6D,$76,$77,$78,$9D,$7A,$3C,$7C,$02,$C0,$00
    ; $80-$8F: control codes
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $90-$9F: control codes
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $A0-$AF: same as $60-$6F
    .byte $A0,$8C,$84,$94,$81,$8E,$92,$95,$97,$69,$6A,$6E,$70,$6F,$6E,$6F
    ; $B0-$BF: same as $70-$7E, plus $BF graphic
    .byte $70,$CF,$72,$73,$74,$6D,$76,$77,$78,$9D,$7A,$3C,$7C,$02,$C0,$BF
    ; $C0-$CF: graphics Set A (screen codes $40-$4F)
    ;   $C0=─, $C1=♠, $C2=│, $C3-$CF=PUA
    .byte $00,$60,$02,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF
    ; $D0-$DF: graphics Set A (screen codes $50-$5F)
    ;   $D0=PUA, $D1=●, $D2=PUA, $D3=♥, $D4-$D7=PUA, $D8=♣, $D9=PUA, $DA=♦, $DB-$DF=PUA
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
    ; $50-$5F: $5C=£(hi=$00), $5E=↑(hi=$21), $5F=←(hi=$21)
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$21,$21
    ; $60-$6F: $60=NBSP(hi=$00), $61-$68=block elements(hi=$25), $69-$6A=PUA(hi=$E0),
    ;          $6B-$6D=arcs(hi=$25), $6E-$6F=PUA(hi=$E0)
    .byte $00,$25,$25,$25,$25,$25,$25,$25,$25,$E0,$E0,$25,$25,$25,$E0,$E0
    ; $70-$7F: $70=PUA, $71=●(hi=$25), $72-$74=PUA, $75=╭(hi=$25), $76-$78=PUA,
    ;          $79=▝(hi=$25), $7A=PUA, $7B=┼(hi=$25), $7C=PUA, $7D=│(hi=$25),
    ;          $7E=π(hi=$03), $7F=skip
    .byte $E0,$25,$E0,$E0,$E0,$25,$E0,$E0,$E0,$25,$E0,$25,$E0,$25,$03,$00
    ; $80-$8F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $90-$9F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; $A0-$AF: same as $60-$6F
    .byte $00,$25,$25,$25,$25,$25,$25,$25,$25,$E0,$E0,$25,$25,$25,$E0,$E0
    ; $B0-$BF: same as $70-$7E, plus $BF=PUA(hi=$E0)
    .byte $E0,$25,$E0,$E0,$E0,$25,$E0,$E0,$E0,$25,$E0,$25,$E0,$25,$03,$E0
    ; $C0-$CF: $C0=─(hi=$25), $C1=♠(hi=$26), $C2=│(hi=$25), $C3-$CF=PUA(hi=$E0)
    .byte $25,$26,$25,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0
    ; $D0-$DF: $D0=PUA, $D1=●(hi=$25), $D2=PUA, $D3=♥(hi=$26), $D4-$D7=PUA,
    ;          $D8=♣(hi=$26), $D9=PUA, $DA=♦(hi=$26), $DB-$DF=PUA
    .byte $E0,$25,$E0,$26,$E0,$E0,$E0,$E0,$26,$E0,$26,$E0,$E0,$E0,$E0,$E0
    ; $E0-$EF: same as $A0-$AF
    .byte $00,$25,$25,$25,$25,$25,$25,$25,$25,$E0,$E0,$25,$25,$25,$E0,$E0
    ; $F0-$FF: same as $B0-$BF
    .byte $E0,$25,$E0,$E0,$E0,$25,$E0,$E0,$E0,$25,$E0,$25,$E0,$25,$03,$E0

UL_BSS

ULSFP_flags:            .res 1
ULSFP_outidx:           .res 1
ULSFP_cp_lo:            .res 1
ULSFP_cp_hi:            .res 1
ULSFP_temp:             .res 1
