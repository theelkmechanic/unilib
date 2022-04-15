; ulmath_imul - Integer multiplication functions

.include "unilib_impl.inc"

ULM_multab_lo = BANK::RAM + $100
ULM_multab_hi = ULM_multab_lo + $200
ULM_multab_neg_lo = ULM_multab_hi + $200
ULM_multab_neg_hi = ULM_multab_neg_lo + $200

.code

; ulmath_umul8_8 - Multiply 8-bit by 8-bit (unsigned)
;   In: X               ; Multiplier
;       A               ; Multiplicand
;  Out: YX              ; Product
.proc ulmath_umul8_8
                        ; Save bank and switch to bank 1
                        pha
                        ldy BANKSEL::RAM
                        phy
                        ldy #1
                        sty BANKSEL::RAM

                        ; Multiply X*A
                        tay
                        jsr ULM_mulXY

                        ; Restore the original bank
                        pla
                        sta BANKSEL::RAM
                        pla
                        rts
.endproc

; ulmath_umul16_8 - Multiply 16-bit by 8-bit (unsigned)
;   In: YX              ; Multiplier
;       A               ; Multiplicand
;  Out: AYX             ; Product
.proc ulmath_umul16_8
                        ; Save bank and switch to bank 1
                        sty ULM_temp_l
                        ldy BANKSEL::RAM
                        phy
                        ldy #1
                        sty BANKSEL::RAM

                        ; Multiply A*X
                        tay
                        jsr ULM_mulXY

                        ; X is product low byte, so hang onto it, and save Y for addition
                        phx
                        sty ULM_temp_h

                        ; Multiply A*Y
                        ldy ULM_temp_l
                        tax
                        jsr ULM_mulXY

                        ; Y is product high byte, so hang onto it
                        phy

                        ; Add Y from first result to X from second to get product middle byte
                        txa
                        clc
                        adc ULM_temp_h
                        tay

                        ; And then add the carry from that into the high byte
                        pla
                        adc #0

                        ; And get the low byte
                        plx

                        ; Restore the original bank
                        sta ULM_temp_h
                        pla
                        sta BANKSEL::RAM
                        lda ULM_temp_h
                        rts
.endproc

; ULM_mulXY - Multiply X * Y, result in YX, bank must be set to 1
.proc ULM_mulXY
                        ; Modify the pointers in our code to point to the right slot for one operand
                        pha
                        txa
                        sta @sm1+1
                        sta @sm3+1
                        eor #$ff
                        sta @sm2+1
                        sta @sm4+1

                        ; Multiply by the other operand by subtracting values from our tables
                        sec
@sm1:                   lda ULM_multab_lo,y
@sm2:                   sbc ULM_multab_neg_lo,y
                        tax
@sm3:                   lda ULM_multab_hi,y
@sm4:                   sbc ULM_multab_neg_hi,y
                        tay
                        pla
                        rts
.endproc

; ULM_multbl_init - Build the multiplication square tables
;   *** WARNING *** This must be the fist memory allocation call, or it will break badly. It 
.proc ULM_multbl_init
                        ; Allocate 2048 bytes for our math tables
                        ldx #<2048
                        ldy #>2048
                        clc
                        jsr ulmem_alloc

                        ; *** WARNING *** We're assuming that this was the first ulmem_alloc, so the
                        ; allocated memory is at $A100 on bank 1. If this was NOT the first ulmem_alloc,
                        ; this will trash whatever was in there and things will not go well for you.

                        ; Switch to bank 1
                        sty BANKSEL::RAM

                        ; Build the multab table
                        ldx #$00
                        txa
                        .byte $c9   ; CMP #immediate - skip TYA and clear carry flag
@table_loop:            tya
                        adc #$00
@ml1:                   sta ULM_multab_hi,x
                        tay
                        cmp #$40
                        txa
                        ror
@ml9:                   adc #$00
                        sta @ml9+1
                        inx
@ml0:                   sta ULM_multab_lo,x
                        bne @table_loop
                        inc @ml0+2
                        inc @ml1+2
                        clc
                        iny
                        bne @table_loop

                        ; Now build the multab_neg table
                        ldx #$00
                        dey
:                       lda ULM_multab_hi+1,x
                        sta ULM_multab_neg_hi+$100,x
                        lda ULM_multab_hi,x
                        sta ULM_multab_neg_hi,y
                        lda ULM_multab_lo+1,x
                        sta ULM_multab_neg_lo+$100,x
                        lda ULM_multab_lo,x
                        sta ULM_multab_neg_lo,y
                        dey
                        inx
                        bne :-
                        rts
.endproc

.bss

ULM_temp_l:             .res    1
ULM_temp_h:             .res    1
