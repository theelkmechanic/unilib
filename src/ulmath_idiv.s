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
                        sta ULM_temp_div
                        sty ULM_temp_h
                        stx ULM_temp_l
                        ldx #16
                        lda #0
                        asl ULM_temp_l
                        rol ULM_temp_h
:                       rol
                        cmp ULM_temp_div
                        bcc :+
                        sbc ULM_temp_div
:                       rol ULM_temp_l
                        rol ULM_temp_h
                        dex
                        bne :--
                        ldy ULM_temp_h
                        ldx ULM_temp_l
                        rts
.endproc

.bss

ULM_temp_div:           .res    1
