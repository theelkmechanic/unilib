.include "unilib_impl.inc"

.code

; ulwin_open - Open a new window
;   In: r0L             Start column of the inside of the window
;       r0H             Start line of the inside of the window
;       r1L             Number of columns inside the window
;       r1H             Number of lines inside the window
;       r2L             Foreground color
;       r2H             Background color
;       r3              Window title string
;       r4H             Flags:
;                           0x80 = border
;  Out: A               Window handle ($FF = failure)
.proc ulwin_open
@listptr = gREG::r11
@winhandle = gREG::r12L
                        ; Save X/Y/bank/r5
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
                        lda @new_elin
                        bit @new_flags
                        bmi :+
                        dec
:                       cmp ULW_screen_size+1
                        bcs @bad_params
                        lda @new_ecol
                        bit @new_flags
                        bmi :+
                        dec
:                       cmp ULW_screen_size
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
                        sty ULW_scratch_fptr+2
                        jsr ulmem_access
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1

                        ; Allocate a buffer for the window colors, should be lines * columns
                        ; (add 2 to lines and columns if there's a border), and for the window
                        ; characters, which should be colors buffer size * 3
                        ldx @new_nlin
                        lda @new_ncol
                        bit @new_flags
                        bpl :+
                        inx
                        inx
                        inc
                        inc
:                       jsr ulmath_umul8_8
                        phx
                        phy
                        clc
                        jsr ulmem_alloc
                        bcs :++
                        pla
                        pla
:                       lda ULW_newwin_handle
                        jsr ulwin_close
                        bra @out_of_memory
:                       tya
                        ldy #ULW_WINDOW::colorbuf+1
                        sta (ULW_scratch_fptr),y
                        dey
                        txa
                        sta (ULW_scratch_fptr),y
                        ply
                        plx
                        lda #3
                        jsr ulmath_umul16_8
                        clc
                        jsr ulmem_alloc
                        bcc :--
                        tya
                        ldy #ULW_WINDOW::charbuf+1
                        sta (ULW_scratch_fptr),y
                        dey
                        txa
                        sta (ULW_scratch_fptr),y

                        ; Initialize the new window structure
                        lda ULW_newwin_handle
                        sta (ULW_scratch_fptr)
                        ldy #ULW_WINDOW::flags
                        lda @new_flags
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_scol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_slin
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_ncol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_nlin
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_ecol
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_elin
                        sta (ULW_scratch_fptr),y

                        ; Save the title string
                        ldy #ULW_WINDOW::title
                        lda @new_title
                        sta (ULW_scratch_fptr),y
                        iny
                        lda @new_title+1
                        sta (ULW_scratch_fptr),y

                        ; Set current window as previous to our new one
                        iny
                        lda ULW_current_fptr
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULW_current_fptr+1
                        sta (ULW_scratch_fptr),y
                        iny
                        lda ULW_current_fptr+2
                        sta (ULW_scratch_fptr),y

                        ; And set new window as next to our current one (if there is a current one)
                        lda ULW_current_fptr+2
                        beq :+
                        sta BANKSEL::RAM
                        iny
                        iny
                        lda ULW_scratch_fptr
                        sta (ULW_current_fptr),y
                        iny
                        lda ULW_scratch_fptr+1
                        sta (ULW_current_fptr),y
                        iny
                        lda ULW_scratch_fptr+2
                        sta (ULW_current_fptr),y

                        ; Then set new window as current (and as screen if it's the first),
                        ; and fill in the window map
:                       jsr ULW_scratchtocurrent
                        ldx ULW_screen_fptr+2
                        bne :+
                        ldx ULW_scratch_fptr+2
                        stx ULW_screen_fptr+2
                        ldx ULW_scratch_fptr+1
                        stx ULW_screen_fptr+1
                        ldx ULW_scratch_fptr
                        stx ULW_screen_fptr
                        sta ULW_screen_handle
:                       sta ULW_current_handle
                        jsr ULW_update_occlusion

                        ; Set window colors, clear it, and draw its border
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        ldx @new_fg
                        ldy @new_bg
                        jsr ULW_putcolor
                        jsr ULW_clear
                        jsr ULW_drawborder
                        lda ULW_current_handle

                        ; Restore X/Y/bank/r5 and exit (A should already be set)
@exit:                  plx
                        stx gREG::r5H
                        plx
                        stx gREG::r5L
                        plx
                        stx BANKSEL::RAM
                        ply
                        plx
                        and #$ff
                        rts
.endproc

.bss

ULW_winlist:            .res    2       ; BRP to start block of list of windows

ULW_newwin_brp:         .res    2       ; BRP to new window structure as we're creating it
ULW_newwin_handle:      .res    1       ; Handle of new window
