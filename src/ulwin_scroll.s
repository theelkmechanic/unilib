.include "unilib_impl.inc"

.code

; ulwin_scroll - Scroll window contents by a specified amount
;   In: A               - Window handle
;       X               - Number of columns to scroll (signed)
;       Y               - Number of lines to scroll (signed)
.proc ulwin_scroll
                        ; Save A/X/Y/bank
                        sta ULW_WINDOW_COPY::handle
                        lda BANKSEL::RAM
                        pha
                        stx @savedx+1
                        sty @savedy+1

                        ; Access the window structure
                        lda ULW_WINDOW_COPY::handle
                        jsr ULW_getwinstruct

                        ; Destination is our start line/column plus our Y/X
                        lda @savedy+1
                        clc
                        adc ULW_WINDOW_COPY::slin
                        sta ULWR_dest+1
                        lda @savedx+1
                        clc
                        adc ULW_WINDOW_COPY::scol
                        sta ULWR_dest
                        lda ULW_WINDOW_COPY::nlin
                        sta ULWR_destsize+1
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWR_destsize

                        ; Crop the destination rect to the window contents
                        jsr ULW_intersectdest

                        ; Did we scroll completely off?
                        lda ULWR_destsize
                        beq @fillall
                        dec
                        cmp ULW_WINDOW_COPY::ncol
                        bcs @fillall
                        lda ULWR_destsize+1
                        beq @fillall
                        dec
                        cmp ULW_WINDOW_COPY::nlin
                        bcs @fillall

                        ; Source rect is dest rect offset by -X/-Y, and then need to
                        ; normalize src/dest to the window contents (subtract slin/scol)
                        lda ULWR_dest
                        sec
                        sbc ULW_WINDOW_COPY::scol
                        sta ULWR_dest
                        sbc @savedx+1
                        sta ULWR_src
                        lda ULWR_dest+1
                        sec
                        sbc ULW_WINDOW_COPY::slin
                        sta ULWR_dest+1
                        sbc @savedy+1
                        sta ULWR_src+1

                        ; Scroll is copy plus fill, so do copy first
                        jsr ULW_copyrect

                        ; What do we need to fill? First check if we scrolled left/right
                        ldx @savedx+1
                        beq @checklines ; didn't scroll left/right so don't need to fill side
                        bpl @fillleft   ; if scrolling right need to fill left

                        ; Fill right columns
                        txa
                        jsr ulmath_negate_8
                        tax
                        lda ULW_WINDOW_COPY::ncol
                        clc
                        adc @savedx+1
                        .byte $2c

                        ; Fill left columns
@fillleft:              lda #0

                        ; Fill columns
                        sta ULWR_dest
                        stx ULWR_destsize
                        lda ULW_WINDOW_COPY::nlin
                        sta ULWR_destsize+1
                        stz ULWR_dest+1
                        lda ULW_WINDOW_COPY::color
                        sta ULWR_color
                        lda ULW_WINDOW_COPY::handle
                        jsr ULW_clearrect

                        ; Okay, now check if we scrolled up/down
@checklines:            ldy @savedy+1
                        beq @alldone    ; didn't scroll up/down so don't need to fill top/bottom
                        bpl @filltop    ; if scrolling down need to fill top

                        ; Fill bottom lines
                        tya
                        jsr ulmath_negate_8
                        tay
                        lda ULW_WINDOW_COPY::nlin
                        clc
                        adc @savedy+1
                        bra @filllines

                        ; Fill whole window
@fillall:               ldy ULW_WINDOW_COPY::nlin

                        ; Fill top lines
@filltop:               lda #0

                        ; Fill lines
@filllines:             sta ULWR_dest+1
                        sty ULWR_destsize+1
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWR_destsize
                        stz ULWR_dest
                        lda ULW_WINDOW_COPY::color
                        sta ULWR_color
                        lda ULW_WINDOW_COPY::handle
                        jsr ULW_clearrect

                        ; Restore A/X/Y/bank
@alldone:               pla
                        sta BANKSEL::RAM
                        lda ULW_WINDOW_COPY::handle
@savedx:                ldx #$00
@savedy:                ldy #$00
                        rts
.endproc
