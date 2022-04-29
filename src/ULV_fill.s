.include "unilib_impl.inc"

.code

; ULV_plotchar - Draw a Unicode character at a specified screen location
;   In: AYX             - Unicode character (X=lo, Y=hi, A=plane)
;       ULVR_destpos    - Screen location (column=low, row=high)
;       ULVR_color      - Colors (fg=low nibble, bg=high nibble) (1-15, undefined behavior if out of range)
;  Out: carry           - Set if character plotted
.proc ULV_plotchar
                        ; Plotting a character is basically a 1x1 fill, so just do that
                        stz ULVR_size
                        stz ULVR_size+1
                        inc ULVR_size
                        inc ULVR_size+1
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULV_fillrect - fill rectangle with Unicode character and color
;   In: AYX             - Unicode character (X=lo, Y=hi, A=plane)
;       ULVR_destpos    - Top/left of rectangle (column=low, line=high)
;       ULVR_size       - Size of rectangle (columns=low, lines=high)
;       ULVR_color      - Colors (fg=low nibble, bg=high nibble) (1-15, undefined behavior if out of range)
; Out:  carry           - Set if character found
.proc ULV_fillrect
                        ; Save A/X/Y
                        pha
                        phx
                        phy

                        ; Look up character info
                        jsr ULFT_findcharinfo
                        bcs ULV_dofill
.endproc

.proc ULV_exitfill
                        ply
                        plx
                        pla
                        rts
.endproc

; ULV_clearrect - clear rectangle with blanks and color
;   In: ULVR_destpos    - Top/left of rectangle (column=low, line=high)
;       ULVR_size       - Size of rectangle (columns=low, lines=high)
;       ULVR_color      - Colors (fg=low nibble, bg=high nibble) (1-15, undefined behavior if out of range)
.proc ULV_clearrect
                        ; Save A/X/Y
                        pha
                        phx
                        phy

                        ; Base glyph is space, overlay glyph/flags are 0
                        stz ULFT_charflags
                        stz ULFT_extraglyph
                        lda #' '
                        sta ULFT_baseglyph
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULV_dofill - Calculate colors and do fill loop
.proc ULV_dofill
                        ; Convert the colors
                        lda ULVR_color
                        jsr ULV_calcglyphcolors

                        ; Calculate base layer starting address
                        lda VERA::CTRL
                        and #$fe
                        sta VERA::CTRL
                        lda ULVR_destpos
                        asl
                        sta ULV_bltdst
                        lda ULVR_destpos+1
                        ora ULV_backbuf_offset
                        sta VERA::ADDR+1
                        lda #VERA::INC1
                        sta VERA::ADDR+2

                        ; Num lines for outer loop, num columns for inner loop
                        ldy ULVR_size+1
                        phy
@outer_loop:
                        ; Loop numcolumns writing base glyph/color
                        ldy ULVR_size
                        lda ULV_bltdst
                        sta VERA::ADDR
                        ldx ULV_basecolor
                        lda ULFT_baseglyph
@inner_loop_base:       sta VERA::DATA0
                        stx VERA::DATA0
                        dey
                        bne @inner_loop_base

                        ; Switch to overlay page, loop numcolumns writing overlay glyph/color
                        ldy ULVR_size
                        lda VERA::ADDR+1
                        ora #$40
                        sta VERA::ADDR+1
                        lda ULV_bltdst
                        sta VERA::ADDR
                        ldx ULV_extracolor
                        lda ULFT_extraglyph
@inner_loop_overlay:    sta VERA::DATA0
                        stx VERA::DATA0
                        dey
                        bne @inner_loop_overlay

                        ; Switch back to base page, step to next line
                        lda VERA::ADDR+1
                        and #$bf
                        inc
                        sta VERA::ADDR+1
                        ply
                        dey
                        phy
                        bne @outer_loop
                        ply

                        ; Mark the lines dirty
                        lda ULVR_destpos+1
                        tax
                        clc
                        adc ULVR_size+1
                        dec
                        tay
                        jsr ULV_setdirtylines

                        ; Set success flag and exit
                        sec
                        jmp ULV_exitfill
.endproc

.bss

ULVR_srcpos:            .res    2
ULVR_destpos:           .res    2
ULVR_size:              .res    2
ULVR_color:             .res    1
