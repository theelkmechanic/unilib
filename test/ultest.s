.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

.import __BSS_RUN__, __BSS_SIZE__

EMU_STDOUT = $9FBB      ; emulator host stdout register

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

; BRP+WORD tests
str_t_wc:       .byte "BRP+WORD create       ", 0
str_t_ws:       .byte "BRP+WORD store $BEEF  ", 0
str_t_wf:       .byte "BRP+WORD fetch verify ", 0
str_t_wi:       .byte "BRP+WORD fai x4+atend ", 0
str_t_wd:       .byte "BRP+WORD dec to start ", 0

; MEM+BYTE tests
str_t_mc:       .byte "MEM+BYTE create       ", 0
str_t_mf:       .byte "MEM+BYTE fetch data   ", 0
str_t_ms:       .byte "MEM+BYTE store+verify ", 0
str_t_mi:       .byte "MEM+BYTE iter to end  ", 0

; VRAM+BYTE tests
str_t_vc:       .byte "VRAM+BYTE create      ", 0
str_t_vs:       .byte "VRAM+BYTE store byte  ", 0
str_t_vf:       .byte "VRAM+BYTE fetch verify", 0
str_t_vi:       .byte "VRAM+BYTE iter to end ", 0

; BRP+BYTE+REVERSE tests
str_t_rc:       .byte "REVERSE create        ", 0
str_t_rf:       .byte "REVERSE first fetch=7 ", 0
str_t_ri:       .byte "REVERSE fai x8 (7..0) ", 0
str_t_ra:       .byte "REVERSE atend         ", 0
str_t_rd:       .byte "REVERSE dec to start  ", 0

; VRAM+DWORD tests
str_t_dc:       .byte "VRAM+DWORD create     ", 0
str_t_ds:       .byte "VRAM+DWORD store      ", 0
str_t_df:       .byte "VRAM+DWORD fetch      ", 0

; Data block tests
str_t_dbc:      .byte "uldb_create size=8    ", 0
str_t_dbrc:     .byte "uldb_getrefcount = 1  ", 0
str_t_dbs:      .byte "uldb_getsize = 8      ", 0
str_t_dbb:      .byte "uldb_getbrp non-zero  ", 0
str_t_dba:      .byte "uldb_addref rc=2      ", 0
str_t_dbr1:     .byte "uldb_release 2->1     ", 0
str_t_dbr0:     .byte "uldb_release 1->0     ", 0
str_t_dbfb:     .byte "uldb_fromBuffer       ", 0
str_t_dbfi:     .byte "uldb_fromIter         ", 0

; Blocklist tests
str_t_llc:      .byte "ullist_create empty    ", 0
str_t_llrc:     .byte "ullist_getrefcount = 1 ", 0
str_t_lls:      .byte "ullist_getsize = 0     ", 0
str_t_lli:      .byte "ullist_insert append   ", 0
str_t_llg:      .byte "ullist_getat pos 0     ", 0
str_t_lli2:     .byte "ullist_insert 2nd end  ", 0
str_t_lli0:     .byte "ullist_insert at 0     ", 0
str_t_llo:      .byte "ullist_getat order     ", 0
str_t_lld:      .byte "ullist_delete middle   ", 0
str_t_llar:     .byte "ullist_addref rc=2     ", 0
str_t_llr1:     .byte "ullist_release 2->1    ", 0
str_t_llr0:     .byte "ullist_release 1->0    ", 0
str_t_llci:     .byte "ullist_create w/init   ", 0

; LIST iterator tests
str_t_lic:      .byte "LIST+BYTE create       ", 0
str_t_lis:      .byte "LIST atstart           ", 0
str_t_lif:      .byte "LIST fai x8 seamless   ", 0
str_t_lie:      .byte "LIST atend             ", 0
str_t_lid:      .byte "LIST dec x8 to start   ", 0
str_t_lidf:     .byte "LIST fetch after dec   ", 0
str_t_lia:      .byte "LIST adv 6, fetch=$22  ", 0
str_t_lir:      .byte "LIST rew 6, fetch=$10  ", 0

str_pass:       .byte " OK", 0
str_fail:       .byte " FAIL", 0
str_summary:    .byte "Passed: ", 0
str_of:         .byte " of ", 0
str_pad:        .byte "          ", 0
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
                        sta EMU_STDOUT
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
                        sta EMU_STDOUT
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        lda win
                        jsr ulwin_putchar
                        pla
                        and #$0f
                        tax
                        lda @hexchars,x
                        sta EMU_STDOUT
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        lda win
                        jmp ulwin_putchar
@hexchars:              .byte "0123456789ABCDEF"
.endproc

; putdec - Write A as unsigned decimal (0-255) to the test window
;   In: A = byte value
.proc putdec
                        ; Convert to BCD using decimal mode
                        sed
                        stz bcd_tmp
                        stz bcd_tmp+1
                        ldx #8
@cvt:                   asl
                        pha
                        lda bcd_tmp+1
                        adc bcd_tmp+1
                        sta bcd_tmp+1
                        lda bcd_tmp
                        adc bcd_tmp
                        sta bcd_tmp
                        pla
                        dex
                        bne @cvt
                        cld
                        ; bcd_tmp low nibble = hundreds (0-2)
                        ; bcd_tmp+1 high nibble = tens, low nibble = ones
                        ldy #0          ; Y=0: still suppressing leading zeros
                        lda bcd_tmp
                        and #$0f
                        beq @tens
                        jsr @emit
                        ldy #1
