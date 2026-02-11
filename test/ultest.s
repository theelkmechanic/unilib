.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

.import __BSS_RUN__, __BSS_SIZE__

.segment "EXEHDR"

    ; Stub launcher
    .byte $0b, $08, $b0, $07, $9e, $32, $30, $36, $31, $00, $00, $00

.segment "LOWCODE"

    jmp start

.code

; =========================================================================
; String data
; =========================================================================

font_fn:        .byte "unilib.ulf"
end_filenames:

str_title:      .byte "UniLib Tests", 0

str_t_alloc:    .byte "Alloc BRP + fill      ", 0
str_t_create:   .byte "Create byte iterator  ", 0
str_t_atstart:  .byte "atstart (initial)     ", 0
str_t_notatend: .byte "not atend (initial)   ", 0
str_t_fwd:      .byte "fetch_and_inc x8      ", 0
str_t_atend:    .byte "atend (after forward) ", 0
str_t_fai_end:  .byte "fetch_and_inc at end  ", 0
str_t_dec:      .byte "dec x8 to start       ", 0
str_t_dec_start:.byte "dec at start          ", 0
str_t_store:    .byte "store + readback      ", 0
str_t_adv:      .byte "adv 4, fetch=4        ", 0
str_t_rew:      .byte "rew 4, fetch=0        ", 0
str_t_delete:   .byte "delete iterator       ", 0

str_pass:       .byte " OK", 0
str_fail:       .byte " FAIL", 0
str_summary:    .byte "Passed: ", 0
str_of:         .byte " of ", 0
str_exp:        .byte " exp:", 0
str_got:        .byte " got:", 0

; =========================================================================
; Helpers
; =========================================================================

; putmsg - Write null-terminated ASCII string to the test window
;   In: YX = pointer to null-terminated string
.proc putmsg
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
@loop:                  lda (gREG::r5),y
                        beq @done
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        phy
                        lda win
                        jsr ulwin_putchar
                        ply
                        iny
                        bne @loop
@done:                  rts
.endproc

; puthex - Write A as 2 hex digits to the test window
;   In: A = byte value
.proc puthex
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        tax
                        lda @hexchars,x
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        lda win
                        jsr ulwin_putchar
                        pla
                        and #$0f
                        tax
                        lda @hexchars,x
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        lda win
                        jmp ulwin_putchar
@hexchars:              .byte "0123456789ABCDEF"
.endproc

; newline - Advance cursor to the start of the next line
.proc newline
                        lda win
                        jsr ulwin_getline
                        ina
                        tay
                        ldx #0
                        lda win
                        jmp ulwin_putcursor
.endproc

; pass - Print " OK" and increment pass counter
.proc pass
                        inc num_passed
                        inc num_total
                        ldx #<str_pass
                        ldy #>str_pass
                        jsr putmsg
                        jmp newline
.endproc

; fail - Print " FAIL" and increment fail counter
.proc fail
                        inc num_total
                        ldx #<str_fail
                        ldy #>str_fail
                        jsr putmsg
                        jmp newline
.endproc

; =========================================================================
; Main test program
; =========================================================================

start:
                        ; Zero BSS
                        lda #<__BSS_RUN__
                        sta gREG::r0L
                        lda #>__BSS_RUN__
                        sta gREG::r0H
                        lda #<__BSS_SIZE__
                        sta gREG::r1L
                        lda #>__BSS_SIZE__
                        sta gREG::r1H
                        lda #0
                        jsr MEMORY_FILL

                        ; Initialize UniLib
                        lda #(end_filenames-font_fn)
                        sta gREG::r1L
                        lda #8
                        sta gREG::r1H
                        lda #<font_fn
                        sta gREG::r0L
                        lda #>font_fn
                        sta gREG::r0H
                        lda #ULCOLOR::WHITE
                        sta gREG::r2L
                        lda #ULCOLOR::DGREY
                        sta gREG::r2H
                        jsr ul_init

                        ; Create title string
                        ldx #<str_title
                        ldy #>str_title
                        jsr ulstr_fromUtf8
                        stx titlebrp
                        sty titlebrp+1

                        ; Open test window: position (1,1), size 78x26, white on blue, border
                        lda #1
                        sta gREG::r0L
                        sta gREG::r0H
                        lda #78
                        sta gREG::r1L
                        lda #26
                        sta gREG::r1H
                        lda #ULCOLOR::WHITE
                        sta gREG::r2L
                        lda #ULCOLOR::BLUE
                        sta gREG::r2H
                        lda titlebrp
                        sta gREG::r3L
                        lda titlebrp+1
                        sta gREG::r3H
                        stz gREG::r4L
                        lda #ULWIN_FLAGS::BORDER
                        sta gREG::r4H
                        jsr ulwin_open
                        sta win
                        jsr ulwin_refresh

; ----- Test: Allocate BRP and fill with test pattern (0-7) -----

                        ldx #<str_t_alloc
                        ldy #>str_t_alloc
                        jsr putmsg

                        ldx #8
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc @alloc_fail
                        stx data_brp
                        sty data_brp+1

                        ; Fill BRP with 0,1,2,...,7
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
:                       tya
                        sta (gREG::r5),y
                        iny
                        cpy #8
                        bne :-

                        jsr pass
                        bra @test_create

@alloc_fail:            jsr fail
                        jmp @summary

; ----- Test: Create byte iterator over the BRP -----

