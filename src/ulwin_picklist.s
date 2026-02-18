; ulwin_picklist - Display a scrollable pick list in a window

.include "unilib_impl.inc"

UL_CODE

; ulwin_picklist - Display a scrollable pick list in a window
;   In: A               - Window handle
;       YX              - Stringtable BRP to choose from
;   Out: A              - 1-based index of chosen item, or 0 if cancelled
.proc ulwin_picklist
                        ; Save params
                        sta ULWPK_handle
                        stx ULWPK_strtbl
                        sty ULWPK_strtbl+1

                        ; Save caller's r0 (KERNAL convention)
                        lda gREG::r0L
                        pha
                        lda gREG::r0H
                        pha

                        lda BANKSEL::RAM
                        pha
                        phx
                        phy

                        ; Get string table entry count
                        ldx ULWPK_strtbl
                        ldy ULWPK_strtbl+1
                        XCALL ulmem_access, UNILIB_BANK_A
                        stx UL_varptr
                        sty UL_varptr+1
                        lda (UL_varptr)
                        sta ULWPK_count
                        cmp #0
                        bne :+
                        jmp @exit_zero          ; empty table
:
                        ; Get window info
                        lda ULWPK_handle
                        jsr ULW_getwinstruct
                        lda ULWC_ncol
                        sta ULWPK_ncol
                        lda ULWC_nlin
                        sta ULWPK_nlin
                        lda ULWC_color
                        sta ULWPK_normal_color

                        ; Compute inverse color (swap nibbles)
                        and #$0F
                        asl
                        asl
                        asl
                        asl
                        sta ULWPK_inverse_color
                        lda ULWPK_normal_color
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULWPK_inverse_color
                        sta ULWPK_inverse_color

                        ; Initialize
                        stz ULWPK_scroll
                        lda #1
                        sta ULWPK_selection

                        ; ======= REDRAW =======
@redraw:                ; Refresh window copy and clear
                        lda ULWPK_handle
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        jsr ULW_clear

                        ; Draw each visible line
                        stz ULWPK_cur_line

@draw_loop:             lda ULWPK_cur_line
                        cmp ULWPK_nlin
                        bcc :+
                        jmp @draw_done
:
                        ; Index = scroll + cur_line + 1 (1-based)
                        clc
                        adc ULWPK_scroll
                        inc
                        sta ULWPK_cur_idx

                        ; Past end of entries?
                        cmp ULWPK_count
                        beq :+
                        bcc :+
                        jmp @draw_done
:
                        ; Is this the selected entry?
                        lda ULWPK_cur_idx
                        cmp ULWPK_selection
                        bne @use_normal
                        lda ULWPK_inverse_color
                        bra @do_color
@use_normal:            lda ULWPK_normal_color
@do_color:              sta ULWR_color

                        ; Fill this line with spaces and per-line color
                        stz ULWR_dest
                        lda ULWPK_cur_line
                        sta ULWR_dest+1
                        lda ULWPK_ncol
                        sta ULWR_destsize
                        lda #1
                        sta ULWR_destsize+1
                        jsr ULW_clearrect

                        ; Get string from table
                        lda ULWPK_cur_idx
                        ldx ULWPK_strtbl
                        ldy ULWPK_strtbl+1
                        stx gREG::r0L
                        sty gREG::r0H
                        XCALL ulstb_get, UNILIB_BANK_A
                        bcs @next_line

                        ; Save string BRP
                        stx ULWPK_str_brp
                        sty ULWPK_str_brp+1

                        ; Get printlen
                        XCALL ulstr_getprintlen, UNILIB_BANK_A
                        beq @next_line
                        sta ULWPK_print_len

                        ; Access string data
                        ldx ULWPK_str_brp
                        ldy ULWPK_str_brp+1
                        XCALL ULS_access, UNILIB_BANK_A

                        ; Refresh window buffers (ULS_access changed bank)
                        lda ULWPK_handle
                        jsr ULW_getwinstruct

                        ; Restore ULWR_color for this line
                        lda ULWPK_cur_idx
                        cmp ULWPK_selection
                        bne :+
                        lda ULWPK_inverse_color
                        bra :++
:                       lda ULWPK_normal_color
:                       sta ULWR_color

                        ; Draw the string
                        stz ULWR_dest
                        lda ULWPK_cur_line
                        sta ULWR_dest+1
                        lda ULWPK_print_len
                        cmp ULWPK_ncol
                        bcc :+
                        lda ULWPK_ncol
:                       sta ULWR_destsize
                        jsr ULW_drawstring

@next_line:             inc ULWPK_cur_line
                        jmp @draw_loop

@draw_done:
                        ; Refresh to display changes
                        jsr ulwin_refresh

                        ; ======= KEY LOOP =======
@keyloop:               jsr GETIN
                        cmp #0
                        beq @keyloop

                        ; Check for RETURN ($0D)
                        cmp #$0D
                        beq @return_selection

                        ; Check for STOP ($03)
                        cmp #$03
                        beq @exit_zero

                        ; Check for cursor down ($11)
                        cmp #$11
                        beq @key_down

                        ; Check for cursor up ($91)
                        cmp #$91
                        beq @key_up

                        ; Ignore other keys
                        bra @keyloop

@key_down:              ; Move selection down
                        lda ULWPK_selection
                        cmp ULWPK_count
                        bcs @keyloop            ; already at bottom
                        inc ULWPK_selection

                        ; Do we need to scroll?
                        lda ULWPK_selection
                        sec
                        sbc ULWPK_scroll
                        cmp ULWPK_nlin
                        bcc :+
                        beq :+
                        inc ULWPK_scroll
:                       jmp @redraw

@key_up:                ; Move selection up
                        lda ULWPK_selection
                        cmp #2
                        bcc @keyloop            ; already at top (selection=1)
                        dec ULWPK_selection

                        ; Scroll up if selection <= scroll
                        lda ULWPK_scroll
                        beq :+                  ; already at scroll=0
                        cmp ULWPK_selection
                        bcc :+                  ; scroll < selection, no scroll needed
                        dec ULWPK_scroll        ; scroll >= selection, scroll up
:                       jmp @redraw

@return_selection:      ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        ; Restore caller's r0
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        lda ULWPK_selection
                        rts

@exit_zero:             ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        ; Restore caller's r0
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        lda #0
                        rts
.endproc

UL_BSS

ULWPK_handle:           .res 1
ULWPK_strtbl:           .res 2
ULWPK_count:            .res 1
ULWPK_ncol:             .res 1
ULWPK_nlin:             .res 1
ULWPK_normal_color:     .res 1
ULWPK_inverse_color:    .res 1
ULWPK_scroll:           .res 1
ULWPK_selection:        .res 1
ULWPK_cur_line:         .res 1
ULWPK_cur_idx:          .res 1
ULWPK_str_brp:          .res 2
ULWPK_print_len:        .res 1
