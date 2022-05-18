.include "unilib_impl.inc"

.code

; ulstr_fromUtf8 - Allocate a BRP string from a NUL-terminated UTF-8 source
;   In: YX              - Pointer to UTF-8 character sequence (must be in currently accessible memory)
;  Out: YX              - String BRP
;       carry           - Set on success
.proc ulstr_fromUtf8
                        ; Save A
                        pha

                        ; How many bytes are we copying?
                        jsr ULS_length

                        ; Is the source in banked memory?
                        cpy #$A0
                        bcc @allocdest
                        cpy #$C0
                        bcs @allocdest

                        ; Allocation may be on a different page, so copy to $700 just in case
                        stz ULS_scratch_fptr
                        lda #$07
                        sta ULS_scratch_fptr+1
                        lda ULS_bytelen
                        jsr ULS_copystrdata

                        ; Okay, save the address to copy from and allocate enough memory for our string data
                        ; plus 3 length bytes plus NUL-terminator
@allocdest:             stx @getcopysrclo+1
                        sty @getcopysrchi+1
                        ldx ULS_bytelen
                        ldy #0
                        inx
                        inx
                        inx
                        inx
                        bne :+
                        iny
:                       jsr ulmem_alloc
                        bcc @done

                        ; Save bank/BRP
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Access allocated memory
                        jsr ulmem_access

                        ; Set lengths in first three bytes(byte, char, print)
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        lda ULS_bytelen
                        sta (ULS_scratch_fptr)
                        inc ULS_scratch_fptr
                        lda ULS_charlen
                        sta (ULS_scratch_fptr)
                        inc ULS_scratch_fptr
                        lda ULS_printlen
                        sta (ULS_scratch_fptr)
                        inc ULS_scratch_fptr

                        ; Copy the UTF-8 character sequence
                        lda ULS_bytelen
@getcopysrclo:          ldx #$00
@getcopysrchi:          ldy #$00
                        jsr ULS_copystrdata

                        ; Restore BRP/bank and set success
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        sec

                        ; Restore A
@done:                  pla
                        rts
.endproc
