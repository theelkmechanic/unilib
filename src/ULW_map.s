; ULW_map - Occlusion/dirty map utilities

.include "unilib_impl.inc"

ULW_temp_ptroff         = $6ff
ULW_temp_tiletotal_lo   = $700
ULW_temp_tiletotal_hi   = $740
ULW_temp_tilecount_lo   = $780
ULW_temp_tilecount_hi   = $7c0

.code

; ULW_update_occlusion - Update the window map and occlusion/covered status
.proc ULW_update_occlusion
                        ; Save A/X/Y/bank
                        pha
                        phx
                        phy
                        ldy BANKSEL::RAM
                        phy

                        ; Update the map and keep track of visible tile counts for each window, starting at the screen
                        ldx #<ULW_fill_map_and_count
                        ldy #>ULW_fill_map_and_count
                        sec
                        jsr ULW_winlist_loop

                        ; Okay, map is up to date and we have visible tile counts for all our windows, so go back through
                        ; and use that to set their occluded/covered status
                        ldx #<ULW_update_coverflags
                        ldy #>ULW_update_coverflags
                        sec
                        jsr ULW_winlist_loop
                        bra UL_map_exit
.endproc

; ULW_set_dirty_rect - Mark a screen rectangle as dirty in the map
;   In: ULW_WINDOW_COPY::handle - Handle to match (0-63, negative=force dirty)
;       ULWR_dest       - Top/left of screen rectangle (L=column, H=line)
;       ULWR_size       - Size of screen rectangle (L=columns, H=lines)
.proc ULW_set_dirty_rect
                        ; Save A/X/Y/bank
                        pha
                        phx
                        phy
                        ldy BANKSEL::RAM
                        phy

                        ; Set the dirty flags for the window/rect in the window map
                        ldx #<ULW_set_dirty_cell
                        ldy #>ULW_set_dirty_cell
                        jsr ULW_maprect_loop
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE ***

.proc UL_map_exit
                        ; Restore A/X/Y/bank
                        ply
                        sty BANKSEL::RAM
                        ply
                        plx
                        pla
                        rts
.endproc

; ULW_set_dirty_cell - Set the dirty bit for the cell if the window handle matches
;   In: A               - Map cell value (high bit = dirty flag, low 6 bits = window handle)
;       ULW_temp_handle - Set dirty bit if window handle matches (negative = always set dirty bit)
.proc ULW_set_dirty_cell
                        ; Are we forcing?
                        bit ULW_WINDOW_COPY::handle
                        bmi @setit

                        ; Does the handle match?
                        tax
                        and #$3f
                        cmp ULW_WINDOW_COPY::handle
                        beq @setit

                        ; Keep the dirty bit
@keepit:                txa
                        .byte $2c

                        ; Set the dirty bit
@setit:                 ora #$80
                        rts
.endproc

; ULW_fill_map_and_count - Fill the scratch window rect in the map and update the counts
;   In: BANKSEL::RAM/ULW_scratch_fptr - Address/bank of window structure
.proc ULW_fill_map_and_count
                        ; Save the window info we need
                        ldy #ULW_WINDOW::ccol
:                       lda (ULW_scratch_fptr),y
                        sta ULW_WINDOW_COPY::handle,y
                        dey
                        bpl :-

                        ; Adjust for border
                        ldy ULW_WINDOW_COPY::scol
                        sty ULWR_dest
                        ldy ULW_WINDOW_COPY::slin
                        ldx ULW_WINDOW_COPY::nlin
                        lda ULW_WINDOW_COPY::ncol
                        bit ULW_WINDOW_COPY::flags
                        bpl :+
                        dec ULWR_dest
                        dey
                        inx
                        inx
                        inc
                        inc
:                       
                        sty ULWR_dest+1
                        stx ULWR_size+1
                        sta ULWR_size

                        ; Calculate the total number of tiles for the window
                        jsr ulmath_umul8_8
                        phy
                        phx

                        ; Save the window handle
                        lda (ULW_scratch_fptr)
                        sta ULW_WINDOW_COPY::handle
                        tax

                        ; Store the total number of tiles for this window, and clear the count
                        pla
                        sta ULW_temp_tiletotal_lo,x
                        pla
                        sta ULW_temp_tiletotal_hi,x
                        stz ULW_temp_tilecount_lo,x
                        stz ULW_temp_tilecount_hi,x

                        ; Loop over the rectangle in the map to update the handles and tile counts
                        ldx #<ULW_set_handle_and_count
                        ldy #>ULW_set_handle_and_count
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE ***

; ULW_maprect_loop - Loop over a rectangle in the window map, calling a function for each cell
;   In: ULWR_dest       - Top/left of screen rectangle (L=column, H=line)
;       ULWR_size       - Size of screen rectangle (L=columns, H=lines)
;       YX              - Function address to call for each cell
.proc ULW_maprect_loop
                        ; Update callback address
                        stx @cell_callback+1
                        sty @cell_callback+2

                        ; Switch to bank 1 to access our window map
                        lda #1
                        sta BANKSEL::RAM

                        ; Calculate and store our start address
                        lda ULWR_dest+1
                        ldx #80
                        jsr ulmath_umul8_8
                        txa
                        clc
                        adc ULWR_dest
                        sta @column_loop+1
                        sta @column_store+1
                        tya
                        adc #>ULW_WINMAP
                        sta @column_loop+2
                        sta @column_store+2

                        ; Start each line at last column, and loop over all lines
                        lda ULWR_size
                        dec
                        sta @line_loop+1
                        lda ULWR_size+1
                        sta @line_count

                        ; Initialize Y for each line 
