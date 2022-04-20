.include "unilib_impl.inc"

.code

; ulwin_open - Open a new window
;   In: r0L             Start column of the inside of the window
;       r0H             Start line of the inside of the window
;       r1L             Number of columns inside the window
;       r1H             Number of lines inside the window
;       r2L             Foreground color
;       r2H             Background color
;       r3/r4L          Pointer to window title (UTF-16; r3 = address, r4L = RAM bank (if needed))
;       r4H             Flags:
;                           0x80 = border
;  Out: A               Window handle ($FF = failure)
.proc ulwin_open
@listptr = gREG::r11
@winhandle = gREG::r12L
                        ; Save bank
                        phx
                        phy
                        lda BANKSEL::RAM
                        pha
                        lda gREG::r5L
                        pha
                        lda gREG::r5H
                        pha

                        ; Validate the parameters we can now
@new_slin = gREG::r0H
@new_nlin = gREG::r1H
@new_elin = gREG::r5H
@new_scol = gREG::r0L
@new_ncol = gREG::r1L
@new_ecol = gREG::r5L
@new_flags = gREG::r4H
@new_fg = gREG::r2L
@new_bg = gREG::r2H
@new_title = gREG::r3

                        ; Calculate the end line/column
                        lda @new_scol
                        clc
                        adc @new_ncol
                        sta @new_ecol
                        lda @new_slin
                        clc
                        adc @new_nlin
                        sta @new_elin

                        ; Have we initialized the screen yet?
                        lda ULW_screen_fptr+2
                        beq @find_empty_slot

                        ; Check that the new window fits on the screen
                        sta BANKSEL::RAM
                        lda @new_slin
                        bit @new_flags
                        bpl :+
                        dec
:                       tay
                        bmi @bad_params
                        lda @new_scol
                        bit @new_flags
                        bpl :+
                        dec
:                       tax
                        bmi @bad_params
                        ldy #ULW_WINDOW::elin
                        lda @new_elin
                        bit @new_flags
                        bpl :+
                        inc
:                       inc
                        cmp (ULW_screen_fptr),y
                        bcs @bad_params
                        ldy #ULW_WINDOW::ecol
                        lda @new_ecol
                        bit @new_flags
                        bpl :+
                        inc
:                       inc
                        cmp (ULW_screen_fptr),y
                        bcs @bad_params

                        ; Find an empty slot for a new window
@find_empty_slot:       stz @winhandle
                        ldx ULW_winlist
                        ldy ULW_winlist+1
@access_next:           jsr ulmem_access
                        stx @listptr
                        sty @listptr+1

                        ; Start at the beginning looking for empty slots (64 slots long, so when y hits 128,
                        ; or -128, we can stop)
                        ldy #0
:                       lda (@listptr),y
                        beq @found_slot
                        iny
                        iny
                        bpl :-

                        ; Failure returns 0
                        lda #ULERR::OUT_OF_RESOURCES
                        .byte $2c
@bad_params:            lda #ULERR::INVALID_PARAMS
                        .byte $2c
@out_of_memory:         lda #ULERR::OUT_OF_MEMORY
                        sta UL_lasterr
                        lda #0
                        jmp @exit

                        ; Found a slot, so see if we can allocate a window structure
@found_slot:            tya
                        ldy #0
                        ldx #.sizeof(ULW_WINDOW)
                        sec ; clear the allocated memory
                        jsr ulmem_alloc
                        bcc @out_of_memory

                        ; Okay, need to save the window structure BRP in the right slot,
                        ; which is at old Y
                        phy
                        tay
                        txa
                        sta (@listptr),y
                        iny
                        pla
                        sta (@listptr),y

                        ; Save the BRP of our window structure while we're building/validating it
                        stx ULW_newwin_brp
                        sta ULW_newwin_brp+1

                        ; Window handle is old Y / 2
                        tya
                        lsr
                        sta ULW_newwin_handle

                        ; Get our window structure into the scratch pointer
                        ldy ULW_newwin_brp+1
                        jsr ulmem_access
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Allocate a buffer for the window contents, should be lines * columns * 3
                        ldx @new_nlin
                        lda #3
                        jsr ulmath_umul8_8
                        lda @new_ncol
                        jsr ulmath_umul8_8
                        clc
                        jsr ulmem_alloc
                        bcs :+
                        lda ULW_newwin_handle
                        jsr ulwin_close
                        bra @out_of_memory

                        ; Initialize the new window structure
:                       tya
                        ldy #ULW_WINDOW::buf_ptr+1
                        sta (ULW_scratch_fptr),y
                        dey
                        txa
                        sta (ULW_scratch_fptr),y
                        lda ULW_newwin_handle
                        sta (ULW_scratch_fptr)
                        ldy #ULW_WINDOW::flags
                        lda @new_flags
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_slin
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_nlin
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_elin
                        sta (ULW_scratch_fptr),y
                        iny
                        iny
                        lda @new_scol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_ncol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_ecol
                        sta (ULW_scratch_fptr),y

                        ; Save the title address/bank
                        ldy #ULW_WINDOW::title_addr
                        lda @new_title
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_title+1
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_title+2
                        sta (ULW_scratch_fptr),y

                        ; Set current window as previous to our new one, and next as null
                        iny
                        lda ULW_current_fptr
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULW_current_fptr+1
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULW_current_fptr+2
                        sta (ULW_scratch_fptr),y

                        ; Then set new window as current and fill in the window map
                        lda ULW_scratch_fptr
                        sta ULW_current_fptr
                        lda ULW_scratch_fptr+1
                        sta ULW_current_fptr+1
                        lda BANKSEL::RAM
                        sta ULW_current_fptr+2
                        lda ULW_newwin_handle
                        sta ULW_current_handle
                        jsr ULW_fill_current_to_map

                        ; Set window colors, clear it, and draw its border
                        ldx @new_fg
                        ldy @new_bg
                        jsr ulwin_putcolor
                        jsr ulwin_clear
                        jsr ulwin_border

                        ; Restore bank and exit (A should already be set)
@exit:                  plx
                        stx gREG::r5H
                        plx
                        stx gREG::r5L
                        plx
                        stx BANKSEL::RAM
                        ply
                        plx
                        rts
.endproc

; ULW_fill_current_to_map - fill the current window rect in the window map
.proc ULW_fill_current_to_map
@flags = gREG::r15H
                        ; Save stuff
                        pha
                        phx
                        phy
                        lda BANKSEL::RAM
                        pha
                        lda ULW_current_fptr+2
                        sta BANKSEL::RAM

                        ; Save the window flags where we can get at them (for the border flag)
                        ldy #ULW_WINDOW::flags
                        lda (ULW_current_fptr),y
                        sta @flags

                        ; Get a pointer to the first line of the window in the window map
                        ldy #ULW_WINDOW::slin
                        lda (ULW_current_fptr),y
                        bit @flags
                        bpl :+
                        dec
:                       ldx #80
                        jsr ulmath_umul8_8
                        clc
                        adc #<(ULW_WINMAP)
                        sta ULW_scratch_fptr
                        txa
                        adc #>(ULW_WINMAP)
                        sta ULW_scratch_fptr+1

                        ; And add in the column
                        ldy #ULW_WINDOW::scol
                        lda (ULW_current_fptr),y
                        bit @flags
                        bpl :+
                        dec
:                       clc
                        adc ULW_scratch_fptr
                        sta ULW_scratch_fptr
                        lda ULW_scratch_fptr+1
                        adc #0
                        sta ULW_scratch_fptr+1

                        ; X is num lines to fill, Y is num columns to fill, A is window handle
                        ldy #ULW_WINDOW::nlin
                        lda (ULW_current_fptr),y
                        dec
                        tax
                        ldy #ULW_WINDOW::ncol
                        lda (ULW_current_fptr),y
                        dec
                        tay
                        bit @flags
                        bpl :+
                        inx
                        inx
                        iny
                        iny
:                       lda (ULW_current_fptr)

                        ; Switch to bank 1
                        pha
                        lda #1
                        sta BANKSEL::RAM
                        pla

                        ; Loop X times to fill lines
@line_loop:             phy

                        ; Loop Y times to fill columns
@column_loop:           sta (ULW_scratch_fptr),y
                        dey
                        bpl @column_loop

                        ; Check if done
                        ply
                        dex
                        bmi @done

                        ; Add one line
                        pha
                        lda ULW_scratch_fptr
                        clc
                        adc #80
                        sta ULW_scratch_fptr
                        lda ULW_scratch_fptr+1
                        adc #0
                        sta ULW_scratch_fptr+1
                        pla
                        bra @line_loop

@done:                  pla
                        sta BANKSEL::RAM
                        ply
                        plx
                        pla
                        rts
.endproc

.bss

ULW_winlist:            .res    2       ; BRP to start block of list of windows

ULW_newwin_brp:         .res    2       ; BRP to new window structure as we're creating it
ULW_newwin_handle:      .res    1       ; Handle of new window
