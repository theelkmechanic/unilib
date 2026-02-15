.include "unilib_impl.inc"

UL_CODE

; ulwin_busy - Draw a "Busy..." window in the bottom left corner (refreshes, displayed until the next refresh)
;   In: carry           - Use custom message in YX
;       YX (optional)   - If carry set, string BRP for custom message
.proc ulwin_busy
                        ; Save A before register saves clobber it
                        pha

                        ; Save caller's r0-r4 (KERNAL convention)
                        ; Note: lda/pha do not affect carry, so carry input is preserved
                        lda gREG::r0L
                        pha
                        lda gREG::r0H
                        pha
                        lda gREG::r1L
                        pha
                        lda gREG::r1H
                        pha
                        lda gREG::r2L
                        pha
                        lda gREG::r2H
                        pha
                        lda gREG::r3L
                        pha
                        lda gREG::r3H
                        pha
                        lda gREG::r4L
                        pha
                        lda gREG::r4H
                        pha

                        ; Save X/Y/RAM bank
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
                        XCALL ulstr_fromUtf8, UNILIB_BANK_A
                        bcs @exit
                        stx ULW_busystr
                        sty ULW_busystr+1

                        ; Get the string printable length (if empty then do nothing)
@openbusywindow:        XCALL ulstr_getprintlen, UNILIB_BANK_A
                        beq @exit

                        ; We need at least 7 extra characters for borders/margins, so max length is 73
                        cmp #73
                        bcc :+
                        lda #73
:                       sta ULWB_msglen

                        ; Window width is length + 2
                        inc
                        inc
                        sta gREG::r1L
                        lda #1
                        sta gREG::r1H

                        ; Window left is 75 - length
                        lda #75
                        sec
                        sbc ULWB_msglen
                        sta gREG::r0L
                        lda #27
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

                        ; And close the window
                        jsr ulwin_close

@exit:                  pla
                        sta BANKSEL::RAM
                        ply
                        plx
                        ; Restore caller's r0-r4
                        pla
                        sta gREG::r4H
                        pla
                        sta gREG::r4L
                        pla
                        sta gREG::r3H
                        pla
                        sta gREG::r3L
                        pla
                        sta gREG::r2H
                        pla
                        sta gREG::r2L
                        pla
                        sta gREG::r1H
                        pla
                        sta gREG::r1L
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        ; Restore A
                        pla
                        rts
.endproc

UL_RODATA

ULW_busymsg:            .asciiz "Busy..."

UL_BSS

ULW_busystr:            .res    2
ULWB_msglen:            .res    1