@tens:                  lda bcd_tmp+1
                        lsr
                        lsr
                        lsr
                        lsr
                        bne :+
                        cpy #0
                        beq @ones
:                       jsr @emit
@ones:                  lda bcd_tmp+1
                        and #$0f
@emit:                  ora #$30
                        sta EMU_STDOUT
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        pha
                        lda win
                        jsr ulwin_putchar
                        pla
                        rts
.endproc

; newline - Advance cursor to the start of the next line, scroll if at bottom
.proc newline
                        lda #$0A
                        sta EMU_STDOUT
                        lda win
                        jsr ulwin_getline
                        cmp #27                 ; last line of 28-line window
                        bcc @no_scroll
                        ; Scroll window contents up 1 line (Y=-1 moves content up)
                        lda win
                        ldx #0
                        ldy #$ff
                        jsr ulwin_scroll
                        ldy #27
                        ldx #0
                        lda win
                        jmp ulwin_putcursor
@no_scroll:             ina
                        tay
                        ldx #0
                        lda win
                        jmp ulwin_putcursor
.endproc

; delay_and_refresh - Refresh the screen and wait ~20ms (1 frame at 60Hz)
.proc delay_and_refresh
                        jmp ulwin_refresh
.endproc

; pass - Print " OK" and increment pass counter
.proc pass
                        inc num_passed
                        inc num_total
                        ldx #<str_pass
                        ldy #>str_pass
                        jsr putmsg
                        jsr newline
                        jmp delay_and_refresh
.endproc

; fail - Print " FAIL" and increment fail counter
.proc fail
                        inc num_total
                        ldx #<str_fail
                        ldy #>str_fail
                        jsr putmsg
                        jsr newline
                        jmp delay_and_refresh
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

                        ; Open test window: position (1,1), size 78x40, white on blue, border
                        lda #1
                        sta gREG::r0L
                        sta gREG::r0H
                        lda #78
                        sta gREG::r1L
                        lda #28
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

; =========================================================================
; BRP+WORD tests
; =========================================================================

; ----- Test: Create BRP+WORD iterator -----

@test_wc:               ldx #<str_t_wc
                        ldy #>str_t_wc
                        jsr putmsg

                        ; Allocate 8-byte BRP (4 words)
                        ldx #8
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc @wc_fail
                        stx data_brp
                        sty data_brp+1

                        ; Create WORD iterator
                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::WORD)
                        ldx data_brp
                        ldy data_brp+1
                        jsr ulitr_create
                        bcc @wc_fail
                        stx iter
                        sty iter+1

                        jsr pass
                        bra @test_ws

@wc_fail:               jsr fail
                        jmp @test_mc

; ----- Test: Store $BEEF via r0 -----

@test_ws:               ldx #<str_t_ws
                        ldy #>str_t_ws
                        jsr putmsg

                        lda #$EF
                        sta gREG::r0L
                        lda #$BE
                        sta gREG::r0H
                        lda #0              ; A ignored for WORD
                        ldx iter
                        ldy iter+1
                        jsr ulitr_store
                        bcs @ws_fail

                        jsr pass
                        bra @test_wf

@ws_fail:               jsr fail

; ----- Test: Fetch and verify r0 = $BEEF -----

@test_wf:               ldx #<str_t_wf
                        ldy #>str_t_wf
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @wf_fail
                        lda gREG::r0L
                        cmp #$EF
                        bne @wf_fail
                        lda gREG::r0H
                        cmp #$BE
                        bne @wf_fail

                        jsr pass
                        bra @test_wi

@wf_fail:               jsr fail

; ----- Test: fetch_and_inc x4, verify atend -----

@test_wi:               ldx #<str_t_wi
                        ldy #>str_t_wi
                        jsr putmsg

                        stz fwd_errs
                        lda #4
                        sta fwd_idx
@wi_loop:               ldx iter
                        ldy iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @wi_err
                        dec fwd_idx
                        bne @wi_loop
                        bra @wi_check
@wi_err:                inc fwd_errs
                        dec fwd_idx
                        bne @wi_loop

@wi_check:              ; Should be at end
                        ldx iter
                        ldy iter+1
                        jsr ulitr_atend
                        bne @wi_fail
                        lda fwd_errs
                        bne @wi_fail

                        jsr pass
                        bra @test_wd

@wi_fail:               jsr fail

; ----- Test: dec x4 back to start -----

@test_wd:               ldx #<str_t_wd
                        ldy #>str_t_wd
                        jsr putmsg

                        lda #4
                        sta fwd_idx
                        stz fwd_errs
@wd_loop:               ldx iter
                        ldy iter+1
                        jsr ulitr_dec
                        bcs @wd_err
                        dec fwd_idx
                        bne @wd_loop
                        bra @wd_check
@wd_err:                inc fwd_errs
                        dec fwd_idx
                        bne @wd_loop

@wd_check:              ldx iter
                        ldy iter+1
                        jsr ulitr_atstart
                        bne @wd_fail
                        lda fwd_errs
                        bne @wd_fail

                        jsr pass
                        bra @word_cleanup

@wd_fail:               jsr fail

@word_cleanup:          ; Delete WORD iterator and free BRP
                        ldx iter
                        ldy iter+1
                        jsr ulitr_delete
                        ldx data_brp
                        ldy data_brp+1
                        jsr ulmem_free

