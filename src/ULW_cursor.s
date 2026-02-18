; ULW_cursor.s - Shared cursor blink helpers (internal, not in jump table)
;
; Provides cursor blink via direct VERA color inversion at the cursor position.
; Used by ulwin_getkey and ulwin_input.
;
; Callers MUST load ULW_WINDOW_COPY (via ULW_getwinstruct) before calling
; any of these routines. The helpers read scol+ccol, slin+clin from the copy
; to compute the VERA address.

.include "unilib_impl.inc"

UL_CODE

; ULW_set_vera_cursor_addr - Set VERA ADDR to L0 color byte at cursor position
;   In: ULW_WINDOW_COPY loaded
;  Out: VERA::ADDR points to L0 color byte, increment=0, port 0 selected
;       VERA::CTRL bit 0 cleared (port 0)
.proc ULW_set_vera_cursor_addr
                        stz VERA::CTRL

                        ; ADDR_L = (scol + ccol) * 2 + 1
                        lda ULWC_scol
                        clc
                        adc ULWC_ccol
                        asl
                        inc
                        sta VERA::ADDR

                        ; ADDR_M = (L0_MAP_BASE << 1) + slin + clin
                        lda VERA::L0::MAP_BASE
                        asl
                        clc
                        adc ULWC_slin
                        clc
                        adc ULWC_clin
                        sta VERA::ADDR+1

                        ; ADDR_H = 0 (no auto-increment, addr bit 16 = 0)
                        stz VERA::ADDR+2
                        rts
.endproc

; ULW_show_cursor - Show blinking cursor by inverting colors at cursor position
;   In: ULW_WINDOW_COPY loaded with current window state
;  Out: ULW_blink_on = 1, L0/L1 colors saved
.proc ULW_show_cursor
                        sei
                        jsr ULW_set_vera_cursor_addr

                        ; Read L0 color and save it
                        lda VERA::DATA0
                        sta ULW_saved_color

                        ; Swap nibbles (invert fg/bg) and write back
                        lsr
                        lsr
                        lsr
                        lsr
                        sta ULWC_temp           ; old_bg in low nibble
                        lda ULW_saved_color
                        asl
                        asl
                        asl
                        asl                     ; old_fg in high nibble
                        ora ULWC_temp
                        sta VERA::DATA0

                        ; Switch to L1: add $40 to ADDR_M
                        lda VERA::ADDR+1
                        clc
                        adc #$40
                        sta VERA::ADDR+1

                        ; Read L1 color and save it
                        lda VERA::DATA0
                        sta ULW_saved_l1clr

                        ; Replace L1 high nibble with old L0 bg
                        ; new_L1 = (L1_current & $0F) | (saved_L0_color & $F0)
                        and #$0F
                        sta ULWC_temp
                        lda ULW_saved_color
                        and #$F0
                        ora ULWC_temp
                        sta VERA::DATA0

                        cli

                        ; Mark cursor as shown
                        lda #1
                        sta ULW_blink_on
                        rts
.endproc

; ULW_hide_cursor - Hide blinking cursor by restoring saved colors
;   In: ULW_WINDOW_COPY loaded with current window state
;  Out: ULW_blink_on = 0, L0/L1 colors restored
.proc ULW_hide_cursor
                        sei
                        jsr ULW_set_vera_cursor_addr

                        ; Restore saved L0 color
                        lda ULW_saved_color
                        sta VERA::DATA0

                        ; Switch to L1: add $40 to ADDR_M
                        lda VERA::ADDR+1
                        clc
                        adc #$40
                        sta VERA::ADDR+1

                        ; Restore saved L1 color
                        lda ULW_saved_l1clr
                        sta VERA::DATA0

                        cli

                        stz ULW_blink_on
                        rts
.endproc

; ULW_check_blink - Check if it's time to toggle cursor blink
;   In: ULW_WINDOW_COPY loaded with current window state
;  Out: Cursor may have been toggled
.proc ULW_check_blink
                        jsr RDTIM               ; A=lo, X=mid, Y=hi (X16 convention)
                        tax                     ; save low byte in X
                        sec
                        sbc ULW_blink_jiffy
                        cmp #30                  ; 30 jiffies = 0.5 sec
                        bcc @done
                        stx ULW_blink_jiffy      ; update timer with saved low byte
                        lda ULW_blink_on
                        bne @hide
                        jmp ULW_show_cursor      ; tail call
@hide:                  jmp ULW_hide_cursor      ; tail call
@done:                  rts
.endproc

UL_BSS

ULW_blink_on:           .res 1          ; 0=normal, 1=inverted
ULW_saved_color:        .res 1          ; saved L0 color byte
ULW_saved_l1clr:        .res 1          ; saved L1 color byte
ULW_blink_jiffy:        .res 1          ; low byte of RDTIM at last toggle
ULWC_temp:              .res 1          ; scratch byte for nibble swap
