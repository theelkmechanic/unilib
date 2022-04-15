; w_putcolor - Set window current foreground/background colors

.include "unilib_impl.inc"

.code

; ulwin_putcolor - Set window foreground/background colors
;   In: A               - Window handle
;       X               - Foreground color
;       Y               - Background color
.proc ulwin_putcolor
@handle = gREG::r12
@fg = gREG::r11L
@bg = gREG::r11H
                        ; Treat 0 as black (1), clip fg to $f
                        sta @handle
                        lda BANKSEL::RAM
                        pha
                        txa
                        bne :+
                        inc
:                       and #$0f
                        sta @fg
                        tya
                        bne :+
                        inc
:                       sta @bg

                        ; Get the window pointer into scratch
                        lda @handle
                        jsr ULW_getwinptr
                        cmp #0
                        beq @exit
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Normal color is bg high | fg low, treat 0 as black (1)
                        lda @bg
                        asl
                        asl
                        asl
                        asl
                        ora @fg
                        ldy #ULW_WINDOW::color
                        sta (ULW_scratch_fptr),y

                        ; Emphasis color is black on fg, unless fg is black, then white on black
                        lda @fg
                        cmp #1
                        beq :+
                        ora #(ULCOLOR::BLACK) << 4
                        bra :++
:                       asl
                        asl
                        asl
                        asl
                        ora #(ULCOLOR::BLACK)
:                       iny
                        sta (ULW_scratch_fptr),y

                        ; Exit
@exit:                  pla
                        sta BANKSEL::RAM
                        lda @handle
                        rts
.endproc
