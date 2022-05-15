; ulmath_signed - Signed integer math helper functions

.include "unilib_impl.inc"

.code

; ulmath_scmp8_8 - Compare 8-bit to 8-bit (signed)
;   In: A               ; First value to compare
;       X               ; Second value to compare
;  Out: carry           ; Set if A >= X, clear if A < X
.proc ulmath_scmp8_8
                        pha
                        sec
                        stx UL_temp_l
                        sbc UL_temp_l
                        bvs :+
                        eor #$80
:                       asl
                        pla
                        rts
.endproc

; ulmath_abs_8 - Get absolute value of an 8-bit value
;   In: A               ; Signed value
;  Out: A               ; |A|
.proc ulmath_abs_8
                        bit #$80
                        beq a_logical_rts_to_use
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ulmath_negate_8 - Flip the sign of an 8-bit value
;   In: A               ; Value to flip
;  Out: A               ; -A
.proc ulmath_negate_8
                        sec
                        sta UL_temp_l
                        lda #0
                        sbc UL_temp_l
.endproc
a_logical_rts_to_use:   rts
