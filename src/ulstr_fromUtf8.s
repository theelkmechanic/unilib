.include "unilib_impl.inc"

.code

; ulstr_fromUtf8 - Allocate a BRP string from a NUL-terminated UTF-8 source
;   In: YX              - Pointer to UTF-8 character sequence (must be in currently accessible memory)
;  Out: YX              - String BRP
;       carry           - Set on success
.proc ulstr_fromUtf8
                        ; How many bytes are we copying?
                        jsr ULS_length

                        ; Save the source address and copy length
                        stx gREG::r0L
                        sty gREG::r0H
                        lda ULS_bytelen
                        sta gREG::r2L
                        stz gREG::r2H

                        ; Is the source in banked memory?
                        cpy #$A0
                        bcc @allocdest
                        cpy #$C0
                        bcs @allocdest

                        ; Allocation may be on a different page, so copy to $400 just in case
                        stz gREG::r1L
                        lda #$04
                        sta gREG::r1H
                        jsr MEMORY_COPY
                        lda gREG::r1L
                        sta gREG::r0L
                        lda gREG::r1H
                        sta gREG::r0H

                        ; Okay, allocate enough memory for our string data plus 3 length bytes plus NUL-terminator
@allocdest:             ldx ULS_bytelen
                        ldy #0
                        inx
                        inx
                        inx
                        inx
                        bne :+
                        iny
:                       jsr ulmem_alloc
                        bcc @done

                        ; Save bank
                        lda BANKSEL::RAM
                        pha

                        ; Save BRP
                        phx
                        phy

                        ; Access allocated memory
                        jsr ulmem_access

                        ; Set lengths in first three bytes(byte, char, print)
                        stx gREG::r1L
                        sty gREG::r1H
                        lda ULS_bytelen
                        sta (gREG::r1)
                        inc gREG::r1L
                        lda ULS_charlen
                        sta (gREG::r1)
                        inc gREG::r1L
                        lda ULS_printlen
                        sta (gREG::r1)
                        inc gREG::r1L

                        ; Copy the UTF-8 character sequence
                        jsr MEMORY_COPY

                        ; Stick a NUL-terminator on the end
                        ldy ULS_bytelen
                        lda #0
                        sta (gREG::r1),y

                        ; Restore BRP
                        ply
                        plx

                        ; Restore bank
                        pla
                        sta BANKSEL::RAM
                        sec
@done:                  rts
.endproc
