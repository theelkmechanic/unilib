; ULW_utils - Window utility functions

.include "unilib_impl.inc"

.code

; ULW_scratchtocurrent - Set window at ULW_scratch_fptr into current
;   In: ULW_scratch_fptr - Far pointer to a window structure
;  Out: ULW_current_fptr - Set to value in ULW_scratch_fptr
;       A/ULW_current_handle - Set to handle at (ULW_scratch_fptr)
.proc ULW_scratchtocurrent
                        lda ULW_scratch_fptr+2
                        sta BANKSEL::RAM
                        sta ULW_current_fptr+2
                        lda ULW_scratch_fptr+1
                        sta ULW_current_fptr+1
                        lda ULW_scratch_fptr
                        sta ULW_current_fptr
                        lda (ULW_scratch_fptr)
                        sta ULW_current_handle
                        rts
.endproc

; ULW_getend - Internal get end line/column helper
;   In: BANKSEL::RAM/ULW_scratch_fptr - pointer to window structure
;  Out: X               - End column (start column + number of columns)
;       Y               - End line (start line + number of lines)
.proc ULW_getend
                        ; End column
                        ldy #ULW_WINDOW::ecol
                        .byte $2c ; skip next instruction
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_getcursor - Internal get cursor line/column helper
;   In: BANKSEL::RAM/ULW_scratch_fptr - pointer to window structure
;  Out: X               - Cursor column
;       Y               - Cursor line
.proc ULW_getcursor
                        ; Cursor column
                        ldy #ULW_WINDOW::ccol
                        .byte $2c ; skip next instruction
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_getsize - Internal get size helper
;   In: BANKSEL::RAM/ULW_scratch_fptr - pointer to window structure
;  Out: X               - Number of columns
;       Y               - Number of lines
.proc ULW_getsize
                        ; Number of columns
                        ldy #ULW_WINDOW::ncol
                        .byte $2c ; skip next instruction
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_getpos - Internal get location helper
;   In: BANKSEL::RAM/ULW_scratch_fptr - pointer to window structure
;  Out: X               - Start column
;       Y               - Start line
.proc ULW_getpos
                        ; Start column
                        ldy #ULW_WINDOW::scol
                        pha
                        lda (ULW_scratch_fptr),y
                        tax

                        ; And next value
                        iny
                        lda (ULW_scratch_fptr),y
                        tay
                        pla
                        rts
.endproc

; ULW_putcursor - Internal put cursor line/column helper
;   In: BANKSEL::RAM/ULW_scratch_fptr - pointer to window structure
;       X               - Cursor column
;       Y               - Cursor line
.proc ULW_putcursor
                        ; Set cursor line
                        tya
                        ldy #ULW_WINDOW::clin
ULW_putpair:            sta (ULW_scratch_fptr),y

                        ; And set previous entry
                        txa
                        dey
                        sta (ULW_scratch_fptr),y
                        rts
.endproc

; ULW_getwinstruct - access window structure and copy to known location
;   In: A               - Window handle
;  Out: ULW_scratch_ptr - Pointer to actual window structure
;       BANKSEL::RAM    - Bank of actual window structure
;       ULW_WINDOW_COPY - Copy of window structure contents
.proc ULW_getwinstruct
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        sta ULW_scratch_fptr+2
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_copywinstruct - copy window structure to known location 
;   In: ULW_scratch_ptr - Pointer to actual window structure
;       BANKSEL::RAM    - Bank of actual window structure
;  Out: ULW_WINDOW_COPY - Copy of window structure contents
.proc ULW_copywinstruct
                        ldy #.sizeof(ULW_WINDOW)-1
:                       lda (ULW_scratch_fptr),y
                        sta ULW_WINDOW_COPY::handle,y
                        dey
                        bpl :-
                        rts
.endproc

; ULW_getwinptr - look up the window pointer for a given window handle
;   In: A               Window handle
;  Out: A               Window far pointer bank (WARNING: also leaves in BANKSEL:RAM)
;       YX              Window far pointer address
.proc ULW_getwinptr
                        ; Get a pointer to the window list entry
                        jsr ULW_getwinentryptr

                        ; Got the pointer, now follow the BRP in it
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        lda (ULW_scratch_fptr)
                        tax
                        inc ULW_scratch_fptr
                        lda (ULW_scratch_fptr)
                        tay
                        jsr ulmem_access
                        lda BANKSEL::RAM
                        rts
