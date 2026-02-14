.include "unilib_impl.inc"

UL_CODE

; ulstr_find - Find first occurrence of a codepoint in a string
;   In: r0 = string BRP, r1 = start index (char), AYX = codepoint to find
;  Out: YX = char index ($FFFF if not found)
.proc ulstr_find
                        ; Save target codepoint
                        stx ULSF_target
                        sty ULSF_target+1
                        sta ULSF_target+2

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string data
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access          ; ULS_scratch_fptr = data ptr

                        ; Skip r1 characters
                        stz ULSF_char_idx
                        stz ULSF_char_idx+1
                        lda gREG::r1L
                        ora gREG::r1H
                        beq @scan

                        lda gREG::r1L           ; skip count
                        sta ULSF_skip_count
@skip_loop:             XCALL ULS_nextchar, UNILIB_BANK_B
                        bcs @not_found          ; hit end while skipping
                        inc ULSF_char_idx
                        bne :+
                        inc ULSF_char_idx+1
:                       dec ULSF_skip_count
                        bne @skip_loop

                        ; Scan for target codepoint
@scan:                  XCALL ULS_nextchar, UNILIB_BANK_B
                        bcs @not_found

                        ; Compare AYX with target (X=low, Y=mid, A=high)
                        cpx ULSF_target
                        bne @no_match
                        cpy ULSF_target+1
                        bne @no_match
                        cmp ULSF_target+2
                        bne @no_match

                        ; Found it
                        pla
                        sta BANKSEL::RAM
                        ldx ULSF_char_idx
                        ldy ULSF_char_idx+1
                        rts

@no_match:              inc ULSF_char_idx
                        bne @scan
                        inc ULSF_char_idx+1
                        bra @scan

@not_found:             pla
                        sta BANKSEL::RAM
                        ldx #$FF
                        ldy #$FF
                        rts

.endproc

UL_BSS

ULSF_target:            .res 3
ULSF_char_idx:          .res 2
ULSF_skip_count:        .res 1
