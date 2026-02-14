; ulmath_imul - Integer multiplication functions

.include "unilib_impl.inc"

; Hardcoded addresses on RAM bank 1 ($A000-$A7FF = 2KB math tables, $B660 = SMC copy)
ULM_multab_lo = BANK::RAM                      ; $A000
ULM_multab_hi = ULM_multab_lo + $200           ; $A200
ULM_multab_neg_lo = ULM_multab_hi + $200       ; $A400
ULM_multab_neg_hi = ULM_multab_neg_lo + $200   ; $A600
ULM_mulXY_ram = $B660                          ; RAM copy of ULM_mulXY in bank 1

UL_CODE

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
                        jsr ULM_mulXY_ram

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
                        sty UL_temp_l
                        ldy BANKSEL::RAM
                        phy
                        ldy #1
                        sty BANKSEL::RAM

                        ; Multiply A*X
                        tay
                        jsr ULM_mulXY_ram

                        ; X is product low byte, so hang onto it, and save Y for addition
                        phx
                        sty UL_temp_h

                        ; Multiply A*Y
                        ldy UL_temp_l
                        tax
                        jsr ULM_mulXY_ram

                        ; Y is product high byte, so hang onto it
                        phy

                        ; Add Y from first result to X from second to get product middle byte
                        txa
                        clc
                        adc UL_temp_h
                        tay

                        ; And then add the carry from that into the high byte
                        pla
                        adc #0

                        ; And get the low byte
                        plx

                        ; Restore the original bank
                        sta UL_temp_h
                        pla
                        sta BANKSEL::RAM
                        lda UL_temp_h
                        rts
.endproc

; ULM_multbl_init - Build the multiplication square tables
;   *** WARNING *** This must be the first memory allocation call, or it will break badly.
.proc ULM_multbl_init
                        ; Tables live at hardcoded addresses on bank 1 (already selected by caller)
                        ; No heap allocation needed

                        ; Initialize accumulator (replaces self-modifying ADC immediate)
                        stz ULM_init_accum

                        ; Build the multab table: f(n) = floor(n^2 / 4), n = 0..511
                        ldy #$00
                        tya
                        tax
                        clc

                        ; Page 1: entries 0-255
@page1_loop:            tya
                        adc #$00
                        sta ULM_multab_hi,x
                        tay
                        cmp #$40
                        txa
                        ror
                        adc ULM_init_accum
                        sta ULM_init_accum
                        inx
                        sta ULM_multab_lo,x
                        bne @page1_loop

                        ; Transition to page 2
                        clc
                        iny

                        ; Page 2: entries 256-511
@page2_loop:            tya
                        adc #$00
                        sta ULM_multab_hi+$100,x
                        tay
                        cmp #$40
                        txa
                        ror
                        adc ULM_init_accum
                        sta ULM_init_accum
                        inx
                        sta ULM_multab_lo+$100,x
                        bne @page2_loop

                        ; Now build the multab_neg table
                        ldx #$00
                        ldy #$ff
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

                        ; Copy ULM_mulXY template to bank 1 RAM at ULM_mulXY_ram
                        ldx #ULM_mulXY_size - 1
:                       lda ULM_mulXY,x
                        sta ULM_mulXY_ram,x
                        dex
                        bpl :-

                        rts
.endproc

; ULM_mulXY - Multiply X * Y, result in YX, bank must be set to 1
; Read-only template copied to bank 1 RAM by ULM_multbl_init.
; The STA targets are pre-computed to point into the RAM copy, not this template.
ULM_mulXY:
                        ; Modify the pointers in the RAM copy to index the right table slot
                        pha
                        txa
                        sta ULM_mulXY_ram + (ULM_mulXY_sm1 - ULM_mulXY) + 1
                        sta ULM_mulXY_ram + (ULM_mulXY_sm3 - ULM_mulXY) + 1
                        eor #$ff
                        sta ULM_mulXY_ram + (ULM_mulXY_sm2 - ULM_mulXY) + 1
                        sta ULM_mulXY_ram + (ULM_mulXY_sm4 - ULM_mulXY) + 1

                        ; Multiply by the other operand by subtracting values from our tables
                        sec
ULM_mulXY_sm1:          lda ULM_multab_lo,y
ULM_mulXY_sm2:          sbc ULM_multab_neg_lo,y
                        tax
ULM_mulXY_sm3:          lda ULM_multab_hi,y
ULM_mulXY_sm4:          sbc ULM_multab_neg_hi,y
                        tay
                        pla
                        rts
ULM_mulXY_end:

ULM_mulXY_size = ULM_mulXY_end - ULM_mulXY

UL_BSS

ULM_init_accum:         .res    1
