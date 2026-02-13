.include "unilib_impl.inc"

.code

; ulstr_compare - Compare two strings
;   In: r0 = first string handle (MSGBLOCK pool index), r1 = second string handle, A = flags (ignored)
;  Out: A = negative if first < second, 0 if equal, positive if first > second
.proc ulstr_compare
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string 1 via ULS_access → data at $400
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Get bytelen1
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulstr_getrawlen
                        sta @s1_bytelen

                        ; Copy $400 data to $500
                        lda @s1_bytelen
                        beq @do_s2
                        tay
:                       dey
                        lda $400,y
                        sta $500,y
                        cpy #0
                        bne :-

                        ; Access string 2 via ULS_access → data at $400
@do_s2:                 ldx gREG::r1L
                        ldy gREG::r1H
                        jsr ULS_access

                        ; Get bytelen2
                        ldx gREG::r1L
                        ldy gREG::r1H
                        jsr ulstr_getrawlen
                        sta @s2_bytelen

                        ; Copy $400 data to $600
                        lda @s2_bytelen
                        beq @compare
                        tay
:                       dey
                        lda $400,y
                        sta $600,y
                        cpy #0
                        bne :-

                        ; Compare min(bytelen1, bytelen2) data bytes
                        ; Data is at $500 and $600 (no offset — raw data)
@compare:               lda @s1_bytelen
                        cmp @s2_bytelen
                        bcc @use_s1_len
                        lda @s2_bytelen
@use_s1_len:            tax                     ; X = min len
                        beq @compare_lengths    ; both empty or one empty

                        ldy #0
@cmp_loop:              lda $500,y
                        cmp $600,y
                        bcc @less
                        bne @greater
                        iny
                        dex
                        bne @cmp_loop

                        ; All compared bytes equal, compare lengths
@compare_lengths:       lda @s1_bytelen
                        cmp @s2_bytelen
                        beq @equal
                        bcc @less

@greater:               pla
                        sta BANKSEL::RAM
                        lda #1
                        rts

@less:                  pla
                        sta BANKSEL::RAM
                        lda #$FF
                        rts

@equal:                 pla
                        sta BANKSEL::RAM
                        lda #0
                        rts

.bss
@s1_bytelen:            .res 1
@s2_bytelen:            .res 1
.endproc