; =========================================================================
; MEM+BYTE tests
; =========================================================================

; ----- Test: Create MEM+BYTE iterator -----

@test_mc:               ldx #<str_t_mc
                        ldy #>str_t_mc
                        jsr putmsg

                        ; Fill mem_buf with 0,1,2,...,7
                        ldx #0
@mem_fill:              txa
                        sta mem_buf,x
                        inx
                        cpx #8
                        bne @mem_fill

                        ; Create MEM iterator over mem_buf
                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::MEM | ULIFMT::BYTE)
                        ldx #<mem_buf
                        ldy #>mem_buf
                        clc                     ; no carry needed for MEM
                        jsr ulitr_create
                        bcc @mc_fail
                        stx iter
                        sty iter+1

                        jsr pass
                        bra @test_mf

@mc_fail:               jsr fail
                        jmp @test_vc

; ----- Test: Fetch first byte, verify = 0 -----

@test_mf:               ldx #<str_t_mf
                        ldy #>str_t_mf
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @mf_fail
                        cmp #0
                        bne @mf_fail

                        jsr pass
                        bra @test_ms

@mf_fail:               jsr fail

; ----- Test: Store $42, readback verify -----

@test_ms:               ldx #<str_t_ms
                        ldy #>str_t_ms
                        jsr putmsg

                        lda #$42
                        ldx iter
                        ldy iter+1
                        jsr ulitr_store
                        bcs @ms_fail

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @ms_fail
                        cmp #$42
                        bne @ms_fail

                        ; Restore original
                        lda #$00
                        ldx iter
                        ldy iter+1
                        jsr ulitr_store

                        jsr pass
                        bra @test_mi

@ms_fail:               jsr fail

; ----- Test: fetch_and_inc x8, verify atend -----

@test_mi:               ldx #<str_t_mi
                        ldy #>str_t_mi
                        jsr putmsg

                        stz fwd_idx
                        stz fwd_errs
@mi_loop:               ldx iter
                        ldy iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @mi_err
                        cmp fwd_idx
                        beq @mi_next
@mi_err:                inc fwd_errs
@mi_next:               inc fwd_idx
                        lda fwd_idx
                        cmp #8
                        bne @mi_loop

                        ldx iter
                        ldy iter+1
                        jsr ulitr_atend
                        bne @mi_fail
                        lda fwd_errs
                        bne @mi_fail

                        jsr pass
                        bra @mem_cleanup

@mi_fail:               jsr fail

@mem_cleanup:           ldx iter
                        ldy iter+1
                        jsr ulitr_delete

; =========================================================================
; VRAM+BYTE tests
; =========================================================================

; ----- Test: Create VRAM+BYTE iterator at $1F000 -----

@test_vc:               ldx #<str_t_vc
                        ldy #>str_t_vc
                        jsr putmsg

                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::VRAM | ULIFMT::BYTE)
                        ldx #$00                ; low byte of $F000
                        ldy #$F0                ; high byte of $F000
                        sec                     ; bit 16 = 1 (address $1F000)
                        jsr ulitr_create
                        bcc @vc_fail
                        stx iter
                        sty iter+1

                        jsr pass
                        bra @test_vs

@vc_fail:               jsr fail
                        jmp @test_rc

; ----- Test: Store $42 at VRAM position -----

@test_vs:               ldx #<str_t_vs
                        ldy #>str_t_vs
                        jsr putmsg

                        lda #$42
                        ldx iter
                        ldy iter+1
                        jsr ulitr_store
                        bcs @vs_fail

                        jsr pass
                        bra @test_vf

@vs_fail:               jsr fail

; ----- Test: Fetch and verify = $42 -----

@test_vf:               ldx #<str_t_vf
                        ldy #>str_t_vf
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @vf_fail
                        cmp #$42
                        bne @vf_fail

                        jsr pass
                        bra @test_vi

@vf_fail:               jsr fail

; ----- Test: iterate to end -----

@test_vi:               ldx #<str_t_vi
                        ldy #>str_t_vi
                        jsr putmsg

                        ; Advance 8 entries to reach end
                        lda #8
                        ldx iter
                        ldy iter+1
                        jsr ulitr_adv

                        ldx iter
                        ldy iter+1
                        jsr ulitr_atend
                        bne @vi_fail
                        ; Also verify fetch fails at end
                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcc @vi_fail

                        jsr pass
                        bra @vram_cleanup

@vi_fail:               jsr fail

@vram_cleanup:          ldx iter
                        ldy iter+1
                        jsr ulitr_delete

; =========================================================================
; BRP+BYTE+REVERSE tests
; =========================================================================

; ----- Test: Create reverse iterator -----

@test_rc:               ldx #<str_t_rc
                        ldy #>str_t_rc
                        jsr putmsg

                        ; Allocate 8-byte BRP and fill with 0-7
                        ldx #8
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc @rc_fail
                        stx data_brp
                        sty data_brp+1

                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
:                       tya
                        sta (gREG::r5),y
                        iny
                        cpy #8
                        bne :-

                        ; Create REVERSE byte iterator
                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULITYP::REVERSE | ULIFMT::BYTE)
                        ldx data_brp
                        ldy data_brp+1
                        jsr ulitr_create
                        bcc @rc_fail
                        stx iter
                        sty iter+1

                        jsr pass
                        bra @test_rf