@line_loop:             ldy #$00

                        ; Read the existing value in the map
@column_loop:           lda ULW_WINMAP,y

                        ; Call the function to modify the value (save/restore Y because we need it)
                        phy
@cell_callback:         jsr $0000
                        ply

                        ; Store the updated value and step to the next column
@column_store:          sta ULW_WINMAP,y
                        dey
                        bpl @column_loop

                        ; Check if done
                        dec @line_count
                        bne :+
                        rts
@line_count:            .byte   $00

                        ; Add one line
:                       lda @column_loop+1
                        clc
                        adc #80
                        sta @column_loop+1
                        sta @column_store+1
                        lda @column_loop+2
                        adc #0
                        sta @column_loop+2
                        sta @column_store+2
                        bra @line_loop
.endproc

; ULW_set_handle_and_count - cell callback to update window handles in the map and count the changes
.proc ULW_set_handle_and_count
                        ; Save the cell value for a minute (for the dirty bit)
                        pha

                        ; For screen window (handle 0), don't count changes because we're just clearing
                        ldy ULW_WINDOW_COPY::handle
                        beq :++

                        ; See what window was there and decrement its count
                        and #$3f
                        tax
                        lda ULW_temp_tilecount_lo,x
                        bne :+
                        dec ULW_temp_tilecount_hi,x
:                       dec ULW_temp_tilecount_lo,x

                        ; Count our cell entry
:                       tya
                        tax
                        inc ULW_temp_tilecount_lo,x
                        bne :+
                        inc ULW_temp_tilecount_hi,x

                        ; Put our handle in and preserve the dirty bit
:                       pla
                        and #$c0
                        ora ULW_WINDOW_COPY::handle
                        rts
.endproc

; ULW_update_coverflags - Update window occluded/covered status based on tile count results
;   In: BANKSEL::RAM/ULW_scratch_fptr - Address/bank of window structure
.proc ULW_update_coverflags
                        ; Get the status and clear the occluded/covered bits
                        ldy #ULW_WINDOW::status
                        lda (ULW_scratch_fptr),y
                        and #<~(ULWS_OCCLUDED | ULWS_COVERED)
                        tay
                        stz ULW_WINDOW_COPY::status

                        ; Get the window handle so we can access the counts
                        lda (ULW_scratch_fptr)
                        tax

                        ; If the count is zero, the window is covered
                        lda ULW_temp_tilecount_hi,x
                        ora ULW_temp_tilecount_lo,x
                        beq @covered

                        ; If the tile count doesn't equal the tile total, the window is occluded
                        lda ULW_temp_tilecount_hi,x
                        cmp ULW_temp_tiletotal_hi,x
                        bne @occluded
                        lda ULW_temp_tilecount_lo,x
                        cmp ULW_temp_tiletotal_lo,x
                        beq @store_status

                        ; Window is covered, set both bits
@covered:               lda #ULWS_OCCLUDED | ULWS_COVERED
                        .byte $2c

                        ; Window is occluded, just set the occluded bit
@occluded:              lda #ULWS_OCCLUDED
                        sta ULW_WINDOW_COPY::status

                        ; Store the correct status
@store_status:          tya
                        ora ULW_WINDOW_COPY::status
                        ldy #ULW_WINDOW::status
                        sta (ULW_scratch_fptr),y
                        rts
.endproc

; ULW_winlist_loop - Call a given function for each open window (window structure pointer will be in ULW_scratch_ptr)
;   In: YX              - Address of function
;       carry           - Set to start at screen window and follow next, clear to start at current window and follow previous
.proc ULW_winlist_loop
                        ; Update callback address
                        stx @winlist_loop+1
                        sty @winlist_loop+2

                        ; Where are we starting the list?
                        bcs :+

                        ; Start at the current window and follow the previous addresses
                        lda #ULW_WINDOW::prev_addr
                        sta ULW_temp_ptroff
                        ldx ULW_current_fptr
                        ldy ULW_current_fptr+1
                        lda ULW_current_fptr+2
                        bra :++

                        ; Start at the screen window and follow the next addresses
:                       lda #ULW_WINDOW::next_addr
                        sta ULW_temp_ptroff
                        ldx ULW_screen_fptr
                        ldy ULW_screen_fptr+1
                        lda ULW_screen_fptr+2

:                       stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        sta ULW_scratch_fptr+2
                        sta BANKSEL::RAM

                        ; Call a given function for each iteration of the loop
@winlist_loop:          jsr $0000

                        ; Step to the next window
                        lda ULW_scratch_fptr+2
                        sta BANKSEL::RAM
                        ldy ULW_temp_ptroff
                        lda (ULW_scratch_fptr),y
                        pha
                        iny
                        lda (ULW_scratch_fptr),y
                        pha
                        iny
                        lda (ULW_scratch_fptr),y
                        bne :+
                        pla
                        pla
                        rts
:                       sta BANKSEL::RAM
                        pla
                        sta ULW_scratch_fptr+1
                        pla
                        sta ULW_scratch_fptr
                        bra @winlist_loop
.endproc
