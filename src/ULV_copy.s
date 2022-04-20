.include "unilib_impl.inc"

.code

; ULV_copyrect - copy rectangle contents to new location
;   In: r0              - Top/left of source (L=column, H=line)
;       r1              - Top/left of destination (L=column, H=line)
;       r2              - Size of rectangle (L=columns, H=lines)
.proc ULV_copyrect
@srclin = gREG::r0H
@dstlin = gREG::r1H
@numlin = gREG::r2H
@srccol = gREG::r0L
@dstcol = gREG::r1L
@numcol = gREG::r2L
@linestep = UL_temp_h
                        ; Save A/X/Y
                        pha
                        phx
                        phy

                        ; Moving up or down?
                        lda @srclin
                        cmp @dstlin
                        bcc @move_down

                        ; Moving up or just left/right, so start at top line, and line step is positive
                        ora ULV_backbuf_offset
                        sta ULV_bltsrc+1
                        lda @dstlin
                        ora ULV_backbuf_offset
                        sta ULV_bltdst+1
                        lda #1
                        bra @check_lr

                        ; Moving down, so start at bottom line, and line step is negative
@move_down:             clc
                        adc @numlin
                        dec
                        ora ULV_backbuf_offset
                        sta ULV_bltsrc+1
                        lda @dstlin
                        clc
                        adc @numlin
                        dec
                        ora ULV_backbuf_offset
                        sta ULV_bltdst+1
                        lda #$ff
@check_lr:              sta @linestep

                        ; Now figure out moving left/right
                        lda @srccol
                        cmp @dstcol
                        bcc @move_right

                        ; Moving left or just up/down, so start at left column, and column step is positive
                        ; (NOTE: for columns we multiply by two)
                        asl
                        sta ULV_bltsrc
                        lda @dstcol
                        asl
                        sta ULV_bltdst
                        lda #VERA::INC1
                        bra @do_move

                        ; Moving right, so start at right column, and column step is negative
@move_right:            clc
                        adc @numcol
                        asl
                        dec
                        sta ULV_bltsrc
                        lda @dstcol
                        clc
                        adc @numcol
                        asl
                        dec
                        sta ULV_bltdst
                        lda #VERA::DEC1
@do_move:               sta ULV_bltsrc+2
                        sta ULV_bltdst+2

                        ; Blit length is num columns * 2, blit loops is num lines
                        lda @numcol
                        asl
                        sta ULV_bltlen
                        stz ULV_bltlen+1
                        ldy @numlin

                        ; Blit the current line to both layers
@blit_loop:             jsr ULV_blt
                        lda ULV_bltsrc+1
                        ora #$40
                        sta ULV_bltsrc+1
                        lda ULV_bltdst+1
                        ora #$40
                        sta ULV_bltdst+1
                        lda VERA::ADDR+1
                        jsr ULV_blt

                        ; Step to next line
                        lda ULV_bltsrc+1
                        and #$bf
                        clc
                        adc @linestep
                        sta ULV_bltsrc+1
                        lda ULV_bltdst+1
                        and #$bf
                        clc
                        adc @linestep
                        sta ULV_bltdst+1
                        dey
                        bne @blit_loop

                        ; Mark the destination lines dirty
                        lda @dstlin
                        tax
                        adc @numlin
                        dec
                        tay
                        jsr ULV_setdirtylines

                        ; Restore A/X/Y and exit
                        ply
                        plx
                        pla
                        rts
.endproc
