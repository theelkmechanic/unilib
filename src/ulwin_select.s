; ulwin_select - Bring a window to the top (make it the current window)

.include "unilib_impl.inc"

UL_CODE

; ulwin_select - Bring a window to the top
;   In: A               - Window handle to select
.proc ulwin_select
                        ; Don't select the screen window
                        cmp #0
                        beq @early_exit

                        ; If already current, nothing to do
                        cmp ULW_current_handle
                        bne :+
@early_exit:            rts
:
                        ; Save handle/bank/X/Y
                        sta ULWSE_handle
                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Get the window structure to work with
                        lda ULWSE_handle
                        jsr ULW_getwinstruct

                        ; Step 1: Unlink from current position in the doubly-linked list
                        ; If we have a previous window, update its next to point to our next
                        lda ULWC_prev_handle
                        bmi @no_prev
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        ldy #ULW_WINDOW::next_handle
                        lda ULWC_next_handle
                        sta (ULW_scratch_fptr),y

@no_prev:               ; If we have a next window, update its previous to point to our previous
                        lda ULWC_next_handle
                        bmi @no_next
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        ldy #ULW_WINDOW::prev_handle
                        lda ULWC_prev_handle
                        sta (ULW_scratch_fptr),y

                        ; Step 2: Insert at the front (make current)
                        ; Our previous becomes the old current window
@no_next:               lda ULWSE_handle
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Set our next to $FF (no next - we're the top)
                        ldy #ULW_WINDOW::next_handle
                        lda #$FF
                        sta (ULW_scratch_fptr),y

                        ; Set our previous to the old current window
                        ldy #ULW_WINDOW::prev_handle
                        lda ULW_current_handle
                        sta (ULW_scratch_fptr),y

                        ; Update old current's next to point to us
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        ldy #ULW_WINDOW::next_handle
                        lda ULWSE_handle
                        sta (ULW_scratch_fptr),y

                        ; We're the new current window
                        sta ULW_current_handle

                        ; Step 3: Update occlusion map
                        jsr ULW_update_occlusion

                        ; Step 4: Mark the window region as dirty so it gets redrawn
                        lda ULWSE_handle
                        jsr ULW_getwinstruct
                        lda ULWC_scol
                        sta ULWR_dest
                        ldx ULWC_slin
                        ldy ULWC_ncol
                        lda ULWC_nlin
                        bit ULWC_flags
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

                        ; Restore X/Y/bank
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        lda ULWSE_handle
@done:                  rts
.endproc

UL_BSS

ULWSE_handle:           .res 1
