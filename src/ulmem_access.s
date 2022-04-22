.include "unilib_impl.inc"

.code

; ulmem_access - Access the memory at a banked RAM pointer (BRP)
;   In: r0              - BRP
;  Out: BANKSEL::RAM    - Set to RAM bank from BRP
;       r0              - 16-bit address of memory
.proc ulmem_access
                        ; Get the BRP into YX
                        ldx gREG::r0L
                        ldy gREG::r0H

                        ; Call the internal version
                        jsr ULM_access

                        ; Store the result
                        sty gREG::r0H
                        stx gREG::r0L
                        rts
.endproc

; ULM_access - Access the memory at a banked RAM pointer (BRP)
;   In: YX              - BRP
;  Out: BANKSEL::RAM    - Set to RAM bank from BRP
;       YX              - 16-bit address of memory
.proc ULM_access
                        pha
                        sty BANKSEL::RAM
                        .byte $24 ; skip the pha at the start of ULM_slot2addr
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

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
