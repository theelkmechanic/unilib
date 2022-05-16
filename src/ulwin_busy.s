.include "unilib_impl.inc"

.code

; ulwin_busy - Draw a "Busy..." window in the bottom left corner (refreshes, displayed until the next refresh)
;   In: carry           - Use custom message in YX
;       YX (optional)   - If carry set, string BRP for custom message
.proc ulwin_busy
                        ; Save A/X/Y/RAM bank
                        pha
                        phx
                        phy
                        lda BANKSEL::RAM
                        pha

                        ; Do we have a custom busy message?
                        bcs @openbusywindow

                        ; Make sure we have our default "Busy..." string
                        ldx ULW_busystr
                        ldy ULW_busystr+1
                        bne @openbusywindow
                        ldx #<ULW_busymsg
                        ldy #>ULW_busymsg
                        jsr ulstr_fromUtf8
                        bcc @exit
                        stx ULW_busystr
                        sty ULW_busystr+1

                        ; Get the string printable length (if empty then do nothing)
@openbusywindow:        jsr ulstr_getprintlen
                        beq @exit

                        ; We need at least 6 extra characters for borders/margins, so max length is 74
                        cmp #74
                        bcc :+
                        lda #74
:                       sta @getmsglen+1

                        ; Window width is length + 2
                        inc
                        inc
                        sta gREG::r1L
                        lda #3
                        sta gREG::r1H

                        ; Window left is 76 - length
                        lda #76
                        sec
@getmsglen:             sbc #$00
                        sta gREG::r0L
                        lda #25
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

                        ; Put the string in our window at 1,1
                        stx gREG::r0L
                        sty gREG::r0H
                        ldx #1
                        ldy #1
                        jsr ulwin_putcursor
                        clc
                        jsr ulwin_putstr

                        ; Refresh the screen
                        jsr ulwin_refresh

                        ; And close the window
                        jsr ulwin_close

                        ; Restore A/X/Y/RAM bank
@exit:                  pla
                        sta BANKSEL::RAM
                        ply
                        plx
                        pla
                        rts
.endproc

.rodata

ULW_busymsg:            .asciiz "Busy..."

.bss

ULW_busystr:            .res    2
