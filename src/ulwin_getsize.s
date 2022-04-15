.include "unilib_impl.inc"

.code

; ulwin_getsize - Get the size of a given window
;   In: A               - Window handle
;  Out: X               - Number of columns
;       Y               - Number of lines
.proc ulwin_getsize
                        ; Save the handle and bank
                        pha
                        ldx BANKSEL::RAM
                        phx

                        ; Get the window structure address
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Get the size
                        jsr ULW_getsize

                        ; Restore and exit
                        pla
                        sta BANKSEL::RAM
                        pla
                        rts
.endproc

; ULW_getsize - Internal get size helper
;   In: BANKSEL::RAM/ULW_scratch_fptr - pointer to window structure
;  Out: X               - Number of columns
;       Y               - Number of lines
.proc ULW_getsize
                        ; Number of columns
                        pha
                        ldy #ULW_WINDOW::ncol
                        lda (ULW_scratch_fptr),y
                        tax

                        ; Number of lines
                        ldy #ULW_WINDOW::nlin
                        lda (ULW_scratch_fptr),y
                        tay
                        pla
                        rts
.endproc
