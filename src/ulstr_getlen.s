.include "unilib_impl.inc"

UL_CODE

; ulstr_getrawlen - Get the raw byte length of a string
;   In: YX              - String handle (MSGBLOCK pool index)
;  Out: A               - UTF-8 string length (in bytes)
.proc ulstr_getrawlen
                        ; Save caller's bank and registers
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Access MB
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; rawlen = end - start
                        ldy #ULMSG_BLOCK::end
                        lda (UL_varptr),y
                        sec
                        ldy #ULMSG_BLOCK::start
                        sbc (UL_varptr),y
                        sta ULSG_result

                        ; Restore bank and registers
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULSG_result
                        rts
.endproc

; ulstr_getlen - Get the character length of a string
;   In: YX              - String handle (MSGBLOCK pool index)
;  Out: A               - UTF-8 string length (in characters)
.proc ulstr_getlen
                        ; Save caller's bank and registers
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Access string data via ULS_access (copies to scratch with NUL)
                        jsr ULS_access

                        ; Scan characters using ULS_nextchar
                        stz ULSG_count
@loop:                  XCALL ULS_nextchar, UNILIB_BANK_B
                        bcs @done               ; hit end
                        inc ULSG_count
                        bra @loop

@done:                  ; Restore bank and registers
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULSG_count
                        rts
.endproc

; ulstr_getprintlen - Get the printable character length of a string
;   In: YX              - String handle (MSGBLOCK pool index)
;  Out: A               - UTF-8 string length (in printable characters)
.proc ulstr_getprintlen
                        ; Save caller's bank and registers
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Access string data via ULS_access (copies to scratch with NUL)
                        jsr ULS_access

                        ; Scan characters, count printable ones
                        stz ULSG_count
@loop:                  XCALL ULS_nextchar, UNILIB_BANK_B
                        bcs @done               ; hit end
                        jsr ul_isprint
                        bcc @loop               ; not printable
                        inc ULSG_count
                        bra @loop

@done:                  ; Restore bank and registers
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULSG_count
                        rts
.endproc

UL_BSS

ULSG_result:            .res 1
ULSG_count:             .res 1
