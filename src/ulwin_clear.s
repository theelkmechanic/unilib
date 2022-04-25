.include "unilib_impl.inc"

.code

; ulwin_clear - Clear the contents of a window and put the cursor at top left
;   In: A               - Handle of window to clear
.proc ulwin_clear
                        ; Save A/X/Y/bank
                        pha
                        phx
                        phy
                        ldy BANKSEL::RAM
                        phy

                        ; Access the window structure
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Call the internal helper
                        jsr ULW_clear

                        ; Restore A/X/Y/bank
                        ply
                        sty BANKSEL::RAM
                        ply
                        plx
                        pla
.endproc
a_nearby_rts:           rts

.proc ULW_clear
@winbuf = gREG::r11
@linelen = gREG::r12L
@linestride = gREG::r12H
@linecount = gREG::r13L
                        ; Copy the window structure
                        jsr ULW_copywinstruct

                        ; Put the cursor at 0,0
                        ldx #0
                        ldy #0
                        jsr ULW_putcursor

                        ; Need to clear the window contents, so access the window buffer
                        ldx ULW_WINDOW_COPY::buf_ptr
                        ldy ULW_WINDOW_COPY::buf_ptr+1
                        jsr ULM_access
                        stx @winbuf
                        sty @winbuf+1

                        ; Our line length is ncol*3, and so is our stride
                        lda ULW_WINDOW_COPY::ncol
                        ldx #3
                        jsr ulmath_umul8_8 ; The most this can be is 240, so we can ignore the high byte
                        stx @linelen
                        stx @linestride

                        ; If we have a border, we need to add @linelen+3 to the buffer start, and the stride becomes
                        ; linelen+6
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        txa
                        inc ;add 3
                        inc
                        sec
                        adc @winbuf
                        sta @winbuf
                        lda @winbuf+1
                        adc #0
                        sta @winbuf+1
                        lda @linelen
                        clc
                        adc #6
                        sta @linestride

                        ; Need to fill nlin lines with our space/NUL/color pattern
:                       lda ULW_WINDOW_COPY::nlin
                        sta @linecount

                        ; Write our space/NUL/color pattern ncol times
:                       ldy #0
:                       lda #' '
                        sta (@winbuf),y
                        iny
                        lda #0
                        sta (@winbuf),y
                        iny
                        lda ULW_WINDOW_COPY::color
                        sta (@winbuf),y
                        iny
                        cpy @linelen
                        bcc :-

                        ; Advance to the next line
                        lda @winbuf
                        clc
                        adc @linestride
                        sta @winbuf
                        lda @winbuf+1
                        adc #0
                        sta @winbuf+1
                        dec @linecount
                        bne :--

                        ; Okay, window backbuffer is cleared; check occlusion, if the window is:
                        ;   - visible, we can clear it in the backbuffer immediately
                        ;   - occluded, we mark the visible portions of the content area as dirty
                        ;   - covered, we don't need to do anything
                        lda #$01
                        bit ULW_WINDOW_COPY::flags
                        bne a_nearby_rts
                        bvs @occluded

                        ; The window is visible, so we can clear it immediately in the backbuffer
                        lda ULW_WINDOW_COPY::scol
                        sta ULVR_destpos
                        lda ULW_WINDOW_COPY::slin
                        sta ULVR_destpos+1
                        lda ULW_WINDOW_COPY::ncol
                        sta ULVR_size
                        lda ULW_WINDOW_COPY::nlin
                        sta ULVR_size+1
                        lda ULW_WINDOW_COPY::color
                        sta ULVR_color
                        jmp ULV_clearrect

                        ; The window is occluded, so we need to walk the window map and mark any blocks in the content area
                        ; for this window as dirty
@occluded:              jmp ULW_set_dirty_rect
.endproc
