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
                        jsr ULM_access
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
                        jsr ULM_access
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
;  Out: ULW_winbufptr/BANKSEL::RAM      - Window buffer pointer to line/column
;       ULW_linelen                     - Length of window content line in buffer
;       ULW_linestride                  - Length of full window line in buffer (including border)
.proc ULW_getwinbufptr
                        ; For a window with no border, line length and stride are both ncol*3
                        phx
                        phy
                        lda ULW_WINDOW_COPY::ncol
                        ldx #3
                        jsr ulmath_umul8_8 ; The most this can be is 240, so we can ignore the high byte
                        stx ULW_linelen
                        stx ULW_linestride

                        ; If we have a border, the stride becomes linelen+6 (also save flags so we can check border later)
                        lda ULW_WINDOW_COPY::flags
                        pha
                        bpl :+
                        txa
                        clc
                        adc #6
                        sta ULW_linestride

                        ; Access the window buffer and save the start address
:                       ldx ULW_WINDOW_COPY::buf_ptr
                        ldy ULW_WINDOW_COPY::buf_ptr+1
                        jsr ULM_access
                        stx ULW_winbufptr
                        sty ULW_winbufptr+1

                        ; If we have a border, we increment X and Y by 1 to compensate
                        pla
                        ply
                        plx
                        bit #$80
                        beq :+
                        inx
                        iny

                        ; Now, the offset into the window buffer is (Y*linestride)+X*3
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
                        ldx #3
                        jsr ulmath_umul8_8
                        txa
                        clc
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
                        lda ULW_WINDOW_COPY::title_addr
                        ora ULW_WINDOW_COPY::title_addr+1
                        ora ULW_WINDOW_COPY::title_bank
                        bra a_handy_rts
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
                        bra ULW_fillrect
.endproc

; ULW_drawchar - draw a UTF-16 character into a window at a specific location in a specific color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Line/column in window contents (L=column, H=line)
;       ULWR_char       - UTF-16 character
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
                        ; Get the window buffer at our top left
                        ldx ULWR_dest
                        ldy ULWR_dest+1
                        jsr ULW_getwinbufptr

                        ; Need to fill nlin lines with our character/color pattern
                        lda ULWR_size+1
                        sta @linecount
                        lda ULWR_size
                        ldx #3
                        jsr ulmath_umul8_8
                        stx @linefill_cmp+1

                        ; Write our character/color pattern to the line
:                       ldy #0
:                       lda ULWR_char
                        sta (ULW_winbufptr),y
                        iny
                        lda ULWR_char+1
                        sta (ULW_winbufptr),y
                        iny
                        lda ULWR_color
                        sta (ULW_winbufptr),y
                        iny
@linefill_cmp:          cpy #$00
                        bcc :-

                        ; Advance to the next line
                        lda ULW_winbufptr
                        clc
                        adc ULW_linestride
                        sta ULW_winbufptr
                        lda ULW_winbufptr+1
                        adc #0
                        sta ULW_winbufptr+1
                        dec @linecount
                        bne :--

                        ; Okay, window backbuffer is cleared; check occlusion, if the window is:
                        ;   - visible, we can clear it in the backbuffer immediately
                        ;   - occluded, we mark the visible portions of the rectangle as dirty
                        ;   - covered, we don't need to do anything
                        lda #$01
                        bit ULW_WINDOW_COPY::flags
                        bne @done
                        bvs @occluded

                        ; The window is visible, so we can clear the rectangle immediately in the backbuffer
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
                        jmp ULV_fillrect

@linecount:             .byte $00

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

; ULW_drawstring - draw a string into a window at a specific location in a specific color
;   In: ULW_scratch_fptr/BANKSEL::RAM/ULW_WINDOW_COPY - Window structure
;       ULWR_dest       - Top/left in window contents (L=column, H=line)
;       ULWR_color      - Color (fg=low nibble, bg=high nibble)
;       YX              - Address of string (in low memory)
.proc ULW_drawstring
                        rts
.endproc

.bss

ULW_linelen:            .res    1
ULW_linestride:         .res    1

ULWR_src:               .res    2
ULWR_dest:              .res    2
ULWR_size:              .res    2
ULWR_char:              .res    2
ULWR_color:             .res    1

.segment "EXTZP": zeropage

ULW_winbufptr:          .res    2