@test_create:           ldx #<str_t_create
                        ldy #>str_t_create
                        jsr putmsg

                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::BYTE)
                        ldx data_brp
                        ldy data_brp+1
                        jsr ulitr_create
                        bcc @create_fail
                        stx iter
                        sty iter+1

                        jsr pass
                        bra @test_atstart

@create_fail:           jsr fail
                        jmp @summary

; ----- Test: atstart is true initially -----

@test_atstart:          ldx #<str_t_atstart
                        ldy #>str_t_atstart
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_atstart
                        beq :+
                        jsr fail
                        bra @test_notatend
:                       jsr pass

; ----- Test: atend is false initially -----

@test_notatend:         ldx #<str_t_notatend
                        ldy #>str_t_notatend
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_atend
                        bne :+
                        jsr fail
                        bra @test_fwd
:                       jsr pass

; ----- Test: fetch_and_inc through all 8 bytes -----

@test_fwd:              ldx #<str_t_fwd
                        ldy #>str_t_fwd
                        jsr putmsg

                        stz fwd_idx
                        stz fwd_errs
@fwd_loop:              ldx iter
                        ldy iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @fwd_err
                        cmp fwd_idx
                        beq @fwd_next
@fwd_err:               inc fwd_errs
@fwd_next:              inc fwd_idx
                        lda fwd_idx
                        cmp #8
                        bne @fwd_loop

                        lda fwd_errs
                        beq :+
                        jsr fail
                        bra @test_atend
:                       jsr pass

; ----- Test: atend is true after iterating all bytes -----

@test_atend:            ldx #<str_t_atend
                        ldy #>str_t_atend
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_atend
                        beq :+
                        jsr fail
                        bra @test_fai_end
:                       jsr pass

; ----- Test: fetch_and_inc at end returns carry set -----

@test_fai_end:          ldx #<str_t_fai_end
                        ldy #>str_t_fai_end
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch_and_inc
                        bcs :+
                        jsr fail
                        bra @test_dec
:                       jsr pass

; ----- Test: dec 8 times back to start -----

@test_dec:              ldx #<str_t_dec
                        ldy #>str_t_dec
                        jsr putmsg

                        lda #8
                        sta fwd_idx
                        stz fwd_errs
@dec_loop:              ldx iter
                        ldy iter+1
                        jsr ulitr_dec
                        bcs @dec_err
                        dec fwd_idx
                        bne @dec_loop
                        bra @dec_check
@dec_err:               inc fwd_errs
                        dec fwd_idx
                        bne @dec_loop

@dec_check:             ; Verify we're at start
                        ldx iter
                        ldy iter+1
                        jsr ulitr_atstart
                        bne @dec_fail
                        lda fwd_errs
                        bne @dec_fail
                        jsr pass
                        bra @test_dec_start

@dec_fail:              jsr fail

; ----- Test: dec at start returns carry set -----

@test_dec_start:        ldx #<str_t_dec_start
                        ldy #>str_t_dec_start
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_dec
                        bcs :+
                        jsr fail
                        bra @test_store
:                       jsr pass

; ----- Test: store a byte and read it back -----

@test_store:            ldx #<str_t_store
                        ldy #>str_t_store
                        jsr putmsg

                        ; Store $42 at position 0
                        lda #$42
                        ldx iter
                        ldy iter+1
                        jsr ulitr_store
                        bcs @store_fail

                        ; Read it back
                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @store_fail
                        cmp #$42
                        bne @store_fail

                        ; Restore original value (0)
                        lda #$00
                        ldx iter
                        ldy iter+1
                        jsr ulitr_store

                        jsr pass
                        bra @test_adv

@store_fail:            jsr fail

; ----- Test: adv 4, then fetch should return 4 -----

@test_adv:              ldx #<str_t_adv
                        ldy #>str_t_adv
                        jsr putmsg

                        lda #4
                        ldx iter
                        ldy iter+1
                        jsr ulitr_adv

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @adv_fail
                        cmp #4
                        bne @adv_fail

                        jsr pass
                        bra @test_rew

@adv_fail:              jsr fail

; ----- Test: rew 4, then fetch should return 0 -----

@test_rew:              ldx #<str_t_rew
                        ldy #>str_t_rew
                        jsr putmsg

                        lda #4
                        ldx iter
                        ldy iter+1
                        jsr ulitr_rew

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @rew_fail
                        cmp #0
                        bne @rew_fail

                        ; Should be back at start
                        ldx iter
                        ldy iter+1
                        jsr ulitr_atstart
                        bne @rew_fail

                        jsr pass
                        bra @test_delete

@rew_fail:              jsr fail

; ----- Test: delete iterator and free BRP -----

@test_delete:           ldx #<str_t_delete
                        ldy #>str_t_delete
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_delete

                        ldx data_brp
                        ldy data_brp+1
                        jsr ulmem_free

                        jsr pass

; ----- Summary -----

@summary:               jsr newline
                        ldx #<str_summary
                        ldy #>str_summary
                        jsr putmsg
                        lda num_passed
                        jsr puthex
                        ldx #<str_of
                        ldy #>str_of
                        jsr putmsg
                        lda num_total
                        jsr puthex

                        jsr ulwin_refresh

@loop:                  bra @loop

; =========================================================================
; BSS
; =========================================================================

.bss

win:            .res 1          ; test window handle
titlebrp:       .res 2          ; title string BRP
data_brp:       .res 2          ; test data BRP
iter:           .res 2          ; iterator handle
fwd_idx:        .res 1          ; loop counter
fwd_errs:       .res 1          ; error counter
num_passed:     .res 1          ; total tests passed
num_total:      .res 1          ; total tests run
