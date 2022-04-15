.include "unilib_impl.inc"

.code

; ulmem_access - Access the memory at a banked RAM "pointer"
;   In: Y               - RAM bank
;       X               - slot #
;  Out: BANKSEL::RAM    - Set to RAM bank from "pointer"
;       YX              - 16-bit address of memory
.proc ulmem_access
                        ; Set the RAM bank
                        pha
                        sty BANKSEL::RAM

                        ; We need to calculate the address, so skip the push at the beginning of
                        ; ULM_slot2addr
                        .byte $24 ; skip next 1-byte opcode
.endproc

; *** WARNING *** DON'T ADD CODE BETWEEN HERE OR YOU WILL BREAK THINGS

.proc ULM_slot2addr
                        ; Given a slot index in X, turn it into an address in YX; we multiply by 32
                        ; and add $A000 to get the address
                        pha
                        txa
                        lsr
                        lsr
                        lsr
                        clc
                        adc #$A0
                        tay
                        txa
                        asl
                        asl
                        asl
                        asl
                        asl
                        tax
                        pla
                        rts
.endproc