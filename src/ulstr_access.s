.include "unilib_impl.inc"

.code

; ulstr_access - Access the data in a string
;   In: YX              - String BRP
;  Out: YX/ULS_scratch_fptr - Address of NUL-terminated UTF-8 string data in YX (copies to $400 low RAM scratch buffer if not in current RAM bank)
.proc ulstr_access
                        ; If the Y is the same as the current bank, just access it (data is 3 bytes in)
                        sty ULS_scratch_fptr+2
                        cpy BANKSEL::RAM
                        bne @needcopy
                        jsr ulmem_access
                        bra @return_charstart

                        ; Need to copy to low memory, so save bank and switch
@needcopy:              lda BANKSEL::RAM
                        pha
                        lda ULS_scratch_fptr+2
                        sta BANKSEL::RAM

                        ; Copy bytelen+4 bytes (to get the NUL and the lengths) from scratch to $400
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        lda (ULS_scratch_fptr)
                        clc
                        adc #4
                        tay
:                       dey
                        lda (ULS_scratch_fptr),y
                        sta $400,y
                        cpy #0
                        bne :-

                        ; Switch bank back (and since we're in $4xx, can use same bank for string data just in case)
                        pla
                        sta BANKSEL::RAM
                        sta ULS_scratch_fptr+2

                        ; And set ULS_scratch_fptr and YX to our copy
                        ldx #0
                        ldy #4
@return_charstart:      inx
                        inx
                        inx
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        rts
.endproc
