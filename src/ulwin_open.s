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
                        ldx BANKSEL::RAM
                        phx

                        ; Validate the parameters we can now
@new_slin = gREG::r0H
@new_nlin = gREG::r1H
@new_elin = gREG::r15H
@new_scol = gREG::r0L
@new_ncol = gREG::r1L
@new_ecol = gREG::r15L
@new_flags = gREG::r4H
@border = gREG::r12H
@new_fg = gREG::r2L
@new_bg = gREG::r2H
@new_title = gREG::r3

                        ; Border is the only flag we have right now, so turn the 0x80 into a 1 if it's there
                        lda @new_flags
                        stz @border
                        asl
                        rol @border

                        ; Check that the window isn't off the top or left of the screen
                        lda @new_slin
                        sec
                        sbc @border
                        bmi @bad_params
                        lda @new_scol
                        sec
                        sbc @border
                        bmi @bad_params

                        ; Calculate the end line/column
                        lda @new_scol
                        clc
                        adc @new_ncol
                        sta @new_ecol
                        lda @new_slin
                        clc
                        adc @new_nlin
                        sta @new_elin

                        ; Find an empty slot for a new window
                        stz @winhandle
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
                        tya
                        ldy #ULW_WINDOW::buf_ptr+1
                        sta (ULW_scratch_fptr),y
                        dey
                        txa
                        sta (ULW_scratch_fptr),y

                        ; Have we initialized the screen yet?
                        lda ULW_screen_fptr+2
                        beq @init_new_window

                        ; Check that the new window fits on the screen
                        sta BANKSEL::RAM
                        ldy #ULW_WINDOW::nlin
                        lda @new_elin
                        clc
                        adc @border
                        dec
                        cmp (ULW_screen_fptr),y
                        bcs :+
                        ldy #ULW_WINDOW::ncol
                        lda @new_ecol
                        clc
                        adc @border
                        dec
                        cmp (ULW_screen_fptr),y
                        bcc @init_new_window

                        ; Window is offscreen, so free it (ulwin_close will work) and fail
:                       lda ULW_newwin_handle
                        jsr ulwin_close
                        bra @bad_params

                        ; Initialize the new window structure
@init_new_window:       ldx ULW_newwin_brp
                        ldy ULW_newwin_brp+1
                        jsr ulmem_access
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
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
                        lda #0
                        sta (ULW_scratch_fptr),y ; Cursor line
                        iny
                        lda @new_scol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_ncol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_ecol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda #0
                        sta (ULW_scratch_fptr),y ; Cursor column

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
                        iny
                        lda #0
                        sta (ULW_scratch_fptr),y
                        iny
                        sta (ULW_scratch_fptr),y
                        iny
                        sta (ULW_scratch_fptr),y

                        ; Then set new window as current
                        lda ULW_scratch_fptr
                        sta ULW_current_fptr
                        lda ULW_scratch_fptr+1
                        sta ULW_current_fptr+1
                        lda BANKSEL::RAM
                        sta ULW_current_fptr+2

                        ; Set window colors, clear it, and draw its border
                        lda ULW_newwin_handle
                        sta ULW_current_handle
                        ldx @new_fg
                        ldy @new_bg
                        jsr ulwin_putcolor
                        jsr ulwin_clear
                        jsr ulwin_border

                        ; Restore bank and exit (A should already be set)
@exit:                  plx
                        stx BANKSEL::RAM
                        rts
.endproc

.bss

ULW_winlist:            .res    2       ; BRP to start block of list of windows

ULW_newwin_brp:         .res    2       ; BRP to new window structure as we're creating it
ULW_newwin_handle:      .res    1       ; Handle of new window
