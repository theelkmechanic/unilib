; ulwin_getkey - Get a keystroke translated to Unicode

.include "unilib_impl.inc"

UL_CODE

; ulwin_getkey - Get a keystroke translated to Unicode
;  Out: A               - Codepoint byte 2 (0 for BMP)
;       Y               - Codepoint byte 1 (high)
;       X               - Codepoint byte 0 (low)
.proc ulwin_getkey
                        ; Save bank
                        lda BANKSEL::RAM
                        pha

                        ; Loop until we get a key
@loop:                  jsr GETIN
                        cmp #0
                        bne @got_key

                        ; No key yet; call idle function if configured
                        lda ULW_keyidle
                        ora ULW_keyidle+1
                        beq @loop               ; no idle function, just loop
                        jsr @do_idle
                        bra @loop

                        ; Got a PETSCII key, convert to Unicode codepoint
@got_key:               tax                     ; X = PETSCII byte
                        jsr UL_petscii_to_codepoint
                        bcs @loop               ; skip chars (control codes) - keep waiting

                        ; X = cp_lo, Y = cp_hi; save results
                        stx ULWGK_cp_lo
                        sty ULWGK_cp_hi

                        ; Restore bank
                        pla
                        sta BANKSEL::RAM

                        ; Load return values
                        ldx ULWGK_cp_lo
                        ldy ULWGK_cp_hi
                        lda #0
                        rts

@do_idle:               jmp (ULW_keyidle)
.endproc

UL_BSS

ULWGK_cp_lo:            .res 1
ULWGK_cp_hi:            .res 1
