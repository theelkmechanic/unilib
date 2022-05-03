.include "unilib_impl.inc"

.code

; ulstr_access - Access the data in a string
;   In: YX              - String BRP
;  Out: YX              - Address of NUL-terminated UTF-8 string data in YX (copies to $400-7ff low RAM scratch buffer if not in current RAM bank)
.proc ulstr_access
                        ; If the Y is the same as the current bank, just access it
                        cpy BANKSEL::RAM
                        bne @needcopy
                        jmp ulmem_access

                        ; Save bank and switch
@needcopy:              sta ULS_scratch_fptr+2
                        lda BANKSEL::RAM
                        pha
                        lda ULS_scratch_fptr+2
                        sta BANKSEL::RAM

                        ; Copy from scratch to $700 until we hit a null or the end of the page
                        ldy #0
@copychar:              lda (ULS_scratch_fptr),y
                        sta $700,y
                        tax
                        iny
                        lda (ULS_scratch_fptr),y
                        sta $700,y
                        iny
                        beq @neednull
                        cmp #0
                        bne @copychar
                        cpx #0
                        bne @copychar

                        ; At end of string, so load new address into YX
@usecopy:               ldx #0
                        ldy #7

                        ; Switch bank back
                        pla
                        sta BANKSEL::RAM
                        rts

@neednull:              ; From copy routine above, used the whole page so need to back up one character and put in a NUL
                        tya
                        dey
                        sta $700,y
                        dey
                        sta $700,y
                        bra @usecopy
.endproc

.segment "EXTZP": zeropage

ULS_scratch_fptr:       .res    3