@rc_fail:               jsr fail
                        jmp @test_dc

; ----- Test: First fetch should return 7 (last byte) -----

@test_rf:               ldx #<str_t_rf
                        ldy #>str_t_rf
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @rf_fail
                        cmp #7
                        bne @rf_fail

                        jsr pass
                        bra @test_ri

@rf_fail:               jsr fail

; ----- Test: fetch_and_inc x8 yields 7,6,5,4,3,2,1,0 -----

@test_ri:               ldx #<str_t_ri
                        ldy #>str_t_ri
                        jsr putmsg

                        lda #7
                        sta fwd_idx             ; expected value starts at 7
                        stz fwd_errs
@ri_loop:               ldx iter
                        ldy iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @ri_err
                        cmp fwd_idx
                        beq @ri_next
@ri_err:                inc fwd_errs
@ri_next:               dec fwd_idx             ; next expected value
                        lda fwd_idx
                        cmp #$FF                ; went past 0?
                        bne @ri_loop

                        lda fwd_errs
                        beq :+
                        jsr fail
                        bra @test_ra
:                       jsr pass

; ----- Test: atend after reverse iteration -----

@test_ra:               ldx #<str_t_ra
                        ldy #>str_t_ra
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_atend
                        beq :+
                        jsr fail
                        bra @test_rd
:                       jsr pass

; ----- Test: dec x8 back to start -----

@test_rd:               ldx #<str_t_rd
                        ldy #>str_t_rd
                        jsr putmsg

                        lda #8
                        sta fwd_idx
                        stz fwd_errs
@rd_loop:               ldx iter
                        ldy iter+1
                        jsr ulitr_dec
                        bcs @rd_err
                        dec fwd_idx
                        bne @rd_loop
                        bra @rd_check
@rd_err:                inc fwd_errs
                        dec fwd_idx
                        bne @rd_loop

@rd_check:              ldx iter
                        ldy iter+1
                        jsr ulitr_atstart
                        bne @rd_fail
                        lda fwd_errs
                        bne @rd_fail

                        jsr pass
                        bra @rev_cleanup

@rd_fail:               jsr fail

@rev_cleanup:           ldx iter
                        ldy iter+1
                        jsr ulitr_delete
                        ldx data_brp
                        ldy data_brp+1
                        jsr ulmem_free

; =========================================================================
; VRAM+DWORD tests
; =========================================================================

; ----- Test: Create VRAM+DWORD iterator -----

@test_dc:               ldx #<str_t_dc
                        ldy #>str_t_dc
                        jsr putmsg

                        lda #16                 ; 4 dwords = 16 bytes
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::VRAM | ULIFMT::DWORD)
                        ldx #$00                ; low byte of $F000
                        ldy #$F0                ; high byte of $F000
                        sec                     ; bit 16 = 1 (address $1F000)
                        jsr ulitr_create
                        bcc @dc_fail
                        stx iter
                        sty iter+1

                        jsr pass
                        bra @test_ds

@dc_fail:               jsr fail
                        jmp @summary

; ----- Test: Store $DEADBEEF via r0/r1 -----

@test_ds:               ldx #<str_t_ds
                        ldy #>str_t_ds
                        jsr putmsg

                        ; DWORD in little-endian: $EF, $BE, $AD, $DE
                        lda #$EF
                        sta gREG::r0L
                        lda #$BE
                        sta gREG::r0H
                        lda #$AD
                        sta gREG::r1L
                        lda #$DE
                        sta gREG::r1H
                        lda #0                  ; A ignored for DWORD
                        ldx iter
                        ldy iter+1
                        jsr ulitr_store
                        bcs @ds_fail

                        jsr pass
                        bra @test_df

@ds_fail:               jsr fail

; ----- Test: Fetch and verify $DEADBEEF -----

@test_df:               ldx #<str_t_df
                        ldy #>str_t_df
                        jsr putmsg

                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcs @df_fail
                        lda gREG::r0L
                        cmp #$EF
                        bne @df_fail
                        lda gREG::r0H
                        cmp #$BE
                        bne @df_fail
                        lda gREG::r1L
                        cmp #$AD
                        bne @df_fail
                        lda gREG::r1H
                        cmp #$DE
                        bne @df_fail

                        jsr pass
                        bra @dword_cleanup

@df_fail:               jsr fail

@dword_cleanup:         ldx iter
                        ldy iter+1
                        jsr ulitr_delete

; =========================================================================
; Data block tests
; =========================================================================

; ----- Test: uldb_create with size 8 -----

@test_db_create:        ldx #<str_t_dbc
                        ldy #>str_t_dbc
                        jsr putmsg

                        ldx #8
                        ldy #0
                        jsr uldb_create
                        bcc @dbc_fail
                        stx db_handle
                        sty db_handle+1

                        ; Verify handle is non-zero
                        txa
                        ora db_handle+1
                        beq @dbc_fail

                        jsr pass
                        bra @test_db_refcount

@dbc_fail:              jsr fail
                        jmp @summary

; ----- Test: uldb_getrefcount = 1 -----

@test_db_refcount:      ldx #<str_t_dbrc
                        ldy #>str_t_dbrc
                        jsr putmsg

                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_getrefcount
                        cpx #1
                        bne @dbrc_fail
                        cpy #0
                        bne @dbrc_fail

                        jsr pass
                        bra @test_db_size

@dbrc_fail:             jsr fail

