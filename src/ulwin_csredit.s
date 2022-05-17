.include "unilib_impl.inc"

.code

ULW_worker_moverestofline:
                        stx ULW_move_srcnopinc
                        sty ULW_move_destincdec
                        lda ULW_WINDOW_COPY::ccol
ULW_move_srcnopinc:     inc
                        sta ULWR_src
ULW_move_destincdec:    inc
                        sta ULWR_dest

                        lda ULW_WINDOW_COPY::ncol
                        clc
                        sbc ULW_WINDOW_COPY::ccol
                        sta ULWR_destsize

                        lda ULW_WINDOW_COPY::clin
                        sta ULWR_src+1
                        sta ULWR_dest+1
                        lda #1
                        sta ULWR_destsize+1
                        jmp ULW_copyrect

ULW_worker_delchar:
                        ; Make sure we are onscreen
                        lda ULW_WINDOW_COPY::ncol
                        dec
                        cmp ULW_WINDOW_COPY::ccol
                        beq :+
                        bcc exitbounce

                        ; Shift left one character
                        ldx #$1A ; INC
                        ldy #$3A ; DEC
                        jsr ULW_worker_moverestofline

                        ; And clear last character cell
:                       lda ULW_WINDOW_COPY::ncol
                        dec
                        sta ULWR_dest
                        lda ULW_WINDOW_COPY::clin
                        sta ULWR_dest+1
                        lda #1
                        sta ULWR_destsize
                        bra ULW_worker_cleardestline

ULW_worker_inschar:
                        ; Check that character is printable
                        ldx gREG::r0L
                        ldy gREG::r0H
                        lda gREG::r1L
                        jsr ul_isprint
                        bcc exit

                        ; Make sure we are onscreen
                        lda ULW_WINDOW_COPY::ncol
                        dec
                        cmp ULW_WINDOW_COPY::ccol
                        beq :+
                        bcc exit

                        ; Shift right one character
                        ldx #$EA ; NOP
                        ldy #$1A ; INC
                        jsr ULW_worker_moverestofline

                        ; And put character at cursor
                        lda get_handle+1
:                       jsr ulwin_putchar
exitbounce:             bra exit

; ulwin_delchar - Delete a character at current cursor position
;   In: A               - Window handle
.proc ulwin_delchar
                        phx
                        ldx #ULW_wrkidx_delchar
                        bra ULW_docursorthing
.endproc

; ulwin_delline - Delete a line at current cursor position
;   In: A               - Window handle
.proc ulwin_delline
                        phx
                        ldx #ULW_wrkidx_delline
                        bra ULW_docursorthing
.endproc

; ulwin_eraseeol - Erase from the current cursor position to the end of the line
;   In: A               - Window handle
.proc ulwin_eraseeol
                        phx
                        ldx #ULW_wrkidx_eraseeol
                        bra ULW_docursorthing
.endproc

; ulwin_getchar - Get character at current cursor position
;   In: A               - Window handle
;  Out: r0/r1L          - Unicode character at cursor position
.proc ulwin_getchar
                        phx
                        ldx #ULW_wrkidx_getchar
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_docursorthing helper for cursor-related window functions
ULW_docursorthing:
                        ; Save X/Y/RAM bank
                        sta get_handle+1
                        lda BANKSEL::RAM
                        pha
                        phy

                        ; Access the window structure
get_handle:             lda #$00
                        phx
                        jsr ULW_getwinstruct
                        plx

                        ; Call the worker
call_worker:            jmp (ULW_workers,x)

; ulwin_inschar - Insert character at current cursor position
;   In: A               - Window handle
;       r0/r1L          - Unicode character to write
.proc ulwin_inschar
                        phx
                        ldx #ULW_wrkidx_inschar
                        bra ULW_docursorthing
.endproc

; ulwin_insline - Insert a line at current character position
;   In: A               - Window handle
.proc ulwin_insline
                        phx
                        ldx #ULW_wrkidx_insline
                        bra ULW_docursorthing
.endproc

ULW_worker_eraseeol:
                        ; See if we have anything to erase
                        lda ULW_WINDOW_COPY::ncol
                        sec
                        sbc ULW_WINDOW_COPY::ccol
                        bcc exit

                        ; Setup the rect/color
                        sta ULWR_destsize
                        lda ULW_WINDOW_COPY::ccol
                        sta ULWR_dest
                        lda ULW_WINDOW_COPY::clin
                        sta ULWR_dest+1

ULW_worker_cleardestline:
                        lda #1
                        sta ULWR_destsize+1
                        lda ULW_WINDOW_COPY::color
                        sta ULWR_color

                        ; And clear it
                        jsr ULW_clearrect

ULW_worker_getchar:

                        ; Exit
exit:                   ply
                        pla
                        sta BANKSEL::RAM
                        lda get_handle+1
                        plx
                        rts

ULW_worker_insline:
                        ; Shift down one line
                        ldx #$EA ; NOP
                        ldy #$1A ; INC
                        jsr ULW_worker_scrollbelow

                        ; And clear current line
                        lda ULW_WINDOW_COPY::clin
                        bra ULW_worker_clearline

ULW_worker_delline:
                        ; Shift up one line
                        ldx #$1A ; INC
                        ldy #$3A ; DEC
                        jsr ULW_worker_scrollbelow

                        ; And clear last line
                        lda ULW_WINDOW_COPY::nlin
                        dec

ULW_worker_clearline:
                        sta ULWR_dest+1
                        stz ULWR_dest
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWR_destsize
                        bra ULW_worker_cleardestline

ULW_worker_scrollbelow:
                        lda ULW_WINDOW_COPY::nlin
                        dec
                        cmp ULW_WINDOW_COPY::clin
                        bne :+
                        rts

:                       stx ULW_scroll_srcnopinc
                        sty ULW_scroll_destincdec
                        lda ULW_WINDOW_COPY::clin
ULW_scroll_srcnopinc:   inc
                        sta ULWR_src+1
ULW_scroll_destincdec:  inc
                        sta ULWR_dest+1

                        lda ULW_WINDOW_COPY::nlin
                        clc
                        sbc ULW_WINDOW_COPY::clin
                        sta ULWR_destsize+1

                        stz ULWR_src
                        stz ULWR_dest
                        lda ULW_WINDOW_COPY::ncol
                        sta ULWR_destsize
                        jmp ULW_copyrect

.rodata

ULW_workers:

ULW_wrkent_getchar:     .word   ULW_worker_getchar
ULW_wrkent_inschar:     .word   ULW_worker_inschar
ULW_wrkent_insline:     .word   ULW_worker_insline
ULW_wrkent_delchar:     .word   ULW_worker_delchar
ULW_wrkent_delline:     .word   ULW_worker_delline
ULW_wrkent_eraseeol:    .word   ULW_worker_eraseeol

ULW_wrkidx_getchar = ULW_wrkent_getchar - ULW_workers
ULW_wrkidx_inschar = ULW_wrkent_inschar - ULW_workers
ULW_wrkidx_insline = ULW_wrkent_insline - ULW_workers
ULW_wrkidx_delchar = ULW_wrkent_delchar - ULW_workers
ULW_wrkidx_delline = ULW_wrkent_delline - ULW_workers
ULW_wrkidx_eraseeol = ULW_wrkent_eraseeol - ULW_workers
