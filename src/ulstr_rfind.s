.include "unilib_impl.inc"

.code

; ulstr_rfind - Find last occurrence of a codepoint in a string (searching backward from start index)
;   In: r0 = string BRP, r1 = start index (search up to this char), AYX = codepoint to find
;  Out: YX = char index ($FFFF if not found)
.proc ulstr_rfind
                        ; Save target codepoint
                        stx ULSRF_target
                        sty ULSRF_target+1
                        sta ULSRF_target+2

                        ; Init last-found to $FFFF (not found)
                        lda #$FF
                        sta ULSRF_last_found
                        sta ULSRF_last_found+1

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string data
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Forward scan from char 0 through char r1, remembering last match
                        stz ULSRF_char_idx
                        stz ULSRF_char_idx+1

                        ; Compute limit = r1 + 1 (number of chars to scan)
                        lda gREG::r1L
                        clc
                        adc #1
                        sta ULSRF_limit
                        lda gREG::r1H
                        adc #0
                        sta ULSRF_limit+1

@scan:                  ; Check if we've scanned enough
                        lda ULSRF_char_idx
                        cmp ULSRF_limit
                        bne @do_scan
                        lda ULSRF_char_idx+1
                        cmp ULSRF_limit+1
                        beq @done

@do_scan:               jsr ULS_nextchar
                        bcs @done

                        ; Compare AYX with target
                        cpx ULSRF_target
                        bne @no_match
                        cpy ULSRF_target+1
                        bne @no_match
                        cmp ULSRF_target+2
                        bne @no_match

                        ; Match: remember this position
                        lda ULSRF_char_idx
                        sta ULSRF_last_found
                        lda ULSRF_char_idx+1
                        sta ULSRF_last_found+1

@no_match:              inc ULSRF_char_idx
                        bne @scan
                        inc ULSRF_char_idx+1
                        bra @scan

@done:                  pla
                        sta BANKSEL::RAM
                        ldx ULSRF_last_found
                        ldy ULSRF_last_found+1
                        rts

.endproc

.bss

ULSRF_target:           .res 3
ULSRF_char_idx:         .res 2
ULSRF_last_found:       .res 2
ULSRF_limit:            .res 2
