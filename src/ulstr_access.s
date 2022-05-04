.include "unilib_impl.inc"

.code

; ulstr_access - Access the data in a string
;   In: YX              - String BRP
;  Out: YX              - Address of NUL-terminated UTF-8 string data in YX (copies to $400 low RAM scratch buffer if not in current RAM bank)
.proc ulstr_access
                        ; If the Y is the same as the current bank, just access it (data is 3 bytes in)
                        cpy BANKSEL::RAM
                        bne @needcopy
                        jsr ulmem_access
                        inx
                        inx
                        inx
                        rts

                        ; Save bank and switch
@needcopy:              sta ULS_scratch_fptr+2
                        lda BANKSEL::RAM
                        pha
                        lda ULS_scratch_fptr+2
                        sta BANKSEL::RAM

                        ; Copy bytelen+1 bytes (to get the NUL) from scratch+3 to $400
                        lda (ULS_scratch_fptr)
                        tay
                        inc ULS_scratch_fptr
                        inc ULS_scratch_fptr
                        inc ULS_scratch_fptr
:                       lda (ULS_scratch_fptr),y
                        sta $400,y
                        dey
                        bpl :-

                        ; At end of string, so load new address into YX
@usecopy:               ldx #0
                        ldy #4

                        ; Switch bank back
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc
