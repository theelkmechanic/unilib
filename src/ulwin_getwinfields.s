.include "unilib_impl.inc"

.code

; ulwin_getcursor - Get the location of a given window's cursor
;   In: A               - Window handle
;  Out: X               - Cursor column
;       Y               - Cursor line
.proc ulwin_getcursor
                        ldy #<ULW_getcursor
                        sty getfields_call+1
                        ldy #>ULW_getcursor
                        sty getfields_call+2
                        bra ULW_getwinfields
.endproc

; ulwin_getsize - Get the size of a given window
;   In: A               - Window handle
;  Out: X               - Number of columns
;       Y               - Number of lines
.proc ulwin_getsize
                        ldy #<ULW_getsize
                        sty getfields_call+1
                        ldy #>ULW_getsize
                        sty getfields_call+2
                        bra ULW_getwinfields
.endproc

; ulwin_getpos - Get the location of a given window
;   In: A               - Window handle
;  Out: X               - Start column
;       Y               - Start line
.proc ulwin_getpos
                        ldy #<ULW_getpos
                        sty getfields_call+1
                        ldy #>ULW_getpos
                        sty getfields_call+2
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_getwinfields - Get the desired fields into X/Y
ULW_getwinfields:
                        ; Save the handle and bank
                        pha
                        ldx BANKSEL::RAM
                        phx

                        ; Get the window structure address
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Get the fields
getfields_call:         jsr $FFFF

                        ; Restore and exit
                        pla
                        sta BANKSEL::RAM
                        pla
                        rts

; ulwin_getline - Get the current cursor line
;   In: A               - Window handle
;  Out: A               - Window cursor line
.proc ulwin_getline
                        ; Save Y and retrieve cursor line
                        phy
                        ldy #ULW_WINDOW::clin
                        bra ULW_getlc
.endproc

; ulwin_getcolumn - Get the current cursor column
;   In: A               - Window handle
;  Out: A               - Window cursor column
.proc ulwin_getcolumn
                        ; Save Y and retrieve cursor column
                        phy
                        ldy #ULW_WINDOW::ccol
.endproc

; FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

ULW_getlc:
                        ; Save handle/bank/X
                        phx
                        ldx BANKSEL::RAM
                        phx

                        ; Get the window structure address
                        phy
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Read value
                        ply
                        lda (ULW_scratch_fptr),y

                        ; Restore X/bank/Y, result in A
                        plx
                        stx BANKSEL::RAM
                        plx
                        ply
                        rts
