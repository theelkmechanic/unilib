.include "unilib_impl.inc"

.code

; ulwin_putcolor - Set window foreground/background colors
;   In: A               - Window handle
;       X               - Foreground color
;       Y               - Background color
.proc ulwin_putcolor
@handle = gREG::r11L
                        ; Treat 0 as black (1), clip fg to $f
                        sta @handle
                        lda BANKSEL::RAM
                        pha
                        txa
                        bne :+
                        inc
:                       and #$0f
                        pha
                        tya
                        bne :+
                        inc
:                       pha

                        ; Access the window structure
                        lda @handle
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Use the internal helper
                        ply
                        plx
                        jsr ULW_putcolor

                        ; Exit
@exit:                  pla
                        sta BANKSEL::RAM
                        lda @handle
                        rts
.endproc

.proc ULW_putcolor
                        ; Normal color is bg high | fg low, treat 0 as black (1)
                        tya
                        asl
                        asl
                        asl
                        asl
                        stx UL_temp_l
                        ora UL_temp_l
                        ldy #ULW_WINDOW::color
                        sta (ULW_scratch_fptr),y

                        ; Emphasis color is black on fg, unless fg is black, then white on black
                        txa
                        cmp #1
                        beq :+
                        ora #(ULCOLOR::BLACK) << 4
                        bra :++
:                       asl
                        asl
                        asl
                        asl
                        ora #(ULCOLOR::WHITE)
:                       iny
                        sta (ULW_scratch_fptr),y
                        rts
.endproc