.endproc

; ULW_getwinentryptr - look up the pointer to the window list entry for a given window handle
;   In: A               Window handle
;  Out: A               Window list entry far pointer bank (WARNING: also leaves in BANKSEL::RAM)
;       YX              Window list entry far pointer address
.proc ULW_getwinentryptr
                        ; Window pointer is zero-based index into the BRP array, max 64 windows
                        asl
                        bcs @bad_handle
                        bmi @bad_handle
                        sta UL_temp_l
                        ldx ULW_winlist
                        ldy ULW_winlist+1
                        jsr ulmem_access
                        txa
                        clc
                        adc UL_temp_l
                        tax
                        tya
                        adc #0
                        tay
                        lda BANKSEL::RAM
                        rts
@bad_handle:            lda #ULERR::INVALID_HANDLE
                        sta UL_lasterr
                        jmp UL_terminate
.endproc

; ULW_intersectsrc - Intersect ULWR_src with the window content area
;   In: ULW_WINDOW_COPY - Window structure
;       ULW_src         - Rectangle to intersect
;  Out: ULW_src         - Updated to intersection rectangle
.proc ULW_intersectsrc
                        ; Store ULW_dest pointer in r11
                        lda #<ULWR_dest
                        sta gREG::r11L
                        lda #>ULWR_dest
                        sta gREG::r11H
                        bra ULW_intersectwindow
.endproc

; ULW_intersectdest - Intersect ULWR_dest with the window content area
;   In: ULW_WINDOW_COPY - Window structure
;       ULW_dest        - Rectangle to intersect
;  Out: ULW_dest        - Updated to intersection rectangle
.proc ULW_intersectdest
                        ; Store ULW_dest pointer in r11
                        lda #<ULWR_dest
                        sta gREG::r11L
                        lda #>ULWR_dest
                        sta gREG::r11H
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

                        ; Store ULW_WINDOW_COPY rect pointer in r12
ULW_intersectwindow:    lda #<ULW_WINDOW_COPY::scol
                        sta gREG::r12L
                        lda #>ULW_WINDOW_COPY::scol
                        sta gREG::r12H

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_intersectrect - Intersect two rectangles
;   In: r11             - Pointer to first rectangle (top/left/height/width)
;       r12             - Pointer to second rectangle (top/left/height/width)
;  Out: (r11)           - Updated to intersection rectangle
.proc ULW_intersectrect
                        ; Convert rectangles to start/end format
                        ldy #2
                        lda (gREG::r11)
                        clc
                        adc (gREG::r11),y
                        dec
                        sta (gREG::r11),y
                        lda (gREG::r12)
                        clc
                        adc (gREG::r12),y
                        dec
                        sta (gREG::r12),y
                        dey
                        lda (gREG::r11),y
                        iny
                        iny
                        clc
                        adc (gREG::r11),y
                        dec
                        sta (gREG::r11),y
                        dey
                        dey
                        lda (gREG::r12),y
                        iny
                        iny
                        clc
                        adc (gREG::r12),y
                        dec
                        
                        ; If we don't sta (gREG::r12),y here, we don't have to restore it later

                        ; Intersection is the max of the mins and the min of the maxes; start with end cols and work backwards
                        ; NOTE: Have to do signed comparisons here or scrolling will break badly
                        pha
                        lda (gREG::r11),y
                        tax
                        pla
                        jsr ulmath_scmp8_8
                        bcs :+
                        sta (gREG::r11),y
:                       dey
                        lda (gREG::r11),y
                        tax
                        lda (gREG::r12),y
                        jsr ulmath_scmp8_8
                        bcs :+
                        sta (gREG::r11),y
:                       dey
                        lda (gREG::r11),y
                        tax
                        lda (gREG::r12),y
                        jsr ulmath_scmp8_8
                        bcc :+
                        sta (gREG::r11),y
