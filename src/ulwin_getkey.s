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

                        ; Load current window struct for cursor blink
                        lda ULW_current_handle
                        jsr ULW_getwinstruct

                        ; Initialize blink state
                        stz ULW_blink_on
                        jsr RDTIM
                        stx ULW_blink_jiffy

                        ; Loop until we get a key
@loop:                  jsr ULW_check_blink

                        jsr GETIN
                        cmp #0
                        bne @got_key

                        ; No key yet; call idle function if configured
                        lda ULW_keyidle
                        ora ULW_keyidle+1
                        beq @loop               ; no idle function, just loop
                        jsr @do_idle
                        bra @loop

                        ; Got a PETSCII key — hide cursor before processing
@got_key:               pha
                        lda ULW_blink_on
                        beq :+
                        jsr ULW_hide_cursor
:                       pla

                        tax                     ; X = PETSCII byte
                        XCALL UL_petscii_to_codepoint, UNILIB_BANK_A
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
