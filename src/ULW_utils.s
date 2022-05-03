; ULW_utils - Window utility functions

.include "unilib_impl.inc"

.code

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
.endproc
a_handy_rts:            rts

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
                        sta ULWR_size
                        ldx ULW_WINDOW_COPY::title
                        ldy ULW_WINDOW_COPY::title+1
                        jsr ULW_drawstring
                        clc
                        adc ULWR_dest
                        sta ULWR_dest

                        ; And finish with another space
                        lda #' '
                        sta ULWR_char
                        stz ULWR_char+1
                        stz ULWR_char+2
                        jmp ULW_drawchar
.endproc

; ULW_clearrect - clear a rectangle in a window with a specific color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Top/left in window contents (L=column, H=line)
;       ULWR_size       - Size in window contents (L=columns, H=lines)
;       ULWR_color      - Color (fg=low nibble, bg=high nibble)
.proc ULW_clearrect
                        ; This is just a fillrect with a space
                        lda #' '
                        sta ULWR_char
                        stz ULWR_char+1
                        stz ULWR_char+2
                        bra ULW_fillrect
.endproc

; ULW_drawchar - draw a UTF-16 character into a window at a specific location in a specific color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Line/column in window contents (L=column, H=line)
;       ULWR_char       - Unicode character
;       ULWR_color      - Color (fg=low nibble, bg=high nibble)
.proc ULW_drawchar
                        ; This is just a fillrect with size 1x1
                        lda #1
                        sta ULWR_size
                        sta ULWR_size+1
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_fillrect - fill a rectangle in a window with a specific character/color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Top/left in window contents (L=column, H=line)
;       ULWR_size       - Size in window contents (L=columns, H=lines)
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
                        lda #$01
                        bit ULW_WINDOW_COPY::flags
                        bne @done
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
                        lda ULWR_size
                        sta ULVR_size
                        lda ULWR_size+1
                        sta ULVR_size+1
                        lda ULWR_color
                        sta ULVR_color
                        ldx ULWR_char
                        ldy ULWR_char+1
                        lda #0
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
                        lda ULWR_size+1
                        sta ULW_linecount
                        ldx ULWR_size
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
;       ULWR_size       - Low byte = max length in characters (0 = whole string)
;       ULWR_color      - Color (fg=low nibble, bg=high nibble)
;       AYX             - Far pointer to string (A=RAM bank, YX=address)
;  Out: A               - Number of characters drawn
.proc ULW_drawstring

                        ; Draw string characters to window; need pointer we can increment
                        jsr ulstr_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        ; Get the max length to write (but not more than to the end of our line)
                        lda ULW_WINDOW_COPY::ncol
                        sec
                        sbc ULWR_dest
                        cmp ULWR_size
                        bcc :+
                        lda ULWR_size
:                       clc
                        adc ULWR_dest
                        sta @lastcol
                        lda ULWR_dest
                        sta @startcol

                        ; Write our string characters/color to the line
                        ldy #0
:                       lda (ULS_scratch_fptr),y
                        tax
                        iny
                        lda (ULS_scratch_fptr),y
                        iny

                        ; Check for NUL-terminator
                        cmp #0
                        bne :+
                        cpx #0
                        bne :+
                        dey
                        dey
                        bra @written

                        ; Try to print the character
:                       stx ULWR_char
                        sta ULWR_char+1
                        stz ULWR_char+2
                        phy
                        jsr ULW_drawchar
                        ply

                        ; Step ahead one cell if we printed something
                        bcc :--
                        inc ULWR_dest
                        cmp @lastcol
                        bcc :--

                        ; Number of characters printed is ULWR_dest-@startcol
@written:               lda ULWR_dest
                        sec
                        sbc @startcol
                        ldx @startcol
                        stx ULWR_dest
                        rts
@startcol:              .byte $00
@lastcol:               .byte $00
.endproc

.bss

ULW_linecount:          .res    1
ULW_linelen:            .res    1
ULW_linestride:         .res    1
ULW_carryflag:          .res    1

ULWR_src:               .res    2
ULWR_dest:              .res    2
ULWR_size:              .res    2
ULWR_char:              .res    3
ULWR_color:             .res    1

.segment "EXTZP": zeropage

ULW_winbufptr:          .res    2

ULS_scratch_fptr:       .res    3
