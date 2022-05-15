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