; ----- Test: uldb_getsize = 8 -----

@test_db_size:          ldx #<str_t_dbs
                        ldy #>str_t_dbs
                        jsr putmsg

                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_getsize
                        cpx #8
                        bne @dbs_fail
                        cpy #0
                        bne @dbs_fail

                        jsr pass
                        bra @test_db_brp

@dbs_fail:              jsr fail

; ----- Test: uldb_getbrp is non-zero -----

@test_db_brp:           ldx #<str_t_dbb
                        ldy #>str_t_dbb
                        jsr putmsg

                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_getbrp
                        stx db_data_brp
                        sty db_data_brp+1

                        txa
                        ora db_data_brp+1
                        beq @dbb_fail

                        jsr pass
                        bra @test_db_addref

@dbb_fail:              jsr fail

; ----- Test: uldb_addref, refcount = 2 -----

@test_db_addref:        ldx #<str_t_dba
                        ldy #>str_t_dba
                        jsr putmsg

                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_addref

                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_getrefcount
                        cpx #2
                        bne @dba_fail
                        cpy #0
                        bne @dba_fail

                        jsr pass
                        bra @test_db_rel1

@dba_fail:              jsr fail

; ----- Test: uldb_release (2 -> 1) -----

@test_db_rel1:          ldx #<str_t_dbr1
                        ldy #>str_t_dbr1
                        jsr putmsg

                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_release

                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_getrefcount
                        cpx #1
                        bne @dbr1_fail
                        cpy #0
                        bne @dbr1_fail

                        jsr pass
                        bra @test_db_rel0

@dbr1_fail:             jsr fail

; ----- Test: uldb_release to zero (1 -> 0, frees) -----

@test_db_rel0:          ldx #<str_t_dbr0
                        ldy #>str_t_dbr0
                        jsr putmsg

                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_release

                        ; If we get here without crashing, it passed
                        jsr pass
                        bra @test_db_frombuf

@dbr0_fail:             jsr fail

; ----- Test: uldb_fromBuffer -----

@test_db_frombuf:       ldx #<str_t_dbfb
                        ldy #>str_t_dbfb
                        jsr putmsg

                        ; Fill db_testdata with known pattern
                        ldx #0
@fb_fill:               txa
                        clc
                        adc #$10
                        sta db_testdata,x
                        inx
                        cpx #8
                        bne @fb_fill

                        ; Create data block from buffer
                        lda #<db_testdata
                        sta gREG::r0L
                        lda #>db_testdata
                        sta gREG::r0H
                        lda #8
                        sta gREG::r1L
                        stz gREG::r1H
                        jsr uldb_fromBuffer
                        bcc @dbfb_fail
                        stx db_handle
                        sty db_handle+1

                        ; Get data BRP and verify contents
                        jsr uldb_getbrp
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H

                        stz fwd_errs
                        ldy #0
@fb_check:              lda (gREG::r5),y
                        sta fwd_idx             ; temp: actual value
                        tya
                        clc
                        adc #$10                ; expected = y + $10
                        cmp fwd_idx
                        beq :+
                        inc fwd_errs
:                       iny
                        cpy #8
                        bne @fb_check

                        lda fwd_errs
                        bne @dbfb_fail

                        ; Clean up: release the data block
                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_release

                        jsr pass
                        bra @test_db_fromiter

@dbfb_fail:             jsr fail

; ----- Test: uldb_fromIter -----

@test_db_fromiter:      ldx #<str_t_dbfi
                        ldy #>str_t_dbfi
                        jsr putmsg

                        ; Allocate a BRP and fill with known data
                        ldx #8
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcs :+
                        jmp @dbfi_fail
:                       stx db_data_brp
                        sty db_data_brp+1

                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
:                       tya
                        eor #$AA                ; pattern: 0^AA, 1^AA, ...
                        sta (gREG::r5),y
                        iny
                        cpy #8
                        bne :-

                        ; Create a BRP+BYTE iterator over this data
                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::BYTE)
                        ldx db_data_brp
                        ldy db_data_brp+1
                        jsr ulitr_create
                        bcs :+
                        jmp @dbfi_fail
:
                        stx iter
                        sty iter+1

                        ; Create data block from iterator
                        lda iter
                        sta gREG::r0L
                        lda iter+1
                        sta gREG::r0H
                        lda #8
                        sta gREG::r1L
                        stz gREG::r1H
                        jsr uldb_fromIter
                        bcs :+
                        jmp @dbfi_fail
:                       stx db_handle
                        sty db_handle+1

                        ; Get data BRP from new data block and verify contents
                        jsr uldb_getbrp
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H

                        stz fwd_errs
                        ldy #0
@fi_check:              lda (gREG::r5),y
                        sta fwd_idx             ; temp: actual value
                        tya
                        eor #$AA                ; expected = y ^ $AA
                        cmp fwd_idx
                        beq :+
                        inc fwd_errs
:                       iny
                        cpy #8
                        bne @fi_check

                        lda fwd_errs
                        beq @fi_ok
                        jmp @dbfi_fail

@fi_ok:                 ; Clean up
                        ldx iter
                        ldy iter+1
                        jsr ulitr_delete
                        ldx db_data_brp
                        ldy db_data_brp+1
                        jsr ulmem_free
                        ldx db_handle
                        ldy db_handle+1
                        jsr uldb_release

                        jsr pass
                        jmp @test_ll_create

