.include "unilib_impl.inc"

.code

; ulwin_getloc - Get the location of a given window
;   In: A               - Window handle
;  Out: X               - Start column
;       Y               - Start line
.proc ulwin_getloc
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

; ULW_getloc - Internal get location helper
;   In: BANKSEL::RAM/ULW_scratch_fptr - pointer to window structure
;  Out: X               - Start column
;       Y               - Start line
.proc ULW_getloc
                        ; Start column
                        pha
                        ldy #ULW_WINDOW::scol
                        lda (ULW_scratch_fptr),y
                        tax

                        ; Start line
                        ldy #ULW_WINDOW::slin
                        lda (ULW_scratch_fptr),y
                        tay
                        pla
                        rts
.endproc
