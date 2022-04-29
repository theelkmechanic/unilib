.include "unilib_impl.inc"

.segment "EXTZP": zeropage

ULS_scratch_fptr:       .res    3

.code

; ulstr_getlen - Get the length of a UTF-16 string (NUL-terminated)
;   In: AYX             - Far pointer to string
;       carry           - Set = only include printable characters, clear = include all characters
;  Out: YX              - String length (in characters)
.proc ulstr_getlen
                        ; Save pointer/bank
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        ldx BANKSEL::RAM
                        phx
                        sta BANKSEL::RAM

                        ; Save just-printable flag
                        ror ULS_scratchflag

                        ; Zero the length counter
                        stz ULS_scratchlen
                        stz ULS_scratchlen+1

                        ; Now count the words until we hit a NUL
@checknull:             ldy #1
                        lda (ULS_scratch_fptr),y
                        tay
                        lda (ULS_scratch_fptr)
                        bne @checkprint
                        cpy #0
                        beq @eos

                        ; If we need to check printable, check it
@checkprint:            bit ULS_scratchflag
                        bpl @justcount
                        tax
                        jsr ULFT_findcharinfo
                        bcc @steptonext

                        ; Count the character
@justcount:             inc ULS_scratchlen
                        bne @steptonext
                        inc ULS_scratchlen+1

                        ; Step to the next character
@steptonext:            inc ULS_scratch_fptr
                        bne :+
                        inc ULS_scratch_fptr+1
:                       inc ULS_scratch_fptr
                        bne @checknull
                        inc ULS_scratch_fptr+1
                        bra @checknull

                        ; End of string, so return character count
@eos:                   ldx ULS_scratchlen
                        ldy ULS_scratchlen+1

                        ; Restore bank
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

.bss

ULS_scratchlen:         .res    2
ULS_scratchflag:        .res    1