@dbfi_fail:             jsr fail

; =========================================================================
; Blocklist tests
; =========================================================================

; ----- Test: ullist_create (empty) -----

@test_ll_create:        ldx #<str_t_llc
                        ldy #>str_t_llc
                        jsr putmsg

                        ldx #0
                        ldy #0
                        jsr ullist_create
                        bcc @llc_fail
                        stx ll_handle
                        sty ll_handle+1

                        ; Verify handle non-zero
                        txa
                        ora ll_handle+1
                        beq @llc_fail

                        jsr pass
                        bra @test_ll_refcount

@llc_fail:              jsr fail
                        jmp @summary

; ----- Test: ullist_getrefcount = 1 -----

@test_ll_refcount:      ldx #<str_t_llrc
                        ldy #>str_t_llrc
                        jsr putmsg

                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getrefcount
                        cpx #1
                        bne @llrc_fail
                        cpy #0
                        bne @llrc_fail

                        jsr pass
                        bra @test_ll_size

@llrc_fail:             jsr fail

; ----- Test: ullist_getsize = 0 -----

@test_ll_size:          ldx #<str_t_lls
                        ldy #>str_t_lls
                        jsr putmsg

                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getsize
                        cpx #0
                        bne @lls_fail
                        cpy #0
                        bne @lls_fail

                        jsr pass
                        bra @test_ll_ins1

@lls_fail:              jsr fail

; ----- Test: ullist_insert (append) -----

@test_ll_ins1:          ldx #<str_t_lli
                        ldy #>str_t_lli
                        jsr putmsg

                        ; Create a data block for testing
                        ldx #8
                        ldy #0
                        jsr uldb_create
                        bcc @lli_fail
                        stx ll_db1
                        sty ll_db1+1

                        ; Insert at end (255)
                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        ldx ll_db1
                        ldy ll_db1+1
                        lda #255
                        jsr ullist_insert
                        bcc @lli_fail

                        ; Verify size = 1
                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getsize
                        cpx #1
                        bne @lli_fail
                        cpy #0
                        bne @lli_fail

                        jsr pass
                        bra @test_ll_getat

@lli_fail:              jsr fail
                        jmp @summary

; ----- Test: ullist_getat position 0 -----

@test_ll_getat:         ldx #<str_t_llg
                        ldy #>str_t_llg
                        jsr putmsg

                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        lda #0
                        jsr ullist_getat
                        bcc @llg_fail
                        cpx ll_db1
                        bne @llg_fail
                        cpy ll_db1+1
                        bne @llg_fail

                        jsr pass
                        bra @test_ll_ins2

@llg_fail:              jsr fail

; ----- Test: ullist_insert (second at end) -----

@test_ll_ins2:          ldx #<str_t_lli2
                        ldy #>str_t_lli2
                        jsr putmsg

                        ; Create second data block
                        ldx #8
                        ldy #0
                        jsr uldb_create
                        bcc @lli2_fail
                        stx ll_db2
                        sty ll_db2+1

                        ; Insert at end
                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        ldx ll_db2
                        ldy ll_db2+1
                        lda #255
                        jsr ullist_insert
                        bcc @lli2_fail

                        ; Verify size = 2
                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getsize
                        cpx #2
                        bne @lli2_fail

                        jsr pass
                        bra @test_ll_ins0

@lli2_fail:             jsr fail

; ----- Test: ullist_insert at position 0 -----

@test_ll_ins0:          ldx #<str_t_lli0
                        ldy #>str_t_lli0
                        jsr putmsg

                        ; Create third data block
                        ldx #8
                        ldy #0
                        jsr uldb_create
                        bcc @lli0_fail
                        stx ll_db3
                        sty ll_db3+1

                        ; Insert at position 0
                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        ldx ll_db3
                        ldy ll_db3+1
                        lda #0
                        jsr ullist_insert
                        bcc @lli0_fail

                        ; Verify size = 3
                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getsize
                        cpx #3
                        bne @lli0_fail

                        jsr pass
                        bra @test_ll_order

@lli0_fail:             jsr fail

; ----- Test: ullist_getat order check -----
; After inserting db3 at 0, order should be: db3, db1, db2

@test_ll_order:         ldx #<str_t_llo
                        ldy #>str_t_llo
                        jsr putmsg

                        stz fwd_errs

                        ; Position 0 should be db3
                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        lda #0
                        jsr ullist_getat
                        bcc @llo_err
                        cpx ll_db3
                        bne @llo_err
                        cpy ll_db3+1
                        beq :+
@llo_err:               inc fwd_errs

                        ; Position 1 should be db1
:                       lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        lda #1
                        jsr ullist_getat
                        bcc @llo_err2
                        cpx ll_db1
                        bne @llo_err2
                        cpy ll_db1+1
                        beq :+
@llo_err2:              inc fwd_errs

                        ; Position 2 should be db2
:                       lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        lda #2
                        jsr ullist_getat
                        bcc @llo_err3
                        cpx ll_db2
                        bne @llo_err3
                        cpy ll_db2+1
                        beq :+
@llo_err3:              inc fwd_errs

:                       lda fwd_errs
                        bne @llo_fail
                        jsr pass
                        bra @test_ll_del

@llo_fail:              jsr fail

; ----- Test: ullist_delete (middle, position 1 = db1) -----
; Order before: db3, db1, db2. After delete pos 1: db3, db2

