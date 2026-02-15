; ulwin_error

.include "unilib_impl.inc"

UL_CODE

; ulwin_error - Display a popup window with an error message and wait for keypress
;   In: r0              - error message string BRP
.proc ulwin_error
                        ; Prevent recursion
                        lda ULW_inerror
                        bne @skip
                        lda #1
                        sta ULW_inerror

                        ; Save registers/bank
                        phx
                        phy
                        lda BANKSEL::RAM
                        pha

                        ; Get the string printable length (if empty then do nothing)
                        ldx gREG::r0L
                        ldy gREG::r0H
                        XCALL ulstr_getprintlen, UNILIB_BANK_A
                        beq @exit

                        ; Max length is 73 (screen is 80, minus border/margins)
                        cmp #73
                        bcc :+
                        lda #73
:                       sta ULWE_msglen

                        ; Window width is length + 2
                        inc
                        inc
                        sta gREG::r1L
                        lda #1
                        sta gREG::r1H

                        ; Center the window horizontally: col = (78 - width) / 2 + 1
                        lda #78
                        sec
                        sbc gREG::r1L
                        lsr
                        inc
                        sta gREG::r0L
                        ; Center vertically: line = 13 (near middle of 30-line screen)
                        lda #13
                        sta gREG::r0H

                        ; Color is error window color
                        lda ULW_errorfg
                        sta gREG::r2L
                        lda ULW_errorbg
                        sta gREG::r2H

                        ; No title
                        stz gREG::r3L
                        stz gREG::r3H

                        ; Border
                        lda #ULWIN_FLAGS::BORDER
                        sta gREG::r4H

                        ; Open the window
                        jsr ulwin_open
                        bmi @exit

                        ; Put the string in our window at one space over
                        stx gREG::r0L
                        sty gREG::r0H
                        ldx #1
                        ldy #0
                        clc
                        jsr ulwin_putloc

                        ; Refresh the screen
                        jsr ulwin_refresh

                        ; Wait for keypress
                        jsr ulwin_getkey

                        ; Close the window
                        jsr ulwin_close

                        ; Refresh to remove the popup
                        jsr ulwin_refresh

@exit:                  pla
                        sta BANKSEL::RAM
                        ply
                        plx
                        stz ULW_inerror
@skip:                  rts
.endproc

; ulwin_errorcfg - Set error/busy message colors
;   In: X               - Error foreground color
;       Y               - Error background color
.proc ulwin_errorcfg
                        stx ULW_errorfg
                        sty ULW_errorbg
                        rts
.endproc

UL_DATA

ULW_errorfg:    .byte   ULCOLOR::WHITE      ; error window foreground color
ULW_errorbg:    .byte   ULCOLOR::RED        ; error window background color

UL_BSS

ULW_inerror:    .res    1                   ; in error display flag
ULWE_msglen:    .res    1
