.include "unilib_impl.inc"

.code

; ulmem_access - Access the memory at a banked RAM "pointer"
;   In: Y               - RAM bank
;       X               - slot #
;  Out: BANKSEL::RAM        - Set to RAM bank from "pointer"
;       YX              - 16-bit address of memory
.proc ulmem_access
                        ; Set the RAM bank
                        pha
                        sty BANKSEL::RAM

                        ; We need to multiply the slot # by 32 and add $A000 to get the address
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
