; ulwin_input.s - Interactive line input with full editing
;
; Provides a complete line editor with cursor movement, insert, backspace,
; and blinking cursor. Returns the entered text as a UniLib string handle.

.include "unilib_impl.inc"

UL_CODE

; ulwin_input - Interactive line input with full editing
;   In: A               - Window handle
;       X               - Max characters (1-255; 0 = use remaining columns on line)
;       r0L             - Timeout in 1/10 seconds (0 = no timeout)
;       r0H             - Initial text length (0 = fresh input;
;                         >0 = chars already on screen before cursor position)
;  Out: YX              - Newly allocated string handle (caller must ulstr_release)
;       A               - Terminating PETSCII key ($0D = Enter)
;       carry set       - Timeout expired (YX still valid — text so far)
.proc ulwin_input
                        ; Save parameters
                        sta ULWI_handle
                        stx ULWI_maxchars
                        lda gREG::r0L
                        sta ULWI_timeout
                        lda gREG::r0H
                        sta ULWI_length
                        sta ULWI_cursor_pos     ; cursor starts at end of preloaded text

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Compute timeout in jiffies (r0L * 6, 0 = no timeout)
                        lda ULWI_timeout
                        beq @no_timeout
                        tax
                        lda #6
                        XCALL ulmath_umul8_8, UNILIB_BANK_A
                        stx ULWI_timeout_jifs
                        sty ULWI_timeout_jifs+1
                        bra @have_timeout
@no_timeout:
                        stz ULWI_timeout_jifs
                        stz ULWI_timeout_jifs+1

@have_timeout:
                        ; Access window struct
                        lda ULWI_handle
                        jsr ULW_getwinstruct

                        ; Compute start position:
                        ; Input starts at cursor_col - r0H (preloaded text before cursor)
                        lda ULWC_ccol
                        sec
                        sbc ULWI_length
                        sta ULWI_start_col
                        lda ULWC_clin
                        sta ULWI_start_line

                        ; Compute remaining columns from start to end of line
                        lda ULWC_ncol
                        sec
                        sbc ULWI_start_col
                        sta ULWI_remaining

                        ; Clamp maxchars: if 0 or > remaining, use remaining
                        lda ULWI_maxchars
                        beq @use_remaining
                        cmp ULWI_remaining
                        bcc @have_max
                        beq @have_max
@use_remaining:
                        lda ULWI_remaining
                        sta ULWI_maxchars
@have_max:

                        ; Position cursor at end of preloaded text, erase rest of line
                        lda ULWI_start_col
                        clc
                        adc ULWI_length
                        tax
                        ldy ULWI_start_line
                        lda ULWI_handle
                        jsr ulwin_putcursor

                        lda ULWI_handle
                        jsr ulwin_eraseeol
                        jsr ulwin_refresh

                        ; Initialize blink state
                        stz ULW_blink_on
                        stz ULWI_timed_out
                        jsr RDTIM               ; A=lo, X=mid, Y=hi (X16 convention)
                        sta ULW_blink_jiffy

                        ; Save RDTIM for timeout deadline
                        lda ULWI_timeout_jifs
                        ora ULWI_timeout_jifs+1
                        beq @init_done
                        ; deadline = current time + timeout_jifs
                        lda ULW_blink_jiffy     ; recover low byte
                        clc
                        adc ULWI_timeout_jifs
                        sta ULWI_deadline
                        txa                     ; X = mid byte of time
                        adc ULWI_timeout_jifs+1
                        sta ULWI_deadline+1

@init_done:
                        ; Reload window struct for blink (putcursor/eraseeol may have changed it)
                        lda ULWI_handle
                        jsr ULW_getwinstruct

                        ; Show cursor immediately at input start
                        jsr ULW_show_cursor

; === Main key loop ===
@key_loop:
                        ; Call RDTIM for both timeout and blink checks
                        jsr RDTIM               ; A=lo, X=mid, Y=hi (X16 convention)
                        sta ULWI_rdtim_lo       ; save low byte

                        ; --- Check timeout ---
                        lda ULWI_timeout_jifs
                        ora ULWI_timeout_jifs+1
                        beq @no_tcheck

                        ; expired if current X:lo >= deadline (unsigned 16-bit)
                        cpx ULWI_deadline+1
                        bcc @no_tcheck          ; current_mid < deadline_mid
                        beq :+
                        jmp @do_timeout         ; current_mid > deadline_mid
