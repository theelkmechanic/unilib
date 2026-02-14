.include "unilib_impl.inc"

UL_CODE

; ulwin_putstr - Output a string at the current cursor location in a window
;   In: A               - Window handle
;       r0              - String BRP to output
;       carry           - Set to allow wrap/scroll
.proc ulwin_putstr
                        ; Get the current cursor position
                        php
                        jsr ulwin_getcursor
                        plp
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ulwin_putloc - Output a string at a specified location in a window (updates cursor position)
;   In: A               - Window handle
;       X               - Starting column for string
;       Y               - Starting line for string
;       r0              - String BRP to output
;       carry           - Set to allow wrap/scroll
.proc ulwin_putloc
                        ; Save A/X/Y/RAM bank/carry flag
                        sta ULW_WINDOW_COPY::handle
                        stx ULWR_dest
                        sty ULWR_dest+1
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy
                        ror ULWPL_wrapflag

                        ; Get the window structure
                        lda ULW_WINDOW_COPY::handle
                        jsr ULW_getwinstruct

                        ; Make sure the start position is inside the window contents
                        lda ULWR_dest
                        bmi @exit
                        cmp ULW_WINDOW_COPY::ncol
                        bcs @exit
                        lda ULWR_dest+1
                        bmi @exit
                        cmp ULW_WINDOW_COPY::nlin
                        bcs @exit

                        ; Get printlen first (before ULS_access clobbers things)
                        ldx gREG::r0L
                        ldy gREG::r0H
                        XCALL ulstr_getprintlen, UNILIB_BANK_A   ; A = printlen
                        beq @exit
                        sta ULWPL_saved_printlen

                        ; Access the string data
                        ldx gREG::r0L
                        ldy gREG::r0H
                        XCALL ULS_access, UNILIB_BANK_A

                        ; Load printlen for first @printstr iteration
                        lda ULWPL_saved_printlen

                        ; Print what we can on this line
@printstr:              sta ULWR_destsize
                        sta ULWPL_remaining_len
                        jsr ULW_drawstring

                        ; Check if there are characters remaining to print
                        cmp ULWPL_remaining_len
                        beq @updatecursor

                        ; Do we want to wrap/scroll?
                        bit ULWPL_wrapflag
                        bpl @updatecursor

                        ; Wrap to next line
                        stz ULWR_dest
                        ldy ULWR_dest+1
                        inc
                        cpy ULW_WINDOW_COPY::nlin 
                        bcc @noscroll

                        ; At bottom of window, so scroll
                        pha
                        lda ULW_WINDOW_COPY::handle
                        ldx #0
                        ldy #$ff
                        jsr ulwin_scroll
                        pla
                        stz ULWR_dest
                        ldy ULW_WINDOW_COPY::nlin
                        dec
@noscroll:              sty ULWR_dest+1
                        bra @printstr

                        ; Update the cursor to the end of whatever we printed
@updatecursor:          clc
                        adc ULWR_dest
			tax
                        ldy ULWR_dest+1
                        jsr ULW_putcursor

                        ; Restore A/X/Y/RAM bank
@exit:                  ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULW_WINDOW_COPY::handle
                        rts

.endproc

UL_BSS

ULWPL_saved_printlen:   .res 1
ULWPL_wrapflag:         .res 1
ULWPL_remaining_len:    .res 1
