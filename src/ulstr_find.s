.include "unilib_impl.inc"

.code

; ulstr_find - Find first occurrence of a codepoint in a string
;   In: r0 = string BRP, r1 = start index (char), AYX = codepoint to find
;  Out: YX = char index ($FFFF if not found)
.proc ulstr_find
                        ; Save target codepoint
                        stx @target
                        sty @target+1
                        sta @target+2

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string data
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access          ; ULS_scratch_fptr = data ptr

                        ; Skip r1 characters
                        stz @char_idx
                        stz @char_idx+1
                        lda gREG::r1L
                        ora gREG::r1H
                        beq @scan

                        lda gREG::r1L           ; skip count
                        sta @skip_count
@skip_loop:             jsr ULS_nextchar
                        bcs @not_found          ; hit end while skipping
                        inc @char_idx
                        bne :+
                        inc @char_idx+1
:                       dec @skip_count
                        bne @skip_loop

                        ; Scan for target codepoint
@scan:                  jsr ULS_nextchar
                        bcs @not_found

                        ; Compare AYX with target (X=low, Y=mid, A=high)
                        cpx @target
                        bne @no_match
                        cpy @target+1
                        bne @no_match
                        cmp @target+2
                        bne @no_match

                        ; Found it
                        pla
                        sta BANKSEL::RAM
                        ldx @char_idx
                        ldy @char_idx+1
                        rts

@no_match:              inc @char_idx
                        bne @scan
                        inc @char_idx+1
                        bra @scan

@not_found:             pla
                        sta BANKSEL::RAM
                        ldx #$FF
                        ldy #$FF
                        rts

.bss
@target:                .res 3
@char_idx:              .res 2
@skip_count:            .res 1
.endproc