:                       dey
                        lda (gREG::r11),y
                        tax
                        lda (gREG::r12),y
                        jsr ulmath_scmp8_8
                        bcc :+
                        sta (gREG::r11),y

                        ; Convert rectangles back to start/size format (never stored r12H so don't need to fix it)
:                       ldy #2
                        lda (gREG::r11),y
                        sec
                        sbc (gREG::r11)
                        inc
                        sta (gREG::r11),y
                        lda (gREG::r12),y
                        sec
                        sbc (gREG::r12)
                        inc
                        sta (gREG::r12),y
                        iny
                        lda (gREG::r11),y
                        dey
                        dey
                        sec
                        sbc (gREG::r11),y
                        inc
                        iny
                        iny
                        sta (gREG::r11),y
                        rts
.endproc

; ULW_getwinbufptr - access the scratch window buffer pointer for a given location in the window (and calculate line length/stride)
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       X                               - Column in window contents
;       Y                               - Line in window contents
;       carry                           - Clear = character buffer, Set = color buffer
;  Out: ULW_winbufptr/BANKSEL::RAM      - Window buffer pointer to line/column
;       ULW_linelen                     - Length of window content line in buffer
;       ULW_linestride                  - Length of full window line in buffer (including border)
.proc ULW_getwinbufptr
                        ; Save the charbuf/colorbuf option for later
                        ror ULW_carryflag

                        ; For a window with no border, line length and stride are both ncol*3 for charbuf and ncol for colorbuf
                        phx
                        phy
                        ldx ULW_WINDOW_COPY::ncol
                        bit ULW_carryflag
                        bmi :+
                        lda #3
                        jsr ulmath_umul8_8 ; The most this can be is 240, so we can ignore the high byte
:                       stx ULW_linelen
                        stx ULW_linestride

                        ; If we have a border, the stride becomes linelen+2*tilewidth (also save offset to correct BRP to access)
                        ldy #0
                        bit ULW_carryflag
                        bpl :+
                        iny
                        iny
:                       lda ULW_WINDOW_COPY::flags
                        bpl :++
                        bit ULW_carryflag
                        bmi :+
                        inx
                        inx
                        inx
                        inx
:                       inx
                        inx
                        stx ULW_linestride

                        ; Access the correct buffer and save the start address
:                       ldx ULW_WINDOW_COPY::charbuf,y
                        lda ULW_WINDOW_COPY::charbuf+1,y
                        tay
                        jsr ulmem_access
                        stx ULW_winbufptr
                        sty ULW_winbufptr+1

                        ; If we have a border, we increment X and Y by 1 to compensate
                        ply
                        plx
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        inx
                        iny

                        ; Now, the offset into the window buffer is (Y*linestride)+X*(3 for charbuf, 1 for colorbuf)
:                       phx
                        tya
                        ldx ULW_linestride
                        jsr ulmath_umul8_8
                        txa
                        clc
                        adc ULW_winbufptr
                        sta ULW_winbufptr
                        tya
                        adc ULW_winbufptr+1
                        sta ULW_winbufptr+1
                        pla
                        beq a_handy_rts
                        ldy #0
                        bit ULW_carryflag
                        bmi :+
                        ldx #3
                        jsr ulmath_umul8_8
                        txa
:                       clc
                        adc ULW_winbufptr
                        sta ULW_winbufptr
                        tya
                        adc ULW_winbufptr+1
                        sta ULW_winbufptr+1

                        ; Take the char/color flag back out of ULW_carryflag
                        rol ULW_carryflag
.endproc
a_handy_rts:            rts

; ULW_clearrect - clear a rectangle in a window with a specific color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Top/left in window contents (L=column, H=line)
;       ULWR_destsize   - Size in window contents (L=columns, H=lines)
;       ULWR_color      - Color (fg=low nibble, bg=high nibble)
.proc ULW_clearrect
                        ; This is just a fillrect with a space
                        lda #' '
                        sta ULWR_char
                        stz ULWR_char+1
                        stz ULWR_char+2
                        bra ULW_fillrect
.endproc

; ULW_drawborder - (re)draw the border/title for the window
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
.proc ULW_drawborder
                        ; Does window have a border?
                        bit ULW_WINDOW_COPY::flags
                        bpl a_handy_rts

                        ; Put a box around it
                        lda ULW_WINDOW_COPY::nlin
                        sta ULW_boxbottom
                        lda ULW_WINDOW_COPY::ncol
                        sta ULW_boxright
                        lda #$ff
                        sta ULW_boxtop
                        sta ULW_boxleft
                        jsr ULW_box

                        ; Is there a window title?
                        lda ULW_WINDOW_COPY::title
                        ora ULW_WINDOW_COPY::title+1
                        beq a_handy_rts

                        ; Draw the window title into the top line using the emphasis color

                        ; First, limit the title length to window width + border - 6 (and make sure at least 1 char can be drawn)
                        lda ULW_WINDOW_COPY::ncol
                        sec
                        sbc #7
                        bmi a_handy_rts ; not enough space to draw any of title
                        inc

                        ; Start with a space at -1,1
                        pha
                        lda #$ff
                        sta ULWR_dest+1
                        inc
                        sta ULWR_char+1
                        sta ULWR_char+2
                        inc
                        sta ULWR_dest
                        lda ULW_WINDOW_COPY::emcolor
                        sta ULWR_color
                        lda #' '
                        sta ULWR_char
                        jsr ULW_drawchar
                        inc ULWR_dest

                        ; Print the title string
                        pla
                        sta ULWR_destsize
                        ldx ULW_WINDOW_COPY::title
                        ldy ULW_WINDOW_COPY::title+1
                        jsr ulstr_access
                        jsr ULW_drawstring
                        clc
                        adc ULWR_dest
                        sta ULWR_dest

                        ; And finish with another space
                        lda #' '
                        sta ULWR_char
                        stz ULWR_char+1
                        stz ULWR_char+2
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_drawchar - draw a UTF-16 character into a window at a specific location in a specific color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Line/column in window contents (L=column, H=line)
;       ULWR_char       - Unicode character
;       ULWR_color      - Color (fg=low nibble, bg=high nibble)
.proc ULW_drawchar
                        ; This is just a fillrect with size 1x1
                        lda #1
                        sta ULWR_destsize
                        sta ULWR_destsize+1
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_fillrect - fill a rectangle in a window with a specific character/color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Top/left in window contents (L=column, H=line)
;       ULWR_destsize   - Size in window contents (L=columns, H=lines)
;       ULWR_char       - UTF-16 character
;       ULWR_color      - Color (fg=low nibble, bg=high nibble)
.proc ULW_fillrect
                        ; Fill the characters, then the colors
                        jsr ULW_fillrect_char
                        jsr ULW_fillrect_color

                        ; Okay, window backbuffer is filled; check occlusion, if the window is:
                        ;   - visible, we can fill it in the screen backbuffer immediately
                        ;   - occluded, we mark the visible portions of the rectangle as dirty
                        ;   - covered, we don't need to do anything
                        bit ULW_WINDOW_COPY::status
                        bmi @done
                        bvs @occluded

                        ; The window is visible, so we can fill the rectangle immediately in the backbuffer
                        lda ULWR_dest
                        clc
                        adc ULW_WINDOW_COPY::scol
                        sta ULVR_destpos
                        lda ULWR_dest+1
                        clc
                        adc ULW_WINDOW_COPY::slin
                        sta ULVR_destpos+1
                        lda ULWR_destsize
                        sta ULVR_size
                        lda ULWR_destsize+1
                        sta ULVR_size+1
                        lda ULWR_color
                        sta ULVR_color
                        ldx ULWR_char
                        ldy ULWR_char+1
                        lda ULWR_char+2
                        jmp ULV_fillrect

                        ; The window is occluded, so we need to walk the window map and mark any blocks in the rectangle
                        ; for this window as dirty
@occluded:              lda ULWR_dest
                        pha
                        clc
                        adc ULW_WINDOW_COPY::scol
                        sta ULWR_dest
                        lda ULWR_dest+1
                        pha
                        clc
                        adc ULW_WINDOW_COPY::slin
                        sta ULWR_dest+1
                        jsr ULW_set_dirty_rect
                        pla
                        sta ULWR_dest+1
                        pla
                        sta ULWR_dest
@done:                  rts
.endproc

; Helper for ULW_fillrect/ULW_colorrect - carry clear to fill character buffer, carry set to fill color buffer
ULW_fillrect_color:
                        ldx ULWR_color
                        lda #$ff
                        bra ULW_fillrect_charorcolor
ULW_fillrect_char:
                        ldx ULWR_char
                        stx charloload+1
                        ldx ULWR_char+1
                        stx charhiload+1
                        ldx ULWR_char+2
                        lda #0
ULW_fillrect_charorcolor:
                        stx lastload+1
                        sta ULW_carryflag

                        ; Get the appropriate buffer at our top left
                        ldx ULWR_dest
                        ldy ULWR_dest+1
                        rol ULW_carryflag
                        jsr ULW_getwinbufptr

                        ; Need to fill nlin lines with our character/color pattern
                        lda ULWR_destsize+1
                        sta ULW_linecount
                        ldx ULWR_destsize
                        bit ULW_carryflag
                        bmi :+
                        lda #3
                        jsr ulmath_umul8_8
:                       stx linefill_cmp+1

                        ; Write our character/color pattern to the line
:                       ldy #0
:                       bit ULW_carryflag
                        bmi lastload
charloload:             lda #$00
                        sta (ULW_winbufptr),y
                        iny
charhiload:             lda #$00
                        sta (ULW_winbufptr),y
                        iny
lastload:               lda #$00
                        sta (ULW_winbufptr),y
                        iny
linefill_cmp:           cpy #$00
                        bcc :-

                        ; Advance to the next line
                        lda ULW_winbufptr
                        clc
                        adc ULW_linestride
                        sta ULW_winbufptr
                        lda ULW_winbufptr+1
                        adc #0
                        sta ULW_winbufptr+1
                        dec ULW_linecount
                        bne :--
                        rts

; ULW_drawstring - draw a string into a window at a specific location in a specific color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Top/left in window contents (L=column, H=line)
;       ULWR_destsize   - Low byte = max length in characters (0 = whole string)
;       ULWR_color      - Color (fg=low nibble, bg=high nibble)
;       ULS_scratch_fptr - String address (must be accessible from current bank)
;  Out: A               - Number of characters drawn
.proc ULW_drawstring
                        ; Get the max length to write (but not more than to the end of our line)
                        lda ULW_WINDOW_COPY::ncol
                        sec
                        sbc ULWR_dest
                        cmp ULWR_destsize
                        bcc :+
                        lda ULWR_destsize
:                       clc
                        adc ULWR_dest
                        sta @lastcol_check+1
                        lda ULWR_dest
                        sta @startcol_sub+1

                        ; Write our string characters/color to the line
:                       jsr ULS_nextchar

                        ; Check for end of string
                        bcs @written

                        ; Try to print the character
                        stx ULWR_char
                        sty ULWR_char+1
                        sta ULWR_char+2
                        jsr ULW_drawchar

                        ; Step ahead one cell if we printed something
                        bcc :-
                        inc ULWR_dest
@lastcol_check:         cmp #$00
                        bcc :-

                        ; Number of characters printed is ULWR_dest-@startcol
@written:               lda ULWR_dest
                        sec
@startcol_sub:          sbc #$00
                        ldx @startcol_sub+1
                        stx ULWR_dest
                        rts
.endproc

; ULW_copyrect - Copy a rectangle within window contents to a new location in the window
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_src        - Top/left of source (L=column, H=line)
;       ULWR_dest       - Top/left of destination (L=column, H=line)
;       ULWR_destsize   - Size of rectangle (L=columns, H=lines)
.proc ULW_copyrect
                        ; Save the src/dest/size for later
                        lda ULWR_src
                        sta ULVR_srcpos
                        lda ULWR_src+1
                        sta ULVR_srcpos+1
                        lda ULWR_dest
                        sta ULVR_destpos
                        lda ULWR_dest+1
                        sta ULVR_destpos+1
                        lda ULWR_destsize
                        sta ULVR_size
                        lda ULWR_destsize+1
                        sta ULVR_size+1

                        ; Moving left or right? (ULW_carryflag:$80 will be set if moving right)
                        lda ULWR_dest
                        cmp ULWR_src
                        ror ULW_carryflag

                        ; Moving up or down? (Store appropriate line advance instructions)
                        lda ULWR_src+1
                        cmp ULWR_dest+1
                        bcs :+

                        ; When moving down, need to start at last line
                        clc
                        adc ULWR_destsize+1
                        dec
                        sta ULWR_src+1
                        lda ULWR_dest+1
                        clc
                        adc ULWR_destsize+1
                        dec
                        sta ULWR_dest+1

                        ; Moving down, so need dec instructions (opcode=$xx)
                        lda #$CE
                        .byte $2c ; skip next instruction

                        ; Moving up, so need inc instructions (opcode=$xx)
:                       lda #$EE
                        sta @stepsrc
                        sta @stepdest

                        ; Loop over lines; copy the character data
@line_loop:             lda ULWR_destsize
                        ldx #3
                        jsr ulmath_umul8_8
                        txa
                        clc
                        ror ULW_carryflag
                        clc
                        ror ULW_carryflag
                        jsr ULW_copylinehelper

                        ; Then copy the color data
                        lda ULWR_destsize
                        sec
                        ror ULW_carryflag
                        sec
                        ror ULW_carryflag
                        jsr ULW_copylinehelper

                        ; Done with one line, was it the last
                        dec ULWR_destsize+1
                        beq @check_occlusion

                        ; Step to next line
@stepsrc:               inc ULWR_src+1
@stepdest:              inc ULWR_dest+1
                        bra @line_loop

                        ; Okay, window backbuffer is filled; restore the input parameters and
                        ; check occlusion, if the window is:
                        ;   - visible, we can copy it in the screen backbuffer immediately
                        ;   - occluded, we mark the visible portions of the destination as dirty
                        ;   - covered, we don't need to do anything
@check_occlusion:       lda ULVR_srcpos
                        sta ULWR_src
                        clc
                        adc ULW_WINDOW_COPY::scol
                        sta ULVR_srcpos
                        lda ULVR_srcpos+1
                        sta ULWR_src+1
                        clc
                        adc ULW_WINDOW_COPY::slin
                        sta ULVR_srcpos+1
                        lda ULVR_destpos
                        sta ULWR_dest
                        clc
                        adc ULW_WINDOW_COPY::scol
                        sta ULVR_destpos
                        lda ULVR_destpos+1
                        sta ULWR_dest+1
                        clc
                        adc ULW_WINDOW_COPY::slin
                        sta ULVR_destpos+1
                        lda ULVR_size
                        sta ULWR_destsize
                        lda ULVR_size+1
                        sta ULWR_destsize+1

                        bit ULW_WINDOW_COPY::status
                        bmi @done
                        bvs @occluded

                        ; The window is visible, so we can copy the rectangle immediately in the backbuffer
                        jmp ULV_copyrect

                        ; The window is occluded, so we need to walk the window map and mark any blocks in the destination
                        ; for this window as dirty
@occluded:              lda ULWR_dest
                        pha
                        lda ULWR_dest+1
                        pha
                        lda ULVR_destpos
                        sta ULWR_dest
                        lda ULVR_destpos+1
                        sta ULWR_dest+1
                        jsr ULW_set_dirty_rect
                        pla
                        sta ULWR_dest+1
                        pla
                        sta ULWR_dest
@done:                  rts
.endproc

; Helper to copy a line of character/color data
;   In: ULW_carryflag   - Bit $C0 set = color data, clear = character data (will get shifted out)
;                         Bit $20 set = move right, clear = move left
;       A               - Bytes to copy
.proc ULW_copylinehelper
                        ; Save bytes to copy
                        sta @lencheck+1
                        sta @moveright+1

                        ; Load source/dest addresses
                        lda ULW_WINDOW_COPY::handle
                        ldx ULWR_src
                        ldy ULWR_src+1
                        rol ULW_carryflag
                        jsr ULW_getwinbufptr
                        lda ULW_winbufptr
                        sta ULW_winsrcptr
                        lda ULW_winbufptr+1
                        sta ULW_winsrcptr+1
                        lda ULW_WINDOW_COPY::handle
                        ldx ULWR_dest
                        ldy ULWR_dest+1
                        rol ULW_carryflag
                        jsr ULW_getwinbufptr

                        ; Are we copying left or right?
                        bit ULW_carryflag
                        bmi @moveright

                        ; Copy left (start 0, done at size)
                        ldy #0
:                       lda (ULW_winsrcptr),y
                        sta (ULW_winbufptr),y
                        iny
@lencheck:              cpy #$00
                        bne :-
                        rts

                        ; Copy right (start size-1, done at -1)
@moveright:             ldy #$00
                        dey
:                       lda (ULW_winsrcptr),y
                        sta (ULW_winbufptr),y
                        dey
                        cpy #$ff
                        bne :-
                        rts
.endproc

.bss

ULW_linecount:          .res    1
ULW_linelen:            .res    1
ULW_linestride:         .res    1
ULW_srcstride:          .res    1
ULW_carryflag:          .res    1

ULWR_src:               .res    2
ULWR_srcsize:           .res    2
ULWR_dest:              .res    2
ULWR_destsize:          .res    2
ULWR_char:              .res    3
ULWR_color:             .res    1

.segment "EXTZP": zeropage

ULW_winbufptr:          .res    2
ULW_winsrcptr:          .res    2
