; ulmath_idiv - Integer division functions

.include "unilib_impl.inc"

.code

; ulmath_udiv8_8 - Divide 8-bit by 8-bit (unsigned)
;   In: X               ; Dividend
;       A               ; Divisor
;  Out: X               ; Quotient
;       A               ; Remainder
.proc ulmath_udiv8_8
                        phy
                        ldy #0
                        jsr ulmath_udiv16_8
                        ply
                        rts
.endproc

; ulmath_udiv16_8 - Divide 16-bit by 8-bit (unsigned)
;   In: YX              ; Dividend
;       A               ; Divisor
;  Out: YX              ; Quotient
;       A               ; Remainder
.proc ulmath_udiv16_8
                        sta UL_temp_div
                        sty UL_temp_h
                        stx UL_temp_l
                        ldx #16
                        lda #0
                        asl UL_temp_l
                        rol UL_temp_h
:                       rol
                        cmp UL_temp_div
                        bcc :+
                        sbc UL_temp_div
:                       rol UL_temp_l
                        rol UL_temp_h
                        dex
                        bne :--
                        ldy UL_temp_h
                        ldx UL_temp_l
                        rts
.endproc

.bss

UL_temp_div:           .res    1
