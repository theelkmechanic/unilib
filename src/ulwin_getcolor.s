; ulwin_getcolor - Get window current foreground/background colors

.include "unilib_impl.inc"

UL_CODE

; ulwin_getcolor - Get color being used for output
;   In: A               - Window handle
;  Out: X               - Foreground color (low nibble)
;       Y               - Background color (high nibble)
.proc ulwin_getcolor
                        ; Save bank
                        pha
                        lda BANKSEL::RAM
                        pha

                        ; Get the window structure pointer
                        tsx
                        lda $102,x              ; get A (window handle) from stack
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Read color byte
                        ldy #ULW_WINDOW::color
                        lda (ULW_scratch_fptr),y

                        ; Split nibbles: X = low (fg), Y = high (bg)
                        pha
                        and #$0F
                        tax
                        pla
                        lsr
                        lsr
                        lsr
                        lsr
                        tay

                        ; Restore bank and A
                        pla
                        sta BANKSEL::RAM
                        pla
                        rts
.endproc
