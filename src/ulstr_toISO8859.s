.include "unilib_impl.inc"

UL_CODE

; ulstr_toISO8859 - Copy string as ISO-8859-15 bytes into a byte iterator
;   In: r0              - String handle (MSGBLOCK pool index)
;       YX              - Byte iterator handle
;  Out: carry           - Set on error
.proc ulstr_toISO8859
                        ; Save iterator handle
                        stx ULSTI_iter
                        sty ULSTI_iter+1

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string → copies data to UL_SCRATCH_BASE with NUL terminator
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Loop: read each Unicode codepoint and convert to ISO-8859-15
@loop:                  XCALL ULS_nextchar, UNILIB_BANK_B
                        bcc :+
                        jmp @done               ; end of string
:

                        ; Codepoint in AYX (A=high byte, Y=mid, X=low)
                        ; A != 0: above BMP → '?'
                        cmp #0
                        bne @unmappable

                        ; Y != 0: codepoint $0100-$FFFF
                        cpy #0
                        bne @high_codepoint

                        ; Y = 0: codepoint $0000-$00FF
                        ; Check if it's one of the 8 replaced positions
                        ; ($A4,$A6,$A8,$B4,$B8,$BC,$BD,$BE map to different chars in -15 vs -1)
                        cpx #$A4
                        beq @replaced
                        cpx #$A6
                        beq @replaced
                        cpx #$A8
                        beq @replaced
                        cpx #$B4
                        beq @replaced
                        cpx #$B8
                        beq @replaced
                        cpx #$BC
                        beq @replaced
                        cpx #$BD
                        beq @replaced
                        cpx #$BE
                        beq @replaced

                        ; Direct mapping: ISO byte = codepoint low byte
                        txa
                        bra @store_byte

@replaced:              ; These ISO-8859-1 codepoints don't exist in ISO-8859-15 → '?'
                        lda #'?'
                        bra @store_byte

@high_codepoint:        ; Y >= 1: check for ISO-8859-15 special mappings
                        ; U+20AC (€) → $A4
                        cpy #$20
                        bne @check_01xx
                        cpx #$AC
                        bne @unmappable
                        lda #$A4
                        bra @store_byte

@check_01xx:            ; U+01xx range: check specific chars
                        cpy #$01
                        bne @unmappable

                        ; U+0160 (Š) → $A6
                        cpx #$60
                        beq @got_a6
                        ; U+0161 (š) → $A8
                        cpx #$61
                        beq @got_a8
                        ; U+017D (Ž) → $B4
                        cpx #$7D
                        beq @got_b4
                        ; U+017E (ž) → $B8
                        cpx #$7E
                        beq @got_b8
                        ; U+0152 (Œ) → $BC
                        cpx #$52
                        beq @got_bc
                        ; U+0153 (œ) → $BD
                        cpx #$53
                        beq @got_bd
                        ; U+0178 (Ÿ) → $BE
                        cpx #$78
                        beq @got_be
                        bra @unmappable

@got_a6:                lda #$A6
                        bra @store_byte
@got_a8:                lda #$A8
                        bra @store_byte
@got_b4:                lda #$B4
                        bra @store_byte
@got_b8:                lda #$B8
                        bra @store_byte
@got_bc:                lda #$BC
                        bra @store_byte
@got_bd:                lda #$BD
                        bra @store_byte
@got_be:                lda #$BE
                        bra @store_byte

@unmappable:            lda #'?'

@store_byte:            ; Store A via byte iterator and advance
                        ldx ULSTI_iter
                        ldy ULSTI_iter+1
                        jsr ulitr_store
                        bcs @error

                        ldx ULSTI_iter
                        ldy ULSTI_iter+1
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

UL_BSS

ULSTI_iter:             .res 2