:                       lda ULWI_rdtim_lo
                        cmp ULWI_deadline
                        bcc @no_tcheck
                        jmp @do_timeout         ; current_lo >= deadline_lo

@no_tcheck:
                        ; --- Check blink (RDTIM-based) ---
                        lda ULWI_rdtim_lo
                        tax                     ; save for stx later
                        sec
                        sbc ULW_blink_jiffy
                        cmp #30                 ; 30 jiffies = 0.5 sec
                        bcc @do_getin
                        stx ULW_blink_jiffy     ; update timer
                        lda ULW_blink_on
                        bne @blink_hide
                        jsr ULW_show_cursor
                        bra @do_getin
@blink_hide:
                        jsr ULW_hide_cursor

@do_getin:
                        ; --- Poll keyboard ---
                        jsr GETIN
                        cmp #0
                        bne @got_key

                        ; No key — call idle callback if configured
                        lda ULW_keyidle
                        ora ULW_keyidle+1
                        beq @key_loop
                        jsr @do_idle
                        bra @key_loop

                        ; --- Got a key ---
@got_key:
                        ; Hide cursor before processing
                        sta ULWI_termkey        ; save key temporarily
                        lda ULW_blink_on
                        beq @dispatch
                        jsr ULW_hide_cursor

@dispatch:
                        lda ULWI_termkey

                        ; Dispatch on PETSCII key
                        cmp #$0D                ; Enter
                        bne :+
                        jmp @enter
:                       cmp #$14                ; Backspace (DEL)
                        bne :+
                        jmp @backspace
:                       cmp #$9D                ; Cursor Left
                        bne :+
                        jmp @left
:                       cmp #$1D                ; Cursor Right
                        bne :+
                        jmp @right
:                       cmp #$13                ; Home
                        bne :+
                        jmp @home
:
; --- Try printable character (placed near dispatch to avoid range errors) ---
@try_printable:
                        ; Check if buffer is full
                        lda ULWI_length
                        cmp ULWI_maxchars
                        bcc :+
                        jmp @after_move         ; at max, ignore
:
                        ; Convert PETSCII to Unicode codepoint
                        ; Keyboard alpha: $41-$5A → lowercase a-z, $C1-$DA → uppercase A-Z
                        ldx ULWI_termkey        ; X = raw PETSCII
                        cpx #$41
                        bcc @not_alpha
                        cpx #$5B
                        bcs @check_shifted
                        ; Unshifted alpha $41-$5A → lowercase Unicode $61-$7A
                        txa
                        clc
                        adc #$20
                        bra @have_alpha
@check_shifted:
                        cpx #$C1
                        bcc @not_alpha
                        cpx #$DB
                        bcs @not_alpha
                        ; Shifted alpha $C1-$DA → uppercase Unicode $41-$5A
                        txa
                        sec
                        sbc #$80
@have_alpha:
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        bra @do_insert

@not_alpha:
                        XCALL UL_petscii_to_codepoint, UNILIB_BANK_A
                        bcc :+
                        jmp @after_move         ; control code, skip
:
                        ; Store codepoint in r0/r1L for inschar
                        stx gREG::r0L           ; cp_lo
                        sty gREG::r0H           ; cp_hi
                        stz gREG::r1L           ; BMP only

@do_insert:

                        ; Position cursor for insert
                        lda ULWI_start_col
                        clc
                        adc ULWI_cursor_pos
                        tax
                        ldy ULWI_start_line
                        lda ULWI_handle
                        jsr ulwin_putcursor

                        ; Insert character (shifts rest of line right, puts char)
                        lda ULWI_handle
                        jsr ulwin_inschar

                        inc ULWI_length
                        inc ULWI_cursor_pos
                        jmp @after_edit

; --- Enter: terminate input ---
@enter:
                        lda #$0D
                        sta ULWI_termkey
                        stz ULWI_timed_out
                        jmp @return_string

; --- Timeout expired ---
@do_timeout:
                        lda #$80
                        sta ULWI_timed_out
                        stz ULWI_termkey
                        jmp @return_string

; --- Backspace: delete char behind cursor ---
@backspace:
                        lda ULWI_cursor_pos
                        beq @key_loop_jmp       ; at start, nothing to delete

                        ; Move cursor back one
                        dec ULWI_cursor_pos
                        lda ULWI_start_col
                        clc
                        adc ULWI_cursor_pos
                        tax
                        ldy ULWI_start_line
                        lda ULWI_handle
                        jsr ulwin_putcursor

                        ; Delete character at new cursor position
                        lda ULWI_handle
                        jsr ulwin_delchar

                        dec ULWI_length
                        jmp @after_edit

