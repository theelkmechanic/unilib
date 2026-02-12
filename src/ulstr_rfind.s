.include "unilib_impl.inc"

.code

; ulstr_rfind - Find last occurrence of a codepoint in a string (searching backward from start index)
;   In: r0 = string BRP, r1 = start index (search up to this char), AYX = codepoint to find
;  Out: YX = char index ($FFFF if not found)
.proc ulstr_rfind
                        ; Save target codepoint
                        stx @target
                        sty @target+1
                        sta @target+2

                        ; Init last-found to $FFFF (not found)
                        lda #$FF
                        sta @last_found
                        sta @last_found+1

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string data
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Forward scan from char 0 through char r1, remembering last match
                        stz @char_idx
                        stz @char_idx+1

                        ; Compute limit = r1 + 1 (number of chars to scan)
                        lda gREG::r1L
                        clc
                        adc #1
                        sta @limit
                        lda gREG::r1H
                        adc #0
                        sta @limit+1

@scan:                  ; Check if we've scanned enough
                        lda @char_idx
                        cmp @limit
                        bne @do_scan
                        lda @char_idx+1
                        cmp @limit+1
                        beq @done

@do_scan:               jsr ULS_nextchar
                        bcs @done

                        ; Compare AYX with target
                        cpx @target
                        bne @no_match
                        cpy @target+1
                        bne @no_match
                        cmp @target+2
                        bne @no_match

                        ; Match: remember this position
                        lda @char_idx
                        sta @last_found
                        lda @char_idx+1
                        sta @last_found+1

@no_match:              inc @char_idx
                        bne @scan
                        inc @char_idx+1
                        bra @scan

@done:                  pla
                        sta BANKSEL::RAM
                        ldx @last_found
                        ldy @last_found+1
                        rts

.bss
@target:                .res 3
@char_idx:              .res 2
@last_found:            .res 2
@limit:                 .res 2
.endproc
