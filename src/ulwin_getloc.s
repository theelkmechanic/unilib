; ulwin_getloc/ulwin_getstr - Get window content as string

.include "unilib_impl.inc"

UL_CODE

; ulwin_getstr - Return remainder of line at current cursor position as string
;   In: A               - Window handle
;  Out: YX              - String handle, carry set on error
.proc ulwin_getstr
                        ; Get cursor position for the window
                        phx
                        phy
                        pha
                        jsr ulwin_getcursor
                        stx ULWGL_col
                        sty ULWGL_line
                        pla
                        ply
                        plx
                        bra ULW_getloc_impl
.endproc

; ulwin_getloc - Return remainder of line at specified position as string
;   In: A               - Window handle
;       X               - Column
;       Y               - Line
;  Out: YX              - String handle, carry set on error
.proc ulwin_getloc
                        ; Save X/Y position for later
                        stx ULWGL_col
                        sty ULWGL_line
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

.proc ULW_getloc_impl
                        ; Save A/X/Y/bank
                        sta ULWGL_handle
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Access the window structure
                        lda ULWGL_handle
                        jsr ULW_getwinstruct

                        ; Get character buffer pointer at the specified position
                        ldx ULWGL_col
                        ldy ULWGL_line
                        clc                     ; character buffer
                        jsr ULW_getwinbufptr
                        stx UL_src_fptr
                        sty UL_src_fptr+1

                        ; Calculate number of characters from column to end of line
                        lda ULW_WINDOW_COPY::ncol
                        sec
                        sbc ULWGL_col
                        bcc @empty
                        beq @empty
                        sta ULWGL_count

                        ; Read each 3-byte character and encode as UTF-8 into SCRATCH2
                        stz ULWGL_outidx
                        ldy #0

@read_loop:             ; Read 3-byte character from buffer
                        lda (UL_src_fptr),y
                        sta ULWGL_cp_lo
                        iny
                        lda (UL_src_fptr),y
                        sta ULWGL_cp_hi
                        iny
                        lda (UL_src_fptr),y
                        sta ULWGL_cp_extra
                        iny
                        sty ULWGL_bufidx

                        ; Skip null characters (empty cells)
                        lda ULWGL_cp_lo
                        ora ULWGL_cp_hi
                        ora ULWGL_cp_extra
                        beq @next_char

                        ; Check output overflow
                        lda ULWGL_outidx
                        cmp #248
                        bcs @done

                        ; Encode codepoint as UTF-8 via helper
                        jsr ULW_encode_utf8

@next_char:             ldy ULWGL_bufidx
                        dec ULWGL_count
                        bne @read_loop

@done:                  ; NUL-terminate and create string
                        ldy ULWGL_outidx
                        lda #0
                        sta UL_SCRATCH2_BASE,y

                        ; Restore bank and create string from UTF-8
                        ply                     ; discard saved Y
                        plx                     ; discard saved X
                        pla
                        sta BANKSEL::RAM

                        ldx #<UL_SCRATCH2_BASE
                        ldy #>UL_SCRATCH2_BASE
                        jmp ulstr_fromUtf8

@empty:                 ; Return empty string
                        stz ULWGL_outidx
                        bra @done
.endproc

; ULW_encode_utf8 - Encode a codepoint from ULWGL vars as UTF-8 into SCRATCH2
.proc ULW_encode_utf8
                        lda ULWGL_cp_extra
                        beq :+
                        jmp @four_byte
:
                        lda ULWGL_cp_hi
                        beq :+
                        jmp @multi_byte
:

                        ; hi = 0: codepoint $0001-$00FF
                        lda ULWGL_cp_lo
                        bmi @two_byte_00xx

                        ; 1-byte UTF-8 ($01-$7F)
                        ldy ULWGL_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULWGL_outidx
                        rts

@two_byte_00xx:         ; Codepoint $0080-$00FF
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$C0
                        ldy ULWGL_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        pla
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULWGL_outidx
                        rts

@multi_byte:            cmp #$08
                        bcs @three_byte

                        ; 2-byte UTF-8 ($0100-$07FF)
                        asl
                        asl
                        sta ULWGL_temp
                        lda ULWGL_cp_lo
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULWGL_temp
                        ora #$C0
                        ldy ULWGL_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        pla
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULWGL_outidx
                        rts

@three_byte:            ; 3-byte UTF-8 ($0800-$FFFF)
                        lda ULWGL_cp_hi
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$E0
                        ldy ULWGL_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        lda ULWGL_cp_hi
                        and #$0F
                        asl
                        asl
                        sta ULWGL_temp
                        lda ULWGL_cp_lo
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULWGL_temp
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        lda ULWGL_cp_lo
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULWGL_outidx
                        rts

@four_byte:             ; 4-byte UTF-8 ($10000+)
                        lda ULWGL_cp_extra
                        lsr
                        lsr
                        ora #$F0
                        ldy ULWGL_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        lda ULWGL_cp_extra
                        and #$03
                        asl
                        asl
                        asl
                        asl
                        sta ULWGL_temp
                        lda ULWGL_cp_hi
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULWGL_temp
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        lda ULWGL_cp_hi
                        and #$0F
                        asl
                        asl
                        sta ULWGL_temp
                        lda ULWGL_cp_lo
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULWGL_temp
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        lda ULWGL_cp_lo
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULWGL_outidx
                        rts
.endproc

UL_BSS

ULWGL_handle:           .res 1
ULWGL_col:              .res 1
ULWGL_line:             .res 1
ULWGL_count:            .res 1
ULWGL_outidx:           .res 1
ULWGL_bufidx:           .res 1
ULWGL_cp_lo:            .res 1
ULWGL_cp_hi:            .res 1
ULWGL_cp_extra:         .res 1
ULWGL_temp:             .res 1