@test_ll_del:           ldx #<str_t_lld
                        ldy #>str_t_lld
                        jsr putmsg

                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        lda #1
                        jsr ullist_delete
                        bcc @lld_fail

                        ; Verify size = 2
                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getsize
                        cpx #2
                        bne @lld_fail

                        ; Verify order: pos 0 = db3, pos 1 = db2
                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        lda #0
                        jsr ullist_getat
                        cpx ll_db3
                        bne @lld_fail
                        cpy ll_db3+1
                        bne @lld_fail

                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        lda #1
                        jsr ullist_getat
                        cpx ll_db2
                        bne @lld_fail
                        cpy ll_db2+1
                        bne @lld_fail

                        jsr pass
                        bra @test_ll_addref

@lld_fail:              jsr fail

; ----- Test: ullist_addref, refcount = 2 -----

@test_ll_addref:        ldx #<str_t_llar
                        ldy #>str_t_llar
                        jsr putmsg

                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_addref

                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getrefcount
                        cpx #2
                        bne @llar_fail
                        cpy #0
                        bne @llar_fail

                        jsr pass
                        bra @test_ll_rel1

@llar_fail:             jsr fail

; ----- Test: ullist_release (2 -> 1) -----

@test_ll_rel1:          ldx #<str_t_llr1
                        ldy #>str_t_llr1
                        jsr putmsg

                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_release

                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getrefcount
                        cpx #1
                        bne @llr1_fail
                        cpy #0
                        bne @llr1_fail

                        jsr pass
                        bra @test_ll_rel0

@llr1_fail:             jsr fail

; ----- Test: ullist_release (1 -> 0, frees) -----

@test_ll_rel0:          ldx #<str_t_llr0
                        ldy #>str_t_llr0
                        jsr putmsg

                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_release

                        ; If we get here without crashing, it passed
                        jsr pass
                        bra @test_ll_create_init

; ----- Test: ullist_create with initial handle -----

@test_ll_create_init:   ldx #<str_t_llci
                        ldy #>str_t_llci
                        jsr putmsg

                        ; Create a data block for initial
                        ldx #8
                        ldy #0
                        jsr uldb_create
                        bcc @llci_fail
                        stx ll_db1
                        sty ll_db1+1

                        ; Create list with initial handle
                        ldx ll_db1
                        ldy ll_db1+1
                        jsr ullist_create
                        bcc @llci_fail
                        stx ll_handle
                        sty ll_handle+1

                        ; Verify size = 1
                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_getsize
                        cpx #1
                        bne @llci_fail

                        ; Verify getat 0 = initial handle
                        lda ll_handle
                        sta gREG::r0L
                        lda ll_handle+1
                        sta gREG::r0H
                        lda #0
                        jsr ullist_getat
                        bcc @llci_fail
                        cpx ll_db1
                        bne @llci_fail
                        cpy ll_db1+1
                        bne @llci_fail

                        ; Clean up
                        ldx ll_handle
                        ldy ll_handle+1
                        jsr ullist_release
                        ldx ll_db1
                        ldy ll_db1+1
                        jsr uldb_release

                        jsr pass
                        jmp @test_li_setup

@llci_fail:             jsr fail

; =========================================================================
; LIST iterator tests
; =========================================================================

                        ; --- Setup: create 2 data blocks with distinct patterns ---
@test_li_setup:
                        ; Create data block A (4 bytes: $10, $11, $12, $13)
                        ldx #4
                        ldy #0
                        jsr uldb_create
                        bcs :+
                        jmp @summary
:                       stx li_db_a
                        sty li_db_a+1

                        ; Fill block A data
                        jsr uldb_getbrp
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda #$10
                        sta (gREG::r5),y
                        iny
                        lda #$11
                        sta (gREG::r5),y
                        iny
                        lda #$12
                        sta (gREG::r5),y
                        iny
                        lda #$13
                        sta (gREG::r5),y

                        ; Create data block B (4 bytes: $20, $21, $22, $23)
                        ldx #4
                        ldy #0
                        jsr uldb_create
                        bcs :+
                        jmp @summary
:                       stx li_db_b
                        sty li_db_b+1

                        ; Fill block B data
                        jsr uldb_getbrp
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda #$20
                        sta (gREG::r5),y
                        iny
                        lda #$21
                        sta (gREG::r5),y
                        iny
                        lda #$22
                        sta (gREG::r5),y
                        iny
                        lda #$23
                        sta (gREG::r5),y

                        ; Create blocklist with A then B
                        ldx li_db_a
                        ldy li_db_a+1
                        jsr ullist_create       ; create with A as initial
                        bcs :+
                        jmp @summary
:                       stx li_list
                        sty li_list+1

                        ; Insert B at end
                        lda li_list
                        sta gREG::r0L
                        lda li_list+1
                        sta gREG::r0H
                        ldx li_db_b
                        ldy li_db_b+1
                        lda #255                ; append at end
                        jsr ullist_insert

; ----- Test: LIST+BYTE create -----

@test_lic:              ldx #<str_t_lic
                        ldy #>str_t_lic
                        jsr putmsg

                        stz gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::LIST | ULIFMT::BYTE)
                        ldx li_list
                        ldy li_list+1
                        jsr ulitr_create
                        bcc @lic_fail
                        stx li_handle
                        sty li_handle+1

                        ; Verify handle non-zero
                        txa
                        ora li_handle+1
                        beq @lic_fail

                        jsr pass
                        bra @test_lis

