.include "unilib_impl.inc"

.code

; ulwin_box - Draw a box around an area in a window
;   In: A               - window handle
;       r0              - Top/left of box (L=column, H=line)
;       r1              - Bottom/right of box (L=column, H=line)
.proc ulwin_box
                        ; Save A/X/Y/bank
                        pha
                        phx
                        phy
                        ldy BANKSEL::RAM
                        phy

                        ; Access the window structure
                        jsr ULW_getwinstruct

                        ; Make sure our top/left/bottom/right are all within the window contents,
                        ; and that top/left are less than bottom/right
                        lda #ULERR::OK
                        sta UL_lasterr
                        lda gREG::r0L
                        bmi @invalid
                        cmp gREG::r1L
                        bcs @invalid
                        ldx gREG::r1L
                        bmi @invalid
                        cpx ULW_WINDOW_COPY::ncol
                        bcs @invalid
                        lda gREG::r0H
                        bmi @invalid
                        cmp gREG::r1H
                        bcs @invalid
                        ldy gREG::r1H
                        bmi @invalid
                        cpy ULW_WINDOW_COPY::nlin
                        bcs @invalid

                        ; If there's a border, need to bump the coords up by 1
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        inx
                        iny
                        inc

                        ; Store our parameters and call the helper
:                       stx ULW_boxright
                        sty ULW_boxbottom
                        sta ULW_boxtop
                        lda gREG::r0L
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        inc
:                       sta ULW_boxleft
                        jsr ULW_box
                        bra @done

                        ; Invalid parameters
@invalid:               lda #ULERR::INVALID_PARAMS
                        sta UL_lasterr

                        ; Restore A/X/Y/bank
@done:                  ply
                        sty BANKSEL::RAM
                        ply
                        plx
                        pla
                        rts
.endproc

; ULW_box - Draw box on scratch window
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULW_boxtop/bottom/left/right                  - Box coordinates
.proc ULW_box
                        ; Box characters are as follows from Unicode:
                        ;   - Horizontal line     = $002501
                        ;   - Vertical line       = $002503
                        ;   - Top-left corner     = $00250f
                        ;   - Top-right corner    = $002513
                        ;   - Bottom-left corner  = $002517
                        ;   - Bottom-right corner = $00251b

                        ; Fill top/bottom lines with horizontal character
                        stz ULWR_char+2
                        lda #$25
                        sta ULWR_char+1
                        lda #$01
                        sta ULWR_char
                        sta ULWR_destsize+1
                        lda ULW_boxleft
                        inc
                        sta ULWR_dest
                        lda ULW_boxright
                        sec
                        sbc ULW_boxleft
                        dec
                        sta ULWR_destsize
                        lda ULW_WINDOW_COPY::color
                        sta ULWR_color
                        lda ULW_boxtop
                        sta ULWR_dest+1
                        jsr ULW_fillrect
                        lda ULW_boxbottom
                        sta ULWR_dest+1
                        jsr ULW_fillrect

                        ; Fill left/right lines with vertical character
                        lda #$03
                        sta ULWR_char
                        lda #1
                        sta ULWR_destsize
                        lda ULW_boxbottom
                        sec
                        sbc ULW_boxtop
                        dec
                        sta ULWR_destsize+1
                        lda ULW_boxtop
                        inc
                        sta ULWR_dest+1
                        lda ULW_boxleft
                        sta ULWR_dest
                        jsr ULW_fillrect
                        lda ULW_boxright
                        sta ULWR_dest
                        jsr ULW_fillrect

                        ; Plot the corner characters

                        ; Top right
                        lda #$13
                        sta ULWR_char
                        dec ULWR_dest+1
                        jsr ULW_drawchar

                        ; Bottom right (can start using fillrect because the previous ULW_drawchar set the size to 1x1)
                        lda #$1b
                        sta ULWR_char
                        lda ULW_boxbottom
                        sta ULWR_dest+1
                        jsr ULW_fillrect

                        ; Bottom left
                        lda #$17
                        sta ULWR_char
                        lda ULW_boxleft
                        sta ULWR_dest
                        jsr ULW_fillrect

                        ; Top left
                        lda #$0f
                        sta ULWR_char
                        lda ULW_boxtop
                        sta ULWR_dest+1
                        jmp ULW_fillrect
.endproc

.bss

ULW_boxtop:             .res    1
ULW_boxbottom:          .res    1
ULW_boxleft:            .res    1
ULW_boxright:           .res    1
