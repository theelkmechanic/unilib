.include "unilib_impl.inc"

.segment "EXTZP" : zeropage

UL_temp_l:              .res    1   ; Temp variables/pointer for general use
UL_temp_h:              .res    1

UL_varptr:              .res    2   ; variable pointer for core functions
UL_var2ptr:             .res    2   ; variable pointer for core functions

ULW_scratch_fptr:       .res    3   ; scratch pointer for window operations

ULS_scratch_char:       .res    3   ; scratch Unicode character for string operations
ULS_scratch_fptr:       .res    3   ; scratch pointer for string operations

.code

; UL_getrng - Check 16-bit address high byte range to see what kind of memory it's in
;   In: Y               - Address high byte
;  Out: A               - $80 = banked RAM  (N set,   use BMI)
;                         $40 = I/O         (V set,   use BVS)
;                         $20 = ROM         (Z clear, use BNE)
;                         $10 = low RAM     (Z set,   use BEQ)
.proc UL_getrng
                        ; Set correct bit based on memory region
                        lda #$80
                        cpy #$c0
                        bcs @rom
                        cpy #$9f
                        beq @io
                        bcs @bankedram
                        lsr
@rom:                   lsr
@io:                    lsr
@bankedram:
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; UL_chkrng - Check 16-bit address high byte range to see what kind of memory it's in
;   In: A               - Address range flags ($80 = banked RAM, $40 = I/O, $20 = ROM, $10 = low RAM)
;  Out: flags           - N set = banked RAM (use BMI)
;                         V set = I/O        (use BVS)
;                         Z clear = ROM      (use BNE)
;                         Z set = low RAM    (use BEQ)
.proc UL_chkrng
                        ; Set flags correctly based on bit
                        sta UL_temp_l
                        lda #$20
                        bit UL_temp_l
                        php
                        lda UL_temp_l
                        plp
                        rts
.endproc

; UL_sbc16 - Subtract 16-bit value from *UL_varptr
;   In: UL_varptr       - Pointer to 16-bit variable
;       YX              - Value to subtract
;  Out: carry           - set/clear based on subtraction
UL_sbc16:
                        ; Subtract value from variable
                        pha
                        phy
                        txa
                        sec
                        sbc (UL_varptr)
                        sta (UL_varptr)
                        tya
                        ldy #1
                        sbc (UL_varptr),y
                        bra finish_addsub

; UL_adc16 - Add 16-bit value to *UL_varptr
;   In: UL_varptr       - Pointer to 16-bit variable
;       YX              - Value to add
;  Out: carry           - set/clear based on addition
UL_adc16:
                        ; Add value to variable
                        pha
                        phy
                        txa
                        clc
                        adc (UL_varptr)
                        sta (UL_varptr)
                        tya
                        ldy #1
                        adc (UL_varptr),y
finish_addsub:          sta (UL_varptr),y
                        ply
                        pla
                        rts

; UL_mulxby32 - Multiply X by 32
;   In: X               - value
;  Out: YX              - value * 32
UL_mulxby32:
                        txa
                        lsr
                        lsr
                        lsr
                        tay
                        txa
                        asl
                        asl
                        asl
                        asl
                        asl
                        tax
                        rts

; UL_divyxby32 - Divide YX by 32 (round up)
;   In: YX              - value
;  Out: YX              - value / 32 (+ 1 if value % 32 != 0)
UL_divyxby32:
                        ; Check low 5 bits to see if we need a +1
                        pha
                        stz UL_temp_l
                        sty UL_temp_h
                        txa
                        and #$1f
                        beq :+
                        inc UL_temp_l

                        ; Divide size by 32
:                       txa
                        ldx #5
:                       lsr UL_temp_h
                        ror
                        dex
                        bne :-
                        ldy UL_temp_h

                        ; And add 1 if we need to
                        ror UL_temp_l
                        adc #0
                        tax
                        pla
                        rts

UL_terminate:
                        ; Hit a fatal internal error, so die (TODO: print a nice message)
                        lda #0
                        clc
                        jsr SCREEN_MODE
                        lda #2
                        jsr SCREEN_SET_CHARSET
                        clc
                        jmp ENTER_BASIC

.bss

UL_lasterr:             .res    1
