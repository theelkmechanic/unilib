.include "unilib_impl.inc"

UL_CODE

; ulwin_putcolor - Set window foreground/background colors
;   In: A               - Window handle
;       X               - Foreground color
;       Y               - Background color
;       carry           - If set, entire window will be recolored; if clear, will only affect new output
.proc ulwin_putcolor
                        ; Treat 0 as black (1), clip fg to $f
                        ; Save carry flag (recolor) and handle to BSS
                        stz ULWPCLR_recolor
                        bcc :+
                        dec ULWPCLR_recolor     ; $FF if carry set (recolor)
:                       sta ULWPCLR_handle
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
                        lda ULWPCLR_handle
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Use the internal helper
                        ply
                        plx
                        jsr ULW_putcolor

                        ; Do we need to recolor the window?
                        bit ULWPCLR_recolor
                        bpl @exit

                        ; Get easy access to window structure
                        jsr ULW_copywinstruct

                        ; Update the window contents color
                        stz ULWR_dest
                        stz ULWR_dest+1
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWR_destsize
                        lda ULW_WINDOW_COPY::nlin
                        sta ULWR_destsize+1
                        lda ULW_WINDOW_COPY::color
                        sta ULWR_color
                        sec
                        jsr ULW_fillrect

                        ; And if there's a border, redraw it as well
                        jsr ULW_drawborder

                        ; Exit
@exit:                  pla
                        sta BANKSEL::RAM
                        lda ULWPCLR_handle
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

UL_BSS

ULWPCLR_handle:         .res    1
ULWPCLR_recolor:        .res    1
