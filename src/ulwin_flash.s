; ulwin_flash - Flash a message on the screen

.include "unilib_impl.inc"

UL_CODE

; ulwin_flash - Flash a message on the screen
;   In: r0              - message string BRP
;       r1              - title string BRP (0 = no title)
;       X               - foreground color
;       Y               - background color
.proc ulwin_flash
                        ; Save registers/bank
                        stx ULWFL_fg
                        sty ULWFL_bg

                        ; Save caller's r0-r4 (KERNAL convention)
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

                        phx
                        phy
                        lda BANKSEL::RAM
                        pha

                        ; Save title BRP before we overwrite r1
                        lda gREG::r1L
                        sta ULWFL_titlebrp
                        lda gREG::r1H
                        sta ULWFL_titlebrp+1

                        ; Save and get message printable length
                        ldx gREG::r0L
                        ldy gREG::r0H
                        stx ULWFL_msgbrp
                        sty ULWFL_msgbrp+1
                        XCALL ulstr_getprintlen, UNILIB_BANK_A
                        cmp #0
                        bne :+
                        jmp @exit
:                       cmp #73
                        bcc :+
                        lda #73
:                       sta ULWFL_msglen

                        ; Check title length if present, use wider of msg/title
                        lda ULWFL_titlebrp
                        ora ULWFL_titlebrp+1
                        beq @no_title
                        ldx ULWFL_titlebrp
                        ldy ULWFL_titlebrp+1
                        XCALL ulstr_getprintlen, UNILIB_BANK_A
                        beq @no_title
                        cmp #71
                        bcc :+
                        lda #71
:                       cmp ULWFL_msglen
                        bcc @no_title
                        sta ULWFL_msglen          ; title wider than message

@no_title:              ; Window width is max(msglen, titlelen) + 2
                        lda ULWFL_msglen
                        inc
                        inc
                        sta ULWFL_width

                        ; r1 = size (width x 1)
                        sta gREG::r1L
                        lda #1
                        sta gREG::r1H

                        ; Center the window horizontally
                        lda #78
                        sec
                        sbc ULWFL_width
                        lsr
                        inc
                        sta gREG::r0L
                        lda #13
                        sta gREG::r0H

                        ; Color
                        lda ULWFL_fg
                        sta gREG::r2L
                        lda ULWFL_bg
                        sta gREG::r2H

                        ; Title (ulwin_open uses r3 for title)
                        lda ULWFL_titlebrp
                        sta gREG::r3L
                        lda ULWFL_titlebrp+1
                        sta gREG::r3H

                        ; Border
                        lda #ULWIN_FLAGS::BORDER
                        sta gREG::r4H

                        ; Open the window
                        jsr ulwin_open
                        bmi @exit

                        ; Put the message string at (1, 0)
                        lda ULWFL_msgbrp
                        sta gREG::r0L
                        lda ULWFL_msgbrp+1
                        sta gREG::r0H
                        ldx #1
                        ldy #0
                        clc
                        jsr ulwin_putloc

                        ; Refresh the screen
                        jsr ulwin_refresh

                        ; Close the window (message stays until next refresh)
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
                        rts
.endproc

UL_BSS

ULWFL_fg:               .res 1
ULWFL_bg:               .res 1
ULWFL_msgbrp:           .res 2
ULWFL_titlebrp:         .res 2
ULWFL_msglen:           .res 1
ULWFL_width:            .res 1
