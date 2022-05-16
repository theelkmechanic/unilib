.include "unilib_impl.inc"

.code

; ulwin_close - Close a window
;   In: A               - Window handle
.proc ulwin_close
                        ; Don't let them close the screen
                        and #$ff
                        bne :+
                        rts

                        ; Save A/X/Y/RAM bank
:                       sta ULW_WINDOW_COPY::handle
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Get a copy of the window structure to work with
                        lda ULW_WINDOW_COPY::handle
                        jsr ULW_getwinstruct

                        ; Mark the window region as dirty so it will get redrawn at the next refresh
                        lda ULW_WINDOW_COPY::scol
                        sta ULWR_dest
                        ldx ULW_WINDOW_COPY::slin
                        ldy ULW_WINDOW_COPY::ncol
                        lda ULW_WINDOW_COPY::nlin
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        dec ULWR_dest
                        dex
                        iny
                        iny
                        inc
                        inc
:                       stx ULWR_dest+1
                        sty ULWR_destsize
                        sta ULWR_destsize+1
                        jsr ULW_set_dirty_rect

                        ; Get the window entry pointer and remove it from the list
                        lda ULW_WINDOW_COPY::handle
                        jsr ULW_getwinentryptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        ldy #1
                        lda (ULW_scratch_fptr)
                        tax
                        lda (ULW_scratch_fptr),y
                        pha
                        lda #0
                        sta (ULW_scratch_fptr),y
                        sta (ULW_scratch_fptr)

                        ; Access the window structure
                        ply
                        phy
                        phx
                        jsr ulmem_access
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Free the backbuffers
                        ldy #ULW_WINDOW::charbuf
                        lda (ULW_scratch_fptr),y
                        tax
                        iny
                        lda (ULW_scratch_fptr),y
                        tay
                        jsr ulmem_free
                        ldy #ULW_WINDOW::colorbuf
                        lda (ULW_scratch_fptr),y
                        tax
                        iny
                        lda (ULW_scratch_fptr),y
                        tay
                        jsr ulmem_free

                        ; And free the window structure
                        plx
                        ply
                        jsr ulmem_free

                        ; Our next goes in the previous window's next (there will always be a previous window
                        ; because you can't close or select the screen, so it's always at the bottom)
                        lda ULW_WINDOW_COPY::prev_addr
                        sta ULW_scratch_fptr
                        lda ULW_WINDOW_COPY::prev_addr+1
                        sta ULW_scratch_fptr+1
                        lda ULW_WINDOW_COPY::prev_bank
                        sta ULW_scratch_fptr+2
                        sta BANKSEL::RAM
                        ldy #ULW_WINDOW::next_addr
                        lda ULW_WINDOW_COPY::next_addr
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULW_WINDOW_COPY::next_addr+1
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULW_WINDOW_COPY::next_bank
                        sta (ULW_scratch_fptr),y

                        ; And if next was empty, we must be the current window
                        bne @setnextsprevious
                        jsr ULW_scratchtocurrent
                        bra @updateocclusion

                        ; If it wasn't empty, we need to put our previous into the next window's previous
@setnextsprevious:      lda ULW_WINDOW_COPY::next_addr
                        sta ULW_scratch_fptr
                        lda ULW_WINDOW_COPY::next_addr+1
                        sta ULW_scratch_fptr+1
                        lda ULW_WINDOW_COPY::next_bank
                        sta ULW_scratch_fptr+2
                        sta BANKSEL::RAM
                        ldy #ULW_WINDOW::prev_addr
                        lda ULW_WINDOW_COPY::prev_addr
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULW_WINDOW_COPY::prev_addr+1
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULW_WINDOW_COPY::prev_bank
                        sta (ULW_scratch_fptr),y

                        ; Update the window map and occlusion flags to remove the closed window
@updateocclusion:       jsr ULW_update_occlusion

                        ;Restore A/X/Y/RAM bank
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULW_WINDOW_COPY::handle
@nope:                  rts
.endproc