; --- Cursor Left ---
@left:
                        lda ULWI_cursor_pos
                        beq @key_loop_jmp       ; at start, can't go left

                        dec ULWI_cursor_pos
                        lda ULWI_start_col
                        clc
                        adc ULWI_cursor_pos
                        tax
                        ldy ULWI_start_line
                        lda ULWI_handle
                        jsr ulwin_putcursor
                        jmp @after_move

@key_loop_jmp:
                        jmp @after_move

; --- Cursor Right ---
@right:
                        lda ULWI_cursor_pos
                        cmp ULWI_length
                        bcs @key_loop_jmp       ; at end of text, can't go right

                        inc ULWI_cursor_pos
                        lda ULWI_start_col
                        clc
                        adc ULWI_cursor_pos
                        tax
                        ldy ULWI_start_line
                        lda ULWI_handle
                        jsr ulwin_putcursor
                        jmp @after_move

; --- Home: move to start ---
@home:
                        stz ULWI_cursor_pos
                        ldx ULWI_start_col
                        ldy ULWI_start_line
                        lda ULWI_handle
                        jsr ulwin_putcursor
                        jmp @after_move

; === After editing (inschar/delchar): refresh display ===
@after_edit:
                        jsr ulwin_refresh

; === After any cursor movement: reload struct, show cursor immediately ===
@after_move:
                        ; Reload window struct for blink
                        lda ULWI_handle
                        jsr ULW_getwinstruct

                        ; Reset blink timer and show cursor immediately
                        jsr RDTIM               ; A=lo, X=mid, Y=hi
                        sta ULW_blink_jiffy
                        jsr ULW_show_cursor     ; show cursor at new position (sets blink_on=1)

                        jmp @key_loop

; === Return string ===
@return_string:
                        ; Hide cursor if still visible
                        lda ULW_blink_on
                        beq @cursor_hidden
                        jsr ULW_hide_cursor

@cursor_hidden:
                        ; Put cursor at end of text, erase to EOL
                        lda ULWI_start_col
                        clc
                        adc ULWI_length
                        tax
                        ldy ULWI_start_line
                        lda ULWI_handle
                        jsr ulwin_putcursor

                        lda ULWI_handle
                        jsr ulwin_eraseeol
                        jsr ulwin_refresh

                        ; Get only the entered characters as a string
                        lda ULWI_length
                        sta gREG::r0L           ; count = chars entered
                        lda ULWI_handle
                        ldx ULWI_start_col
                        ldy ULWI_start_line
                        jsr ULW_getloc_n        ; YX = string handle, carry set on error
                        stx ULWI_str_lo
                        sty ULWI_str_hi

                        ; Restore caller's bank
                        pla
                        sta BANKSEL::RAM

                        ; Return: YX = string, A = termkey, carry = timeout
                        ldx ULWI_str_lo
                        ldy ULWI_str_hi
                        lda ULWI_timed_out
                        asl                     ; shift bit 7 into carry
                        lda ULWI_termkey
                        rts

@do_idle:               jmp (ULW_keyidle)
.endproc

UL_BSS

ULWI_handle:            .res 1          ; window handle
ULWI_maxchars:          .res 1          ; effective max characters
ULWI_timeout:           .res 1          ; timeout in 1/10 sec (0=none)
ULWI_length:            .res 1          ; current text length
ULWI_cursor_pos:        .res 1          ; cursor offset from start (0=at start)
ULWI_start_col:         .res 1          ; window-relative column where input begins
ULWI_start_line:        .res 1          ; window-relative line
ULWI_remaining:         .res 1          ; remaining columns on line (temp)
ULWI_timeout_jifs:      .res 2          ; timeout in jiffies (r0L * 6, 0=none)
ULWI_deadline:          .res 2          ; RDTIM deadline (low+mid bytes)
ULWI_termkey:           .res 1          ; terminating key
ULWI_timed_out:         .res 1          ; 0 = normal, $80 = timeout
ULWI_str_lo:            .res 1          ; returned string handle low
ULWI_str_hi:            .res 1          ; returned string handle high
ULWI_rdtim_lo:          .res 1          ; saved RDTIM low byte for key loop