@lic_fail:              jsr fail
                        jmp @li_cleanup

; ----- Test: LIST atstart -----

@test_lis:              ldx #<str_t_lis
                        ldy #>str_t_lis
                        jsr putmsg

                        ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_atstart
                        beq :+
                        jsr fail
                        bra @test_lif
:                       jsr pass

; ----- Test: LIST fetch_and_inc x8 seamless -----

@test_lif:              ldx #<str_t_lif
                        ldy #>str_t_lif
                        jsr putmsg

                        stz fwd_errs
                        ; Expected values: $10,$11,$12,$13,$20,$21,$22,$23
                        lda #0
                        sta fwd_idx             ; loop counter
@lif_loop:              ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_fetch_and_inc
                        bcs @lif_err
                        ; Compute expected: idx < 4 ? $10+idx : $20+(idx-4)
                        sta gREG::r5L           ; save actual
                        lda fwd_idx
                        cmp #4
                        bcs @lif_block_b
                        clc
                        adc #$10                ; expected = $10 + idx
                        bra @lif_cmp
@lif_block_b:           sec
                        sbc #4
                        clc
                        adc #$20                ; expected = $20 + (idx-4)
@lif_cmp:               cmp gREG::r5L
                        beq @lif_next
@lif_err:               inc fwd_errs
@lif_next:              inc fwd_idx
                        lda fwd_idx
                        cmp #8
                        bne @lif_loop

                        lda fwd_errs
                        beq :+
                        jsr fail
                        bra @test_lie
:                       jsr pass

; ----- Test: LIST atend -----

@test_lie:              ldx #<str_t_lie
                        ldy #>str_t_lie
                        jsr putmsg

                        ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_atend
                        beq :+
                        jsr fail
                        bra @test_lid
:                       jsr pass

; ----- Test: LIST dec x8 back to start -----

@test_lid:              ldx #<str_t_lid
                        ldy #>str_t_lid
                        jsr putmsg

                        lda #8
                        sta fwd_idx
                        stz fwd_errs
@lid_loop:              ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_dec
                        bcs @lid_err
                        dec fwd_idx
                        bne @lid_loop
                        bra @lid_check
@lid_err:               inc fwd_errs
                        dec fwd_idx
                        bne @lid_loop

@lid_check:             ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_atstart
                        bne @lid_fail
                        lda fwd_errs
                        bne @lid_fail
                        jsr pass
                        bra @test_lidf

@lid_fail:              jsr fail

; ----- Test: LIST fetch after dec returns $10 -----

@test_lidf:             ldx #<str_t_lidf
                        ldy #>str_t_lidf
                        jsr putmsg

                        ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_fetch
                        bcs @lidf_fail
                        cmp #$10
                        bne @lidf_fail

                        jsr pass
                        bra @test_lia

@lidf_fail:             jsr fail

; ----- Test: LIST adv 6, fetch = $22 -----

@test_lia:              ldx #<str_t_lia
                        ldy #>str_t_lia
                        jsr putmsg

                        lda #6
                        ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_adv

                        ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_fetch
                        bcs @lia_fail
                        cmp #$22
                        bne @lia_fail

                        jsr pass
                        bra @test_lir

@lia_fail:              jsr fail

; ----- Test: LIST rew 6, atstart, fetch = $10 -----

@test_lir:              ldx #<str_t_lir
                        ldy #>str_t_lir
                        jsr putmsg

                        lda #6
                        ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_rew

                        ; Verify at start
                        ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_atstart
                        bne @lir_fail

                        ; Verify fetch = $10
                        ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_fetch
                        bcs @lir_fail
                        cmp #$10
                        bne @lir_fail

                        jsr pass
                        bra @li_cleanup

@lir_fail:              jsr fail

; ----- LIST cleanup -----

@li_cleanup:            ldx li_handle
                        ldy li_handle+1
                        jsr ulitr_delete
                        ldx li_list
                        ldy li_list+1
                        jsr ullist_release
                        ldx li_db_a
                        ldy li_db_a+1
                        jsr uldb_release
                        ldx li_db_b
                        ldy li_db_b+1
                        jsr uldb_release

; ----- Summary -----

@summary:               ldx #<str_summary
                        ldy #>str_summary
                        jsr putmsg
                        lda num_passed
                        jsr putdec
                        ldx #<str_of
                        ldy #>str_of
                        jsr putmsg
                        lda num_total
                        jsr putdec
                        ldx #<str_pad
                        ldy #>str_pad
                        jsr putmsg

                        jsr ulwin_refresh
                        lda #$0A
                        sta EMU_STDOUT
                        stp
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
mem_buf:        .res 8          ; memory buffer for MEM tests
db_handle:      .res 2          ; data block handle
db_data_brp:    .res 2          ; data block's data BRP
db_testdata:    .res 8          ; test data buffer for fromBuffer test
ll_handle:      .res 2          ; blocklist handle
ll_db1:         .res 2          ; blocklist test data block 1
ll_db2:         .res 2          ; blocklist test data block 2
ll_db3:         .res 2          ; blocklist test data block 3
li_handle:      .res 2          ; LIST iterator handle
li_db_a:        .res 2          ; LIST test data block A
li_db_b:        .res 2          ; LIST test data block B
li_list:        .res 2          ; LIST test blocklist handle
bcd_tmp:        .res 2          ; scratch for putdec BCD conversion
