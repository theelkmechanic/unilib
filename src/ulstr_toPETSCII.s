.include "unilib_impl.inc"

UL_CODE

; ulstr_toPETSCII - Copy string as PETSCII bytes into a byte iterator
;   In: r0              - String handle (MSGBLOCK pool index)
;       YX              - Byte iterator handle
;       A               - Flags: bit 0 clear (0) = shifted, bit 0 set (1) = unshifted
;  Out: carry           - Set on error
.proc ulstr_toPETSCII
                        ; Save flags
                        sta ULSTP_flags

                        ; Save iterator handle
                        stx ULSTP_iter
                        sty ULSTP_iter+1

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string → copies data to UL_SCRATCH_BASE
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Loop: read each Unicode codepoint and convert to PETSCII
@loop:                  XCALL ULS_nextchar, UNILIB_BANK_B
                        bcc :+
                        jmp @done               ; end of string
:
                        ; Codepoint in AYX (A=high, Y=mid, X=low)
                        ; A != 0: above BMP → '?'
                        cmp #0
                        beq :+
                        jmp @unmappable
:
                        ; Y != 0: codepoint $0100+
                        cpy #0
                        bne @high_codepoint

                        ; Y = 0, X = codepoint $00-$FF
                        ; Check for CR
                        cpx #$0D
                        beq @identity

                        ; Below space? → unmappable
                        cpx #$20
                        bcc @unmappable_near

                        ; $20-$40: ASCII punctuation → identity
                        cpx #$41
                        bcc @identity

                        ; $41-$5A: uppercase A-Z
                        cpx #$5B
                        bcc @upper_letter

                        ; $5B: [ → identity
                        cpx #$5B
                        beq @identity

                        ; $5C: \ → unmappable (PETSCII $5C is £)
                        cpx #$5D
                        bcc @unmappable_near

                        ; $5D: ] → identity
                        cpx #$5D
                        beq @identity

                        ; $5E-$60: ^, _, ` → unmappable
                        cpx #$61
                        bcc @unmappable_near

                        ; $61-$7A: lowercase a-z
                        cpx #$7B
                        bcc @lower_letter

                        ; $7B-$7F: {, |, }, ~, DEL → unmappable
                        cpx #$80
                        bcc @unmappable_near

                        ; $80-$9F: C1 control codes → unmappable
                        cpx #$A0
                        bcc @unmappable

                        ; $A0: NBSP → PETSCII $A0
                        cpx #$A0
                        beq @nbsp

                        ; $A3: £ → PETSCII $5C
                        cpx #$A3
                        beq @pound

                        ; Other $80-$FF → unmappable
                        bra @unmappable

@unmappable_near:       jmp @unmappable

@upper_letter:          ; A-Z ($41-$5A)
                        lda ULSTP_flags
                        and #$01
                        bne @upper_unshifted

                        ; Shifted: A-Z → PETSCII $C1-$DA (byte + $80)
                        txa
                        clc
                        adc #$80
                        bra @store_byte

@upper_unshifted:       ; Unshifted: A-Z → PETSCII $41-$5A (identity)
                        txa
                        bra @store_byte

@lower_letter:          ; a-z ($61-$7A) → PETSCII $41-$5A (both modes)
                        txa
                        sec
                        sbc #$20
                        bra @store_byte

@identity:              txa
                        bra @store_byte

@nbsp:                  lda #$A0
                        bra @store_byte

@pound:                 lda #$5C
                        bra @store_byte

@high_codepoint:        ; Y >= 1: check specific Unicode codepoints
                        ; Check PUA range: Y=$E0 → PETSCII = X
                        cpy #$E0
                        beq @pua

                        ; Search the reverse lookup table
                        sty ULSTP_cp_hi
                        stx ULSTP_cp_lo
                        ldx #PETSCII_REVTBL_SIZE-1
@rev_loop:              lda ULSTP_cp_hi
                        cmp revtbl_hi,x
                        bne @rev_next
                        lda ULSTP_cp_lo
                        cmp revtbl_lo,x
                        beq @rev_found
@rev_next:              dex
                        bpl @rev_loop

                        ; Not found
                        bra @unmappable

@rev_found:             ; Found: load PETSCII byte
                        lda revtbl_pet,x

                        ; If shifted mode and result is $C0-$DA (Set A graphic),
                        ; those positions show as letters in shifted mode → unmappable
                        pha
                        lda ULSTP_flags
                        and #$01
                        bne @rev_ok             ; unshifted → all graphics available

                        ; Shifted mode: check if result is in $C0-$DA
                        pla
                        pha
                        cmp #$C0
                        bcc @rev_ok
                        cmp #$DB
                        bcs @rev_ok

                        ; $C0-$DA in shifted mode → unmappable
                        pla
                        bra @unmappable

@rev_ok:                pla
                        bra @store_byte

@pua:                   ; PUA: PETSCII = X (the low byte IS the PETSCII code)
                        ; Check if shifted mode restricts this
                        lda ULSTP_flags
                        and #$01
                        bne @pua_ok             ; unshifted → OK

                        ; Shifted mode: $C0-$DA are letters, not graphics
                        cpx #$C0
                        bcc @pua_ok
                        cpx #$DB
                        bcs @pua_ok
                        bra @unmappable

@pua_ok:                txa
                        bra @store_byte

@unmappable:            lda #'?'

@store_byte:            ; Store A via byte iterator and advance
                        ldx ULSTP_iter
                        ldy ULSTP_iter+1
                        jsr ulitr_store
                        bcs @error

                        ldx ULSTP_iter
                        ldy ULSTP_iter+1
                        jsr ulitr_inc

                        jmp @loop

@done:                  pla
                        sta BANKSEL::RAM
                        clc
                        rts

@error:                 pla
                        sta BANKSEL::RAM
                        sec
                        rts

.endproc

UL_RODATA

; Reverse lookup table: Unicode codepoint → PETSCII byte
; For graphic characters with standard BMP Unicode mappings
; PUA characters (U+E0xx) are handled in code (PETSCII = lo byte)

PETSCII_REVTBL_SIZE = 25

; Unicode high bytes (sorted by codepoint)
revtbl_hi:
    .byte $00           ; U+00A0 → NBSP
    .byte $03           ; U+03C0 → π
    .byte $21,$21       ; U+2190 ←, U+2191 ↑
    .byte $25           ; U+2500 ─
    .byte $25           ; U+2502 │
    .byte $25           ; U+253C ┼
    .byte $25           ; U+256D ╭
    .byte $25           ; U+256E ╮
    .byte $25           ; U+256F ╯
    .byte $25           ; U+2570 ╰
    .byte $25           ; U+2581 ▁
    .byte $25           ; U+2584 ▄
    .byte $25           ; U+258C ▌
    .byte $25           ; U+258E ▎
    .byte $25           ; U+2592 ▒
    .byte $25           ; U+2594 ▔
    .byte $25           ; U+2595 ▕
    .byte $25           ; U+2597 ▗
    .byte $25           ; U+259D ▝
    .byte $25           ; U+25CF ●
    .byte $26           ; U+2660 ♠
    .byte $26           ; U+2663 ♣
    .byte $26           ; U+2665 ♥
    .byte $26           ; U+2666 ♦

; Unicode low bytes
revtbl_lo:
    .byte $A0           ; U+00A0
    .byte $C0           ; U+03C0
    .byte $90,$91       ; U+2190, U+2191
    .byte $00           ; U+2500
    .byte $02           ; U+2502
    .byte $3C           ; U+253C
    .byte $6D           ; U+256D
    .byte $6E           ; U+256E
    .byte $6F           ; U+256F
    .byte $70           ; U+2570
    .byte $81           ; U+2581
    .byte $84           ; U+2584
    .byte $8C           ; U+258C
    .byte $8E           ; U+258E
    .byte $92           ; U+2592
    .byte $94           ; U+2594
    .byte $95           ; U+2595
    .byte $97           ; U+2597
    .byte $9D           ; U+259D
    .byte $CF           ; U+25CF
    .byte $60           ; U+2660
    .byte $63           ; U+2663
    .byte $65           ; U+2665
    .byte $66           ; U+2666

; PETSCII bytes (use $A0-$BF range where possible for both-modes compatibility)
revtbl_pet:
    .byte $A0           ; NBSP
    .byte $BE           ; π (at $7E/$BE, always available)
    .byte $5F,$5E       ; ←, ↑
    .byte $C0           ; ─ (Set A, unshifted only)
    .byte $BD           ; │ (at $7D/$BD, always available)
    .byte $BB           ; ┼ (at $7B/$BB, always available)
    .byte $B5           ; ╭ (at $75/$B5, always available)
    .byte $AB           ; ╮ (at $6B/$AB, always available)
    .byte $AD           ; ╯ (at $6D/$AD, always available)
    .byte $AC           ; ╰ (at $6C/$AC, always available)
    .byte $A4           ; ▁ (at $64/$A4, always available)
    .byte $A2           ; ▄ (at $62/$A2, always available)
    .byte $A1           ; ▌ (at $61/$A1, always available)
    .byte $A5           ; ▎ (at $65/$A5, always available)
    .byte $A6           ; ▒ (at $66/$A6, always available)
    .byte $A3           ; ▔ (at $63/$A3, always available)
    .byte $A7           ; ▕ (at $67/$A7, always available)
    .byte $A8           ; ▗ (at $68/$A8, always available)
    .byte $B9           ; ▝ (at $79/$B9, always available)
    .byte $B1           ; ● (at $71/$B1, always available)
    .byte $C1           ; ♠ (Set A, unshifted only)
    .byte $D8           ; ♣ (Set A, unshifted only)
    .byte $D3           ; ♥ (Set A, unshifted only)
    .byte $DA           ; ♦ (Set A, unshifted only)

UL_BSS

ULSTP_iter:             .res 2
ULSTP_flags:            .res 1
ULSTP_cp_hi:            .res 1
ULSTP_cp_lo:            .res 1
