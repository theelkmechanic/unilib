.include "unilib_impl.inc"

.code

; ulstr_compare - Compare two strings
;   In: r0 = first string BRP, r1 = second string BRP, A = flags (ignored)
;  Out: A = negative if first < second, 0 if equal, positive if first > second
.proc ulstr_compare
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Copy string 1 to $500
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        ; Read bytelen from header byte 0
                        lda (ULS_scratch_fptr)
                        sta @s1_bytelen
                        ; Copy bytelen+4 bytes (header + data + NUL)
                        clc
                        adc #4
                        tay
:                       dey
                        lda (ULS_scratch_fptr),y
                        sta $500,y
                        cpy #0
                        bne :-

                        ; Copy string 2 to $600
                        ldx gREG::r1L
                        ldy gREG::r1H
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        lda (ULS_scratch_fptr)
                        sta @s2_bytelen
                        clc
                        adc #4
                        tay
:                       dey
                        lda (ULS_scratch_fptr),y
                        sta $600,y
                        cpy #0
                        bne :-

                        ; Compare min(bytelen1, bytelen2) data bytes
                        ; Data starts at offset 3 ($503 and $603)
                        lda @s1_bytelen
                        cmp @s2_bytelen
                        bcc @use_s1_len
                        lda @s2_bytelen
@use_s1_len:            tax                     ; X = min len
                        beq @compare_lengths    ; both empty or one empty

                        ldy #0
@cmp_loop:              lda $503,y
                        cmp $603,y
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
