.include "unilib_impl.inc"

.code

; ulstr_getlen - Get the length of a string
;   In: YX              - String BRP
;  Out: A               - UTF-8 string length (in characters)
.proc ulstr_getlen
                        ; Want the string length in characters (BRP[1])
                        lda #1
                        .byte $2c
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ulstr_getprintlen - Get the printable length of a string
;   In: YX              - String BRP
;  Out: A               - UTF-8 string length (in characters, only printable characters included)
.proc ulstr_getprintlen
                        ; Want the string length in printable characters (BRP[2])
                        lda #2
                        .byte $2c
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ulstr_getrawlen - Get the raw length of a string
;   In: YX              - String BRP
;  Out: A               - UTF-8 string length (in bytes)
.proc ulstr_getrawlen
                        ; Want the string length in bytes (BRP[0])
                        lda #0
                        sta @getlenoffset+1

                        ; Save RAM bank/X/Y
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Access the BRP
                        jsr ulmem_access
                        stx @getlen+1
                        sty @getlen+2

                        ; Get the desired length field
@getlenoffset:          ldx #$FF
@getlen:                lda $FFFF,x
                        sta @lenresult+1

                        ; Restore RAM bank/X/Y
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
@lenresult:             lda #$FF
                        rts
.endproc
