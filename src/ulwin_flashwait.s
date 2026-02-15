; ulwin_flashwait - Flash a message on the screen and wait

.include "unilib_impl.inc"

UL_CODE

; ulwin_flashwait - Flash a message on the screen and wait for timeout or keypress
;   In: r0              - message string BRP
;       r1              - title string BRP (0 = no title)
;       X               - foreground color
;       Y               - background color
;       A               - seconds to wait (0 = wait for keypress only)
.proc ulwin_flashwait
                        ; Save wait time before flash overwrites A
                        sta ULWFW_seconds
                        phx
                        phy
                        lda BANKSEL::RAM
                        pha

                        ; Save title BRP before we overwrite r1
                        lda gREG::r1L
                        sta ULWFW_titlebrp
                        lda gREG::r1H
                        sta ULWFW_titlebrp+1

                        ; Save and get message printable length
                        ldx gREG::r0L
                        ldy gREG::r0H
                        stx ULWFW_msgbrp
                        sty ULWFW_msgbrp+1
                        XCALL ulstr_getprintlen, UNILIB_BANK_A
                        cmp #0
                        bne :+
                        jmp @exit
:                       cmp #73
                        bcc :+
                        lda #73
:                       sta ULWFW_msglen

                        ; Check title length if present, use wider of msg/title
                        lda ULWFW_titlebrp
                        ora ULWFW_titlebrp+1
                        beq @no_title
                        ldx ULWFW_titlebrp
                        ldy ULWFW_titlebrp+1
                        XCALL ulstr_getprintlen, UNILIB_BANK_A
                        beq @no_title
                        cmp #71
                        bcc :+
                        lda #71
:                       cmp ULWFW_msglen
                        bcc @no_title
                        sta ULWFW_msglen

@no_title:              ; Window width is max(msglen, titlelen) + 2
                        lda ULWFW_msglen
                        inc
                        inc
                        sta ULWFW_width

                        ; r1 = size (width x 1)
                        sta gREG::r1L
                        lda #1
                        sta gREG::r1H

                        ; Center the window horizontally
                        lda #78
                        sec
                        sbc ULWFW_width
                        lsr
                        inc
                        sta gREG::r0L
                        lda #13
                        sta gREG::r0H

                        ; Color (saved from caller's X/Y)
                        tsx
                        lda $103,x              ; X was pushed third (after phx, phy, pha)
                        sta gREG::r2L
                        lda $102,x              ; Y was pushed second
                        sta gREG::r2H

                        ; Title
                        lda ULWFW_titlebrp
                        sta gREG::r3L
                        lda ULWFW_titlebrp+1
                        sta gREG::r3H

                        ; Border
                        lda #ULWIN_FLAGS::BORDER
                        sta gREG::r4H

                        ; Open the window
                        jsr ulwin_open
                        bpl :+
                        jmp @exit
:
                        ; Put the message string at (1, 0)
                        lda ULWFW_msgbrp
                        sta gREG::r0L
                        lda ULWFW_msgbrp+1
                        sta gREG::r0H
                        ldx #1
                        ldy #0
                        clc
                        jsr ulwin_putloc

                        ; Refresh the screen
                        jsr ulwin_refresh

                        ; If seconds == 0, just wait for keypress
                        lda ULWFW_seconds
                        beq @wait_key_only

                        ; Calculate target jiffy count: read current + seconds * 60
                        jsr RDTIM               ; A=high, X=mid, Y=low
                        sty ULWFW_target
                        stx ULWFW_target+1

                        ; Add seconds * 60 to target (16-bit only, good for up to ~18 min)
                        ldx ULWFW_seconds
                        lda #0
                        sta ULWFW_addval
                        sta ULWFW_addval+1
@mul_loop:              lda ULWFW_addval
                        clc
                        adc #60
                        sta ULWFW_addval
                        lda ULWFW_addval+1
                        adc #0
                        sta ULWFW_addval+1
                        dex
                        bne @mul_loop

                        lda ULWFW_target
                        clc
                        adc ULWFW_addval
                        sta ULWFW_target
                        lda ULWFW_target+1
                        adc ULWFW_addval+1
                        sta ULWFW_target+1

                        ; Wait loop: check keypress and time
@wait_loop:             jsr GETIN
                        cmp #0
                        bne @done_waiting       ; key pressed, exit

                        ; Check time
                        jsr RDTIM               ; A=high, X=mid, Y=low
                        ; Compare 16-bit: target - current (mid:low)
                        tya                     ; A = low byte of current
                        cmp ULWFW_target
                        txa                     ; A = mid byte of current
                        sbc ULWFW_target+1
                        bcc @wait_loop          ; current < target, keep waiting

@done_waiting:          ; Close the window
                        jsr ulwin_close
                        jsr ulwin_refresh

@exit:                  pla
                        sta BANKSEL::RAM
                        ply
                        plx
                        rts

@wait_key_only:         jsr ulwin_getkey
                        bra @done_waiting
.endproc

UL_BSS

ULWFW_seconds:          .res 1
ULWFW_msgbrp:           .res 2
ULWFW_titlebrp:         .res 2
ULWFW_msglen:           .res 1
ULWFW_width:            .res 1
ULWFW_target:           .res 2
ULWFW_addval:           .res 2
