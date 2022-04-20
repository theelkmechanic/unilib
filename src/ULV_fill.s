.include "unilib_impl.inc"

.code

; ULV_plotchar - Draw a UTF-16 character at a specified screen location
; In:   r0              - Screen location (column=low, row=high)
;       r1              - UTF-16 character (little-endian)
;       r2L             - Foreground color (1-15, undefined behavior if out of range)
;       r2H             - Background color (1-15, undefined behavior if out of range)
; Out:  carry           - Set if character plotted
.proc ULV_plotchar
                        ; Plotting a character is basically a 1x1 fill, so just do that
                        phx
                        phy
                        ldx gREG::r1L
                        ldy gREG::r1H
                        stz gREG::r1L
                        stz gREG::r1H
                        inc gREG::r1L
                        inc gREG::r1H
                        jsr ULV_fillrect
                        sty gREG::r1H
                        stx gREG::r1L
                        ply
                        plx
                        rts
.endproc

; ULV_fillrect - fill rectangle with Unicode character and color
;   In: r0              - Top/left of rectangle (L=column, H=line)
;       r1              - Size of rectange (L=columns, H=lines)
;       r2L             - Foreground color (1-15, undefined behavior if out of range)
;       r2H             - Background color (1-15, undefined behavior if out of range)
;       YX              - UTF-16 character (little-endian)
;  Out: carry           - Set if character found
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
;   In: r0              - Top/left of rectangle (L=column, H=line)
;       r1              - Size of rectange (L=columns, H=lines)
;       r2L             - Foreground color (1-15, undefined behavior if out of range)
;       r2H             - Background color (1-15, undefined behavior if out of range)
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

; ULV_dofill - Calculate colors and do fill loop
.proc ULV_dofill
@line = gREG::r0H
@column = gREG::r0L
@numlines = gREG::r1H
@numcolumns = gREG::r1L
@fg = gREG::r2L
@bg = gREG::r2H
                        ; Convert the colors
                        ldx @fg
                        ldy @bg
                        jsr ULV_calcglyphcolors

                        ; Calculate base layer starting address
                        lda VERA::CTRL
                        and #$fe
                        sta VERA::CTRL
                        lda @column
                        asl
                        sta ULV_bltdst
                        lda @line
                        ora ULV_backbuf_offset
                        sta VERA::ADDR+1
                        lda #VERA::INC1
                        sta VERA::ADDR+2

                        ; Num lines for outer loop, num columns for inner loop
                        ldy @numlines
                        phy
@outer_loop:
                        ; Loop numcolumns writing base glyph/color
                        ldy @numcolumns
                        lda ULV_bltdst
                        sta VERA::ADDR
                        ldx ULV_basecolor
                        lda ULFT_baseglyph
@inner_loop_base:       sta VERA::DATA0
                        stx VERA::DATA0
                        dey
                        bne @inner_loop_base

                        ; Switch to overlay page, loop numcolumns writing overlay glyph/color
                        ldy @numcolumns
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
                        lda @line
                        tax
                        clc
                        adc @numlines
                        dec
                        tay
                        jsr ULV_setdirtylines

                        ; Set success flag and exit
                        sec
                        jmp ULV_exitfill
.endproc
