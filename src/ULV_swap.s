.include "unilib_impl.inc"

.code

; ULV_swap - Switch backbuffer to front and update new backbuffer dirty lines
.proc ULV_swap
                        ; Switch backbuffer to be current display
                        lda ULV_backbuf_offset
                        lsr
                        sta VERA::L0::MAP_BASE
                        ora #$20 ; 0x04000 >> 1
                        sta VERA::L1::MAP_BASE

                        ; Flip old display to be backbuffer offset
                        asl
                        eor #$60
                        sta ULV_backbuf_offset

                        ; Now blit any dirty lines from the new display onto the new backbuffer
                        clc
                        adc #29
                        sta ULV_bltdst+1
                        eor #$20
                        sta ULV_bltsrc+1
                        lda #VERA::INC1
                        sta ULV_bltsrc+2
                        sta ULV_bltdst+2
                        stz ULV_bltsrc
                        stz ULV_bltdst
                        stz ULV_bltlen+1
                        ldx #160
                        stx ULV_bltlen
                        ldx #29
@cleanit_loop:          bit ULV_dirtylines,x
                        bpl @next_line
                        jsr ULV_blt
                        lda ULV_bltsrc+1
                        eor #$40
                        sta ULV_bltsrc+1
                        lda ULV_bltdst+1
                        eor #$40
                        sta ULV_bltdst+1
                        jsr ULV_blt
                        stz ULV_dirtylines,x
@next_line:             dec ULV_bltsrc+1
                        dec ULV_bltdst+1
                        dex
                        bpl @cleanit_loop
                        rts
.endproc

; ULV_setdirtylines - Set dirty bits for range of lines
;   In: X               ; Start line
;       Y               ; End line
.proc ULV_setdirtylines
                        ; Set the dirty bits for the specified range of lines
                        pha
                        iny
                        sty UL_temp_l
                        lda #$80
:                       sta ULV_dirtylines,x
                        inx
                        cpx UL_temp_l
                        bcc :-
                        pla
                        rts
.endproc

.bss

ULV_backbuf_offset:     .res    1
ULV_dirtylines:         .res    30
