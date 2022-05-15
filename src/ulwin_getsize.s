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
