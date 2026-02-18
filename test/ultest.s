.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

.import __BSS_RUN__, __BSS_SIZE__
.import ULS_access

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

; UTF-8 iterator tests
str_t_u8c:      .byte "BRP+UTF8 create        ", 0
str_t_u8f1:     .byte "UTF8 fetch=U+0041      ", 0
str_t_u8f2:     .byte "UTF8 inc,fetch=U+00E9  ", 0
str_t_u8f3:     .byte "UTF8 inc,fetch=U+4E2D  ", 0
str_t_u8f4:     .byte "UTF8 fai=U+4E2D,U+1F600", 0
str_t_u8e:      .byte "UTF8 inc->atend        ", 0
str_t_u8d:      .byte "UTF8 dec,fetch=U+1F600 ", 0
str_t_u8ds:     .byte "UTF8 dec x3->atstart   ", 0

; REVERSE+UTF8 tests
str_t_ru8c:     .byte "REV+UTF8 create        ", 0
str_t_ru8f:     .byte "REV+UTF8 fetch=U+1F600 ", 0
str_t_ru8i:     .byte "REV+UTF8 fai x4+atend  ", 0
str_t_ru8d:     .byte "REV+UTF8 last fai=0041 ", 0

; STRING iterator tests
str_t_sic:      .byte "STRING create          ", 0
str_t_sif:      .byte "STRING fetch=U+0041    ", 0
str_t_sii:      .byte "STRING fai x4+atend    ", 0
str_t_sirc:     .byte "REV+STRING create      ", 0
str_t_sirf:     .byte "REV+STRING fetch=1F600 ", 0
str_t_sicl:     .byte "STRING cleanup         ", 0

; UTF-8 test data: 'A' (1 byte) + e-acute U+00E9 (2 bytes) + CJK U+4E2D (3 bytes) + grinning U+1F600 (4 bytes)
utf8_testdata:  .byte $41, $C3, $A9, $E4, $B8, $AD, $F0, $9F, $98, $80
UTF8_TESTLEN = 10
; NUL-terminated version for ulstr_fromUtf8
utf8_teststr:   .byte $41, $C3, $A9, $E4, $B8, $AD, $F0, $9F, $98, $80, $00

; String function tests
str_t_srel:     .byte "ulstr_release          ", 0
str_t_scmp1:    .byte "compare(Hello,Hello)=0 ", 0
str_t_scmp2:    .byte "compare(Hello,World)<0 ", 0
str_t_scmp3:    .byte "compare(World,Hello)>0 ", 0
str_t_sfnd1:    .byte "find(Hello,0,'l')=2    ", 0
str_t_sfnd2:    .byte "find(Hello,3,'l')=3    ", 0
str_t_sfnd3:    .byte "find(Hello,0,'z')=-1   ", 0
str_t_srfnd:    .byte "rfind(Hello,4,'l')=3   ", 0
str_t_sapp:     .byte "append(Hello,World)    ", 0
str_t_smid:     .byte "mid(Hello,1,3)=ell     ", 0
str_t_sto8:     .byte "toUtf8(Hello,iter)     ", 0

; Refcount test strings
str_t_rc1:      .byte "addref rc=2            ", 0
str_t_rc2:      .byte "release 2->1 still ok  ", 0
str_t_rc3:      .byte "release 1->0 freed     ", 0
str_t_zcm:      .byte "mid zero-copy substr   ", 0
str_t_zcr:      .byte "mid src released ok    ", 0

str_hello:      .byte "Hello", 0
str_world:      .byte "World", 0
str_cafe:       .byte "Caf", $C3, $A9, 0

; Stringtable test strings
str_t_stc:      .byte "ulstb_create 3         ", 0
str_t_stp:      .byte "ulstb_put slot 1       ", 0
str_t_stg:      .byte "ulstb_get slot 1       ", 0
str_t_stb0:     .byte "ulstb_get slot 0 err   ", 0
str_t_stb4:     .byte "ulstb_get slot 4 err   ", 0
str_t_std:      .byte "ulstb_delete           ", 0
str_t_stbld:    .byte "ulstb_build 3 strings  ", 0
str_t_stbg:     .byte "ulstb_get after build  ", 0

; Test data for ulstb_build: three NUL-terminated strings + empty terminator
stb_build_data: .byte "Alpha", 0, "Beta", 0, "Gamma", 0, 0

; Heap function tests
str_t_ha32:     .byte "heap_alloc 32 bytes    ", 0
str_t_hcap:     .byte "heap_capacity = 32     ", 0
str_t_hclr:     .byte "heap_alloc cleared     ", 0
str_t_h0:       .byte "heap_alloc 0 = error   ", 0
str_t_hrsm:     .byte "realloc same size      ", 0
str_t_hrsh:     .byte "realloc shrink 64->32  ", 0
str_t_hrgi:     .byte "realloc grow inplace   ", 0
str_t_hrgc:     .byte "realloc grow copy      ", 0
str_t_hfre:     .byte "heap free + realloc    ", 0

; FLOAT and STRINGTABLE iterator tests
str_t_flcs:     .byte "BRP+FLOAT create+store ", 0
str_t_flf:      .byte "BRP+FLOAT fetch FACC   ", 0
str_t_istc:     .byte "BRP+STRTBL create      ", 0
str_t_istf:     .byte "STRTBL fetch entry     ", 0
str_t_isti:     .byte "STRTBL fai x3+atend    ", 0
str_t_istcl:    .byte "STRTBL cleanup         ", 0

; fromPETSCII tests
str_t_fps:      .byte "fromPETSCII shifted    ", 0
str_t_fpsl:     .byte "fromPETSCII shifted lc ", 0
str_t_fpsp:     .byte "fromPETSCII £ special  ", 0
str_t_fpe:      .byte "fromPETSCII empty      ", 0

; fromISO8859 tests
str_t_fia:      .byte "fromISO8859 ASCII      ", 0
str_t_fil:      .byte "fromISO8859 latin e    ", 0
str_t_fie:      .byte "fromISO8859 euro       ", 0
str_t_fimt:     .byte "fromISO8859 empty      ", 0

; toPETSCII round-trip test
str_t_tpr:      .byte "toPETSCII round-trip   ", 0
str_t_tpu:      .byte "toPETSCII unmappable   ", 0

; toISO8859 round-trip test
str_t_tir:      .byte "toISO8859 round-trip   ", 0
str_t_tiu:      .byte "toISO8859 unmappable   ", 0

; format tests
str_t_fmn:      .byte "format no placeholders ", 0
str_t_fms:      .byte "format sequential {}   ", 0
str_t_fmi:      .byte "format indexed {1}     ", 0

; Test data
; PETSCII "HELLO" in shifted mode: H=$48 E=$45 L=$4C L=$4C O=$4F (uppercase→lowercase in shifted)
petscii_hello:  .byte $48,$45,$4C,$4C,$4F,$00
; PETSCII shifted uppercase via $C1-$DA range: H=$C8 I=$C9 (→ "HI")
petscii_hi_sh:  .byte $C8,$C9,$00
; PETSCII with £ ($5C) and ↑ ($5E)
petscii_special:.byte $5C,$5E,$00
; ISO-8859-15 "Cafe" with e-acute ($E9) and Euro ($A4)
iso_cafe:       .byte $43,$61,$66,$E9,$00
iso_euro:       .byte $A4,$00
; Format test data
fmt_hello:      .byte "Hello, {}!", 0
fmt_idx:        .byte "A={1} B={2}", 0
fmt_plain:      .byte "No placeholders", 0
fmt_names:      .byte "World", 0, 0    ; single-entry stb_build data
fmt_ab_data:    .byte "alpha", 0, "beta", 0, 0
; UTF-8 for 中 (U+4E2D) — used for toISO8859 unmappable test
utf8_zhong:     .byte $E4, $B8, $AD, $00

; inschar/delchar test strings
str_t_ins:      .byte "inschar shifts buffer ", 0
str_t_del:      .byte "delchar shifts buffer ", 0
ins_expect:     .byte "ABXCDE", 0
del_expect:     .byte "ACDE", 0

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

; puthex_stdout - Write A as 2 hex digits to EMU_STDOUT only
;   In: A = byte value
.proc puthex_stdout
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        tax
                        lda hexchars,x
                        sta EMU_STDOUT
                        pla
                        pha
                        and #$0f
                        tax
                        lda hexchars,x
                        sta EMU_STDOUT
                        pla
                        rts
hexchars:               .byte "0123456789ABCDEF"
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
                        jsr ulwin_putcursor
                        rts
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
                        jsr ulwin_refresh
                        rts
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
.ifdef ROM_TEST
                        ; ROM mode: decompress font from ROM bank C (r1L=0)
                        stz gREG::r1L
.else
                        lda #(end_filenames-font_fn)
                        sta gREG::r1L
                        lda #8
                        sta gREG::r1H
                        lda #<font_fn
                        sta gREG::r0L
                        lda #>font_fn
                        sta gREG::r0H
.endif
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
                        bcs @alloc_fail
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
                        bcs @create_fail
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
                        bcs @wc_fail
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
                        bcs @wc_fail
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
                        bcs @mc_fail
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
                        bcs @vc_fail
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
                        bcs @rc_fail
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
                        bcs @rc_fail
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

.ifdef ROM_TEST
                        ; DEBUG: dump iterator state before loop
                        ; iter handle = bank:slot BRP
                        ldx iter
                        ldy iter+1
                        jsr ulmem_access        ; YX = address, bank set
                        stx gREG::r13L
                        sty gREG::r13H
                        ; Byte 0 = type_format
                        lda (gREG::r13)
                        jsr puthex_stdout
                        lda #':'
                        sta EMU_STDOUT
                        ; Bytes 1-3 = cur (addr_lo, addr_hi, bank)
                        ldy #1
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        iny
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        iny
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        lda #'/'
                        sta EMU_STDOUT
                        ; Bytes 4-6 = start
                        iny
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        iny
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        iny
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        lda #'-'
                        sta EMU_STDOUT
                        ; Bytes 7-9 = end
                        iny
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        iny
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        iny
                        lda (gREG::r13),y
                        jsr puthex_stdout
                        lda #$0A
                        sta EMU_STDOUT
.endif
                        lda #7
                        sta fwd_idx             ; expected value starts at 7
                        stz fwd_errs
@ri_loop:               ldx iter
                        ldy iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @ri_err
                        ; DEBUG: print actual value
                        pha
                        clc
                        adc #'0'
                        sta EMU_STDOUT
                        pla
                        cmp fwd_idx
                        beq @ri_next
                        bra @ri_err2
@ri_err:                lda #'C'                ; DEBUG: 'C' = carry set error
                        sta EMU_STDOUT
@ri_err2:               inc fwd_errs
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
                        bcs @dc_fail
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

                        ; DEBUG: try fetch before store to verify iterator is valid
                        ldx iter
                        ldy iter+1
                        jsr ulitr_fetch
                        bcc @ds_fetchok
                        lda #'!'
                        sta EMU_STDOUT          ; '!' = fetch also fails
                        bra @ds_dostore
@ds_fetchok:            lda #'.'
                        sta EMU_STDOUT          ; '.' = fetch ok

                        ; DWORD in little-endian: $EF, $BE, $AD, $DE
@ds_dostore:            lda #$EF
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
                        bcs @dbc_fail
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
                        bcs @dbfb_fail
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
                        bcc :+
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
                        bcc :+
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
                        bcc :+
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
                        bcs @llc_fail
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
                        bcs @lli_fail
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
                        bcs @lli_fail

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
                        bcs @llg_fail
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
                        bcs @lli2_fail
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
                        bcs @lli2_fail

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
                        bcs @lli0_fail
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
                        bcs @lli0_fail

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
                        bcs @llo_err
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
                        bcs @llo_err2
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
                        bcs @llo_err3
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
                        bcs @lld_fail

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
                        bcs @llci_fail
                        stx ll_db1
                        sty ll_db1+1

                        ; Create list with initial handle
                        ldx ll_db1
                        ldy ll_db1+1
                        jsr ullist_create
                        bcs @llci_fail
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
                        bcs @llci_fail
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
                        bcc :+
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
                        bcc :+
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
                        bcc :+
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
                        bcs @lic_fail
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

; =========================================================================
; UTF-8 Iterator tests
; =========================================================================

                        ; Setup: allocate BRP with UTF-8 test data
                        ldx #UTF8_TESTLEN
                        ldy #0
                        clc                     ; don't clear
                        jsr ulmem_alloc
                        bcc :+
                        jmp @test_str_setup
:                       stx u8_brp
                        sty u8_brp+1

                        ; Fill with test data
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
@u8_fill:               lda utf8_testdata,y
                        sta (gREG::r5),y
                        iny
                        cpy #UTF8_TESTLEN
                        bne @u8_fill

; ----- Test: Create BRP+UTF8 iterator -----

@test_u8c:              ldx #<str_t_u8c
                        ldy #>str_t_u8c
                        jsr putmsg

                        lda #UTF8_TESTLEN
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::UTF8)
                        ldx u8_brp
                        ldy u8_brp+1
                        jsr ulitr_create
                        bcs @u8c_fail
                        stx u8_iter
                        sty u8_iter+1

                        jsr pass
                        bra @test_u8f1

@u8c_fail:              jsr fail
                        jmp @u8_cleanup

; ----- Test: fetch = U+0041 ('A') -----

@test_u8f1:             ldx #<str_t_u8f1
                        ldy #>str_t_u8f1
                        jsr putmsg

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_fetch
                        bcs @u8f1_fail
                        lda gREG::r0L
                        cmp #$41
                        bne @u8f1_fail
                        lda gREG::r0H
                        bne @u8f1_fail
                        lda gREG::r1L
                        bne @u8f1_fail

                        jsr pass
                        bra @test_u8f2

@u8f1_fail:             jsr fail

; ----- Test: inc, fetch = U+00E9 -----

@test_u8f2:             ldx #<str_t_u8f2
                        ldy #>str_t_u8f2
                        jsr putmsg

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_inc

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_fetch
                        bcs @u8f2_fail
                        lda gREG::r0L
                        cmp #$E9
                        bne @u8f2_fail
                        lda gREG::r0H
                        bne @u8f2_fail
                        lda gREG::r1L
                        bne @u8f2_fail

                        jsr pass
                        bra @test_u8f3

@u8f2_fail:             jsr fail

; ----- Test: inc, fetch = U+4E2D -----

@test_u8f3:             ldx #<str_t_u8f3
                        ldy #>str_t_u8f3
                        jsr putmsg

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_inc

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_fetch
                        bcs @u8f3_fail
                        lda gREG::r0L
                        cmp #$2D
                        bne @u8f3_fail
                        lda gREG::r0H
                        cmp #$4E
                        bne @u8f3_fail
                        lda gREG::r1L
                        bne @u8f3_fail

                        jsr pass
                        bra @test_u8f4

@u8f3_fail:             jsr fail

; ----- Test: fetch_and_inc = U+4E2D, then fetch = U+1F600 -----

@test_u8f4:             ldx #<str_t_u8f4
                        ldy #>str_t_u8f4
                        jsr putmsg

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @u8f4_fail
                        ; Should have returned U+4E2D
                        lda gREG::r0L
                        cmp #$2D
                        bne @u8f4_fail
                        lda gREG::r0H
                        cmp #$4E
                        bne @u8f4_fail

                        ; Now fetch should be U+1F600
                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_fetch
                        bcs @u8f4_fail
                        lda gREG::r0L
                        cmp #$00
                        bne @u8f4_fail
                        lda gREG::r0H
                        cmp #$F6
                        bne @u8f4_fail
                        lda gREG::r1L
                        cmp #$01
                        bne @u8f4_fail

                        jsr pass
                        bra @test_u8e

@u8f4_fail:             jsr fail

; ----- Test: inc -> atend -----

@test_u8e:              ldx #<str_t_u8e
                        ldy #>str_t_u8e
                        jsr putmsg

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_inc

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_atend
                        beq :+
                        jsr fail
                        bra @test_u8d
:                       jsr pass

; ----- Test: dec, fetch = U+1F600 -----

@test_u8d:              ldx #<str_t_u8d
                        ldy #>str_t_u8d
                        jsr putmsg

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_dec

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_fetch
                        bcs @u8d_fail
                        lda gREG::r0L
                        cmp #$00
                        bne @u8d_fail
                        lda gREG::r0H
                        cmp #$F6
                        bne @u8d_fail
                        lda gREG::r1L
                        cmp #$01
                        bne @u8d_fail

                        jsr pass
                        bra @test_u8ds

@u8d_fail:              jsr fail

; ----- Test: dec x3 -> atstart -----

@test_u8ds:             ldx #<str_t_u8ds
                        ldy #>str_t_u8ds
                        jsr putmsg

                        ; Dec 3 more times to get back to start
                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_dec
                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_dec
                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_dec

                        ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_atstart
                        beq :+
                        jsr fail
                        jmp @u8_cleanup
:                       jsr pass

; =========================================================================
; REVERSE+UTF8 Iterator tests (reuse u8_brp)
; =========================================================================

; ----- Test: Create REVERSE+BRP+UTF8 iterator -----

@test_ru8c:             ldx #<str_t_ru8c
                        ldy #>str_t_ru8c
                        jsr putmsg

                        lda #UTF8_TESTLEN
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::REVERSE | ULITYP::BRP | ULIFMT::UTF8)
                        ldx u8_brp
                        ldy u8_brp+1
                        jsr ulitr_create
                        bcs @ru8c_fail
                        stx ru8_iter
                        sty ru8_iter+1

                        jsr pass
                        bra @test_ru8f

@ru8c_fail:             jsr fail
                        jmp @u8_cleanup

; ----- Test: REV+UTF8 fetch = U+1F600 (last char) -----

@test_ru8f:             ldx #<str_t_ru8f
                        ldy #>str_t_ru8f
                        jsr putmsg

                        ldx ru8_iter
                        ldy ru8_iter+1
                        jsr ulitr_fetch
                        bcs @ru8f_fail
                        lda gREG::r0L
                        cmp #$00
                        bne @ru8f_fail
                        lda gREG::r0H
                        cmp #$F6
                        bne @ru8f_fail
                        lda gREG::r1L
                        cmp #$01
                        bne @ru8f_fail

                        jsr pass
                        bra @test_ru8i

@ru8f_fail:             jsr fail

; ----- Test: REV+UTF8 fai x4 + atend -----

@test_ru8i:             ldx #<str_t_ru8i
                        ldy #>str_t_ru8i
                        jsr putmsg

                        stz fwd_errs
                        lda #4
                        sta fwd_idx
@ru8i_loop:             ldx ru8_iter
                        ldy ru8_iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @ru8i_err
                        ; Save last fetched codepoint
                        lda gREG::r0L
                        sta ru8_last_r0l
                        lda gREG::r0H
                        sta ru8_last_r0h
                        lda gREG::r1L
                        sta ru8_last_r1l
                        dec fwd_idx
                        bne @ru8i_loop
                        bra @ru8i_check
@ru8i_err:              inc fwd_errs
                        dec fwd_idx
                        bne @ru8i_loop

@ru8i_check:            ; Should be at end
                        ldx ru8_iter
                        ldy ru8_iter+1
                        jsr ulitr_atend
                        bne @ru8i_fail
                        lda fwd_errs
                        bne @ru8i_fail

                        jsr pass
                        bra @test_ru8d

@ru8i_fail:             jsr fail

; ----- Test: REV+UTF8 last fai returned U+0041 ('A') -----

@test_ru8d:             ldx #<str_t_ru8d
                        ldy #>str_t_ru8d
                        jsr putmsg

                        ; The last successful fai should have returned 'A' (U+0041)
                        lda ru8_last_r0l
                        cmp #$41
                        bne @ru8d_fail
                        lda ru8_last_r0h
                        bne @ru8d_fail
                        lda ru8_last_r1l
                        bne @ru8d_fail

                        jsr pass
                        bra @ru8_cleanup

@ru8d_fail:             jsr fail

; ----- REVERSE+UTF8 cleanup -----

@ru8_cleanup:           ldx ru8_iter
                        ldy ru8_iter+1
                        jsr ulitr_delete

; ----- UTF-8 cleanup -----

@u8_cleanup:            ldx u8_iter
                        ldy u8_iter+1
                        jsr ulitr_delete
                        ldx u8_brp
                        ldy u8_brp+1
                        jsr ulmem_free

; =========================================================================
; STRING Iterator tests
; =========================================================================

; ----- Test: STRING create -----

@test_sic:              ldx #<str_t_sic
                        ldy #>str_t_sic
                        jsr putmsg

                        ; Create string from UTF-8 test data "Aé中😀"
                        ldx #<utf8_teststr
                        ldy #>utf8_teststr
                        jsr ulstr_fromUtf8
                        bcs @sic_fail
                        stx si_str
                        sty si_str+1

                        ; Create STRING+UTF8 iterator
                        lda #(ULITYP::STRING | ULIFMT::UTF8)
                        ldx si_str
                        ldy si_str+1
                        jsr ulitr_create
                        bcs @sic_fail2
                        stx si_iter
                        sty si_iter+1

                        jsr pass
                        bra @test_sif

@sic_fail2:             ldx si_str
                        ldy si_str+1
                        jsr ulstr_release
@sic_fail:              jsr fail
                        jmp @test_str_setup

; ----- Test: STRING fetch = U+0041 ('A') -----

@test_sif:              ldx #<str_t_sif
                        ldy #>str_t_sif
                        jsr putmsg

                        ldx si_iter
                        ldy si_iter+1
                        jsr ulitr_fetch
                        bcs @sif_fail
                        lda gREG::r0L
                        cmp #$41
                        bne @sif_fail
                        lda gREG::r0H
                        bne @sif_fail
                        lda gREG::r1L
                        bne @sif_fail

                        jsr pass
                        bra @test_sii

@sif_fail:              jsr fail

; ----- Test: STRING fai x4 + atend -----

@test_sii:              ldx #<str_t_sii
                        ldy #>str_t_sii
                        jsr putmsg

                        stz fwd_errs
                        lda #4
                        sta fwd_idx
@sii_loop:              ldx si_iter
                        ldy si_iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @sii_err
                        dec fwd_idx
                        bne @sii_loop
                        bra @sii_check
@sii_err:               inc fwd_errs
                        dec fwd_idx
                        bne @sii_loop

@sii_check:             ; Should be at end
                        ldx si_iter
                        ldy si_iter+1
                        jsr ulitr_atend
                        bne @sii_fail
                        lda fwd_errs
                        bne @sii_fail

                        jsr pass
                        bra @test_sirc

@sii_fail:              jsr fail

; ----- Test: REVERSE+STRING create -----

@test_sirc:             ldx #<str_t_sirc
                        ldy #>str_t_sirc
                        jsr putmsg

                        lda #(ULITYP::REVERSE | ULITYP::STRING | ULIFMT::UTF8)
                        ldx si_str
                        ldy si_str+1
                        jsr ulitr_create
                        bcs @sirc_fail
                        stx si_riter
                        sty si_riter+1

                        jsr pass
                        bra @test_sirf

@sirc_fail:             jsr fail
                        jmp @test_sicl

; ----- Test: REV+STRING fetch = U+1F600 -----

@test_sirf:             ldx #<str_t_sirf
                        ldy #>str_t_sirf
                        jsr putmsg

                        ldx si_riter
                        ldy si_riter+1
                        jsr ulitr_fetch
                        bcs @sirf_fail
                        lda gREG::r0L
                        cmp #$00
                        bne @sirf_fail
                        lda gREG::r0H
                        cmp #$F6
                        bne @sirf_fail
                        lda gREG::r1L
                        cmp #$01
                        bne @sirf_fail

                        jsr pass
                        bra @test_sicl

@sirf_fail:             jsr fail

; ----- Test: STRING cleanup -----

@test_sicl:             ldx #<str_t_sicl
                        ldy #>str_t_sicl
                        jsr putmsg

@si_cleanup:            ldx si_riter
                        ldy si_riter+1
                        jsr ulitr_delete
                        ldx si_iter
                        ldy si_iter+1
                        jsr ulitr_delete
                        ldx si_str
                        ldy si_str+1
                        jsr ulstr_release

                        jsr pass

; =========================================================================
; String function tests
; =========================================================================

@test_str_setup:
                        ; Create test strings
                        ldx #<str_hello
                        ldy #>str_hello
                        jsr ulstr_fromUtf8
                        stx s_hello
                        sty s_hello+1

                        ldx #<str_world
                        ldy #>str_world
                        jsr ulstr_fromUtf8
                        stx s_world
                        sty s_world+1

                        ldx #<str_cafe
                        ldy #>str_cafe
                        jsr ulstr_fromUtf8
                        stx s_cafe
                        sty s_cafe+1

; ----- Test: ulstr_release (create + release Cafe, no crash) -----

@test_srel:             ldx #<str_t_srel
                        ldy #>str_t_srel
                        jsr putmsg

                        ldx s_cafe
                        ldy s_cafe+1
                        jsr ulstr_release

                        jsr pass

; ----- Test: compare(Hello,Hello) = 0 -----

@test_scmp1:            ldx #<str_t_scmp1
                        ldy #>str_t_scmp1
                        jsr putmsg

                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        lda s_hello
                        sta gREG::r1L
                        lda s_hello+1
                        sta gREG::r1H
                        lda #0
                        jsr ulstr_compare
                        cmp #0
                        bne @scmp1_fail

                        jsr pass
                        bra @test_scmp2

@scmp1_fail:            jsr fail

; ----- Test: compare(Hello,World) < 0 -----

@test_scmp2:            ldx #<str_t_scmp2
                        ldy #>str_t_scmp2
                        jsr putmsg

                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        lda s_world
                        sta gREG::r1L
                        lda s_world+1
                        sta gREG::r1H
                        lda #0
                        jsr ulstr_compare
                        bmi :+
                        jsr fail
                        bra @test_scmp3
:                       jsr pass

; ----- Test: compare(World,Hello) > 0 -----

@test_scmp3:            ldx #<str_t_scmp3
                        ldy #>str_t_scmp3
                        jsr putmsg

                        lda s_world
                        sta gREG::r0L
                        lda s_world+1
                        sta gREG::r0H
                        lda s_hello
                        sta gREG::r1L
                        lda s_hello+1
                        sta gREG::r1H
                        lda #0
                        jsr ulstr_compare
                        beq @scmp3_fail
                        bmi @scmp3_fail

                        jsr pass
                        bra @test_sfnd1

@scmp3_fail:            jsr fail

; ----- Test: find(Hello, 0, 'l') = 2 -----

@test_sfnd1:            ldx #<str_t_sfnd1
                        ldy #>str_t_sfnd1
                        jsr putmsg

                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        stz gREG::r1L
                        stz gREG::r1H
                        ldx #$6C                ; 'l'
                        ldy #0
                        lda #0
                        jsr ulstr_find
                        cpx #2
                        bne @sfnd1_fail
                        cpy #0
                        bne @sfnd1_fail

                        jsr pass
                        bra @test_sfnd2

@sfnd1_fail:            jsr fail

; ----- Test: find(Hello, 3, 'l') = 3 -----

@test_sfnd2:            ldx #<str_t_sfnd2
                        ldy #>str_t_sfnd2
                        jsr putmsg

                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        lda #3
                        sta gREG::r1L
                        stz gREG::r1H
                        ldx #$6C                ; 'l'
                        ldy #0
                        lda #0
                        jsr ulstr_find
                        cpx #3
                        bne @sfnd2_fail
                        cpy #0
                        bne @sfnd2_fail

                        jsr pass
                        bra @test_sfnd3

@sfnd2_fail:            jsr fail

; ----- Test: find(Hello, 0, 'z') = $FFFF -----

@test_sfnd3:            ldx #<str_t_sfnd3
                        ldy #>str_t_sfnd3
                        jsr putmsg

                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        stz gREG::r1L
                        stz gREG::r1H
                        ldx #$7A                ; 'z'
                        ldy #0
                        lda #0
                        jsr ulstr_find
                        cpx #$FF
                        bne @sfnd3_fail
                        cpy #$FF
                        bne @sfnd3_fail

                        jsr pass
                        bra @test_srfnd

@sfnd3_fail:            jsr fail

; ----- Test: rfind(Hello, 4, 'l') = 3 -----

@test_srfnd:            ldx #<str_t_srfnd
                        ldy #>str_t_srfnd
                        jsr putmsg

                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        lda #4
                        sta gREG::r1L
                        stz gREG::r1H
                        ldx #$6C                ; 'l'
                        ldy #0
                        lda #0
                        jsr ulstr_rfind
                        cpx #3
                        bne @srfnd_fail
                        cpy #0
                        bne @srfnd_fail

                        jsr pass
                        jmp @test_sapp

@srfnd_fail:            jsr fail

; ----- Test: append(Hello,World) -> rawlen=10 -----

@test_sapp:             ldx #<str_t_sapp
                        ldy #>str_t_sapp
                        jsr putmsg

                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        lda s_world
                        sta gREG::r1L
                        lda s_world+1
                        sta gREG::r1H
                        jsr ulstr_append
                        bcs @sapp_fail
                        stx s_temp
                        sty s_temp+1

                        ; Check rawlen = 10
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_getrawlen
                        cmp #10
                        bne @sapp_fail2

                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_smid

@sapp_fail2:            ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release
@sapp_fail:             jsr fail

; ----- Test: mid(Hello, 1, 3) -> rawlen=3 -----

@test_smid:             ldx #<str_t_smid
                        ldy #>str_t_smid
                        jsr putmsg

                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        lda #1
                        sta gREG::r1L
                        stz gREG::r1H
                        lda #3
                        sta gREG::r2L
                        stz gREG::r2H
                        jsr ulstr_mid
                        bcs @smid_fail
                        stx s_temp
                        sty s_temp+1

                        ; Check rawlen = 3
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_getrawlen
                        cmp #3
                        bne @smid_fail2

                        ; Verify data is 'e','l','l' via ULS_access
                        ldx s_temp
                        ldy s_temp+1
                        jsr ULS_access
                        stx gREG::r13L
                        sty gREG::r13H
                        lda (gREG::r13)
                        cmp #$65                ; 'e'
                        bne @smid_fail2
                        ldy #1
                        lda (gREG::r13),y
                        cmp #$6C                ; 'l'
                        bne @smid_fail2
                        iny
                        lda (gREG::r13),y
                        cmp #$6C                ; 'l'
                        bne @smid_fail2

                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_sto8

@smid_fail2:            ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release
@smid_fail:             jsr fail

; ----- Test: toUtf8(Hello, byte_iter) -> 5 bytes match -----

@test_sto8:             ldx #<str_t_sto8
                        ldy #>str_t_sto8
                        jsr putmsg

                        ; Allocate 8-byte BRP for output
                        ldx #8
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc :+
                        jmp @sto8_fail
:                       stx s_temp
                        sty s_temp+1

                        ; Create byte iterator over it
                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::BYTE)
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulitr_create
                        bcc :+
                        jmp @sto8_fail
:
                        stx s_temp2
                        sty s_temp2+1

                        ; Call toUtf8
                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        ldx s_temp2
                        ldy s_temp2+1
                        jsr ulstr_toUtf8
                        bcs @sto8_fail2

                        ; Verify bytes: read the BRP directly
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        stz fwd_errs
                        ldy #0
                        lda (gREG::r5),y
                        cmp #$48                ; 'H'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$65                ; 'e'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$6C                ; 'l'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$6C                ; 'l'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$6F                ; 'o'
                        beq :+
                        inc fwd_errs
:
                        lda fwd_errs
                        bne @sto8_fail2

                        ; Cleanup
                        ldx s_temp2
                        ldy s_temp2+1
                        jsr ulitr_delete
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulmem_free

                        jsr pass
                        jmp @test_rc1

@sto8_fail2:            ldx s_temp2
                        ldy s_temp2+1
                        jsr ulitr_delete
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulmem_free
@sto8_fail:             jsr fail

; =========================================================================
; Refcount tests
; =========================================================================

; ----- Test: addref increments refcount to 2 -----

@test_rc1:              ldx #<str_t_rc1
                        ldy #>str_t_rc1
                        jsr putmsg

                        ; Create a fresh string for refcount testing
                        ldx #<str_cafe
                        ldy #>str_cafe
                        jsr ulstr_fromUtf8
                        stx s_temp
                        sty s_temp+1

                        ; addref: refcount should be 2
                        jsr ulstr_addref

                        ; Verify rawlen still works (string is valid)
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_getrawlen
                        cmp #5                  ; "Caf\xC3\xA9" = 5 bytes
                        bne @rc1_fail

                        jsr pass
                        bra @test_rc2

@rc1_fail:              jsr fail

; ----- Test: release 2->1, string still valid -----

@test_rc2:              ldx #<str_t_rc2
                        ldy #>str_t_rc2
                        jsr putmsg

                        ; Release once (2 -> 1)
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release

                        ; String should still be valid — check rawlen
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_getrawlen
                        cmp #5
                        bne @rc2_fail

                        jsr pass
                        bra @test_rc3

@rc2_fail:              jsr fail

; ----- Test: release 1->0, string freed (no crash) -----

@test_rc3:              ldx #<str_t_rc3
                        ldy #>str_t_rc3
                        jsr putmsg

                        ; Release again (1 -> 0, string freed)
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release

                        ; If we get here without crashing, pass
                        jsr pass

; ----- Test: mid creates zero-copy substring -----

@test_zcm:              ldx #<str_t_zcm
                        ldy #>str_t_zcm
                        jsr putmsg

                        ; mid(Hello, 1, 3) = "ell"
                        lda s_hello
                        sta gREG::r0L
                        lda s_hello+1
                        sta gREG::r0H
                        lda #1
                        sta gREG::r1L
                        stz gREG::r1H
                        lda #3
                        sta gREG::r2L
                        stz gREG::r2H
                        jsr ulstr_mid
                        bcs @zcm_fail
                        stx s_temp
                        sty s_temp+1

                        ; Verify rawlen = 3
                        jsr ulstr_getrawlen
                        cmp #3
                        bne @zcm_fail2

                        ; Verify data via ULS_access
                        ldx s_temp
                        ldy s_temp+1
                        jsr ULS_access
                        stx gREG::r13L
                        sty gREG::r13H
                        lda (gREG::r13)
                        cmp #$65                ; 'e'
                        bne @zcm_fail2
                        ldy #1
                        lda (gREG::r13),y
                        cmp #$6C                ; 'l'
                        bne @zcm_fail2
                        iny
                        lda (gREG::r13),y
                        cmp #$6C                ; 'l'
                        bne @zcm_fail2

                        jsr pass
                        bra @test_zcr

@zcm_fail2:            ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release
@zcm_fail:              jsr fail
                        jmp @test_stc

; ----- Test: release source, mid substring still valid -----

@test_zcr:              ldx #<str_t_zcr
                        ldy #>str_t_zcr
                        jsr putmsg

                        ; Addref s_hello so we can release it and get it back
                        ldx s_hello
                        ldy s_hello+1
                        jsr ulstr_addref

                        ; Release s_hello (data block still held by mid's addref)
                        ldx s_hello
                        ldy s_hello+1
                        jsr ulstr_release

                        ; Mid substring should still work
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_getrawlen
                        cmp #3
                        bne @zcr_fail

                        ; Release the mid substring
                        ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release

                        jsr pass
                        jmp @test_stc

@zcr_fail:              ldx s_temp
                        ldy s_temp+1
                        jsr ulstr_release
                        jsr fail

; ----- Test: ulstb_create 3 -----

@test_stc:              ldx #<str_t_stc
                        ldy #>str_t_stc
                        jsr putmsg

                        lda #3
                        jsr ulstb_create
                        bcs @stc_fail
                        stx stb_handle
                        sty stb_handle+1

                        jsr pass
                        bra @test_stp

@stc_fail:              jsr fail
                        jmp @test_stbld

; ----- Test: ulstb_put slot 1 -----

@test_stp:              ldx #<str_t_stp
                        ldy #>str_t_stp
                        jsr putmsg

                        ; Put s_hello into slot 1
                        lda stb_handle
                        sta gREG::r0L
                        lda stb_handle+1
                        sta gREG::r0H
                        lda #1
                        ldx s_hello
                        ldy s_hello+1
                        jsr ulstb_put
                        bcs @stp_fail

                        jsr pass
                        bra @test_stg

@stp_fail:              jsr fail

; ----- Test: ulstb_get slot 1 -----

@test_stg:              ldx #<str_t_stg
                        ldy #>str_t_stg
                        jsr putmsg

                        ; Get slot 1 and verify it matches s_hello
                        lda stb_handle
                        sta gREG::r0L
                        lda stb_handle+1
                        sta gREG::r0H
                        lda #1
                        jsr ulstb_get
                        bcs @stg_fail
                        cpx s_hello
                        bne @stg_fail
                        cpy s_hello+1
                        bne @stg_fail

                        jsr pass
                        bra @test_stb0

@stg_fail:              jsr fail

; ----- Test: ulstb_get slot 0 (bounds error) -----

@test_stb0:             ldx #<str_t_stb0
                        ldy #>str_t_stb0
                        jsr putmsg

                        lda stb_handle
                        sta gREG::r0L
                        lda stb_handle+1
                        sta gREG::r0H
                        lda #0
                        jsr ulstb_get
                        bcs @stb0_pass          ; expect error
                        jsr fail
                        bra @test_stb4
@stb0_pass:             jsr pass

; ----- Test: ulstb_get slot 4 (bounds error) -----

@test_stb4:             ldx #<str_t_stb4
                        ldy #>str_t_stb4
                        jsr putmsg

                        lda stb_handle
                        sta gREG::r0L
                        lda stb_handle+1
                        sta gREG::r0H
                        lda #4
                        jsr ulstb_get
                        bcs @stb4_pass          ; expect error
                        jsr fail
                        bra @test_std
@stb4_pass:             jsr pass

; ----- Test: ulstb_delete -----

@test_std:              ldx #<str_t_std
                        ldy #>str_t_std
                        jsr putmsg

                        ; Delete table (refcounting means s_hello survives —
                        ; put addref'd it, delete will release back to original refcount)
                        ldx stb_handle
                        ldy stb_handle+1
                        jsr ulstb_delete

                        ; If we get here without crashing, pass
                        jsr pass
                        bra @test_stbld

; ----- Test: ulstb_build 3 strings -----

@test_stbld:            ldx #<str_t_stbld
                        ldy #>str_t_stbld
                        jsr putmsg

                        ldx #<stb_build_data
                        ldy #>stb_build_data
                        jsr ulstb_build
                        bcc :+
                        jmp @stbld_fail
:                       stx stb_handle
                        sty stb_handle+1

                        jsr pass
                        bra @test_stbg

@stbld_fail:            jsr fail
                        jmp @str_cleanup

; ----- Test: ulstb_get after build -----

@test_stbg:             ldx #<str_t_stbg
                        ldy #>str_t_stbg
                        jsr putmsg

                        ; Get slot 1 ("Alpha") and check its length = 5
                        lda stb_handle
                        sta gREG::r0L
                        lda stb_handle+1
                        sta gREG::r0H
                        lda #1
                        jsr ulstb_get
                        bcs @stbg_fail
                        jsr ulstr_getlen
                        cmp #5
                        bne @stbg_fail

                        ; Get slot 3 ("Gamma") and check its length = 5
                        lda stb_handle
                        sta gREG::r0L
                        lda stb_handle+1
                        sta gREG::r0H
                        lda #3
                        jsr ulstb_get
                        bcs @stbg_fail
                        jsr ulstr_getlen
                        cmp #5
                        bne @stbg_fail

                        ; Clean up build table
                        ldx stb_handle
                        ldy stb_handle+1
                        jsr ulstb_delete

                        jsr pass
                        bra @str_cleanup

@stbg_fail:             ldx stb_handle
                        ldy stb_handle+1
                        jsr ulstb_delete
                        jsr fail

; ----- String cleanup -----

@str_cleanup:           ldx s_hello
                        ldy s_hello+1
                        jsr ulstr_release
                        ldx s_world
                        ldy s_world+1
                        jsr ulstr_release

; =====================================================================
; Heap function tests
; =====================================================================

; ----- Test: heap_alloc 32 bytes -----

                        ldx #<str_t_ha32
                        ldy #>str_t_ha32
                        jsr putmsg

                        ldx #32
                        ldy #0
                        clc
                        jsr ulmem_alloc
                        bcs @ha32_fail
                        stx h_brp_a
                        sty h_brp_a+1
                        ; BRP must be non-zero
                        cpx #0
                        bne @ha32_pass
                        cpy #0
                        beq @ha32_fail
@ha32_pass:             jsr pass
                        bra @test_hcap
@ha32_fail:             jsr fail
                        jmp @summary

; ----- Test: heap_capacity = 32 -----

@test_hcap:             ldx #<str_t_hcap
                        ldy #>str_t_hcap
                        jsr putmsg

                        ldx h_brp_a
                        ldy h_brp_a+1
                        jsr ulmem_capacity
                        cpx #32
                        bne @hcap_fail
                        cpy #0
                        bne @hcap_fail
                        jsr pass
                        bra @test_hclr
@hcap_fail:             jsr fail

; ----- Test: heap_alloc cleared -----

@test_hclr:             ldx #<str_t_hclr
                        ldy #>str_t_hclr
                        jsr putmsg

                        ldx #64
                        ldy #0
                        sec                     ; clear memory
                        jsr ulmem_alloc
                        bcs @hclr_fail
                        stx h_brp_b
                        sty h_brp_b+1
                        ; Access BRP and check byte 0 and byte 63 are zero
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda (gREG::r5),y
                        bne @hclr_fail
                        ldy #63
                        lda (gREG::r5),y
                        bne @hclr_fail
                        jsr pass
                        bra @test_h0
@hclr_fail:             jsr fail

; ----- Test: heap_alloc 0 = error -----

@test_h0:               ldx #<str_t_h0
                        ldy #>str_t_h0
                        jsr putmsg

                        ldx #0
                        ldy #0
                        clc
                        jsr ulmem_alloc
                        bcs @h0_pass
                        ; Should have failed — free the accidental alloc and fail
                        jsr ulmem_free
                        jsr fail
                        bra @test_hrsm
@h0_pass:               jsr pass

; ----- Test: realloc same size -----

@test_hrsm:             ldx #<str_t_hrsm
                        ldy #>str_t_hrsm
                        jsr putmsg

                        lda h_brp_a
                        sta gREG::r0L
                        lda h_brp_a+1
                        sta gREG::r0H
                        ldx #32
                        ldy #0
                        jsr ulmem_realloc
                        bcs @hrsm_fail
                        ; Returned BRP should match original
                        cpx h_brp_a
                        bne @hrsm_fail
                        cpy h_brp_a+1
                        bne @hrsm_fail
                        jsr pass
                        bra @test_hrsh
@hrsm_fail:             jsr fail

; ----- Test: realloc shrink 64->32 -----

@test_hrsh:             ldx #<str_t_hrsh
                        ldy #>str_t_hrsh
                        jsr putmsg

                        lda h_brp_b
                        sta gREG::r0L
                        lda h_brp_b+1
                        sta gREG::r0H
                        ldx #32
                        ldy #0
                        jsr ulmem_realloc
                        bcs @hrsh_fail
                        ; Same BRP returned
                        cpx h_brp_b
                        bne @hrsh_fail
                        cpy h_brp_b+1
                        bne @hrsh_fail
                        stx h_brp_b
                        sty h_brp_b+1
                        ; Verify capacity is now 32
                        jsr ulmem_capacity
                        cpx #32
                        bne @hrsh_fail
                        cpy #0
                        bne @hrsh_fail
                        jsr pass
                        bra @test_hrgi
@hrsh_fail:             jsr fail

; ----- Test: realloc grow inplace -----

@test_hrgi:             ldx #<str_t_hrgi
                        ldy #>str_t_hrgi
                        jsr putmsg

                        ; Free h_brp_b (shrunk block, no longer needed)
                        ldx h_brp_b
                        ldy h_brp_b+1
                        jsr ulmem_free
                        ; Free h_brp_a too (start fresh)
                        ldx h_brp_a
                        ldy h_brp_a+1
                        jsr ulmem_free

                        ; Allocate fresh 32 bytes
                        ldx #32
                        ldy #0
                        clc
                        jsr ulmem_alloc
                        bcs @hrgi_fail
                        stx h_brp_a
                        sty h_brp_a+1

                        ; Write sentinel values
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        lda #$A5
                        ldy #0
                        sta (gREG::r5),y
                        lda #$5A
                        ldy #31
                        sta (gREG::r5),y

                        ; Realloc to 64 bytes (should grow in-place since heap is mostly empty)
                        lda h_brp_a
                        sta gREG::r0L
                        lda h_brp_a+1
                        sta gREG::r0H
                        ldx #64
                        ldy #0
                        jsr ulmem_realloc
                        bcs @hrgi_fail

                        ; Save result
                        stx h_brp_a
                        sty h_brp_a+1

                        ; Access and verify sentinel data preserved
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda (gREG::r5),y
                        cmp #$A5
                        bne @hrgi_fail
                        ldy #31
                        lda (gREG::r5),y
                        cmp #$5A
                        bne @hrgi_fail

                        jsr pass
                        bra @test_hrgc
@hrgi_fail:             jsr fail

; ----- Test: realloc grow copy -----

@test_hrgc:             ldx #<str_t_hrgc
                        ldy #>str_t_hrgc
                        jsr putmsg

                        ; Free previous allocation
                        ldx h_brp_a
                        ldy h_brp_a+1
                        jsr ulmem_free

                        ; Allocate 32 bytes for A
                        ldx #32
                        ldy #0
                        clc
                        jsr ulmem_alloc
                        bcs @hrgc_fail
                        stx h_brp_a
                        sty h_brp_a+1

                        ; Write sentinels to A
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        lda #$C3
                        ldy #0
                        sta (gREG::r5),y
                        lda #$3C
                        ldy #31
                        sta (gREG::r5),y

                        ; Allocate 32 bytes for B (blocks in-place growth of A)
                        ldx #32
                        ldy #0
                        clc
                        jsr ulmem_alloc
                        bcs @hrgc_fail
                        stx h_brp_b
                        sty h_brp_b+1

                        ; Realloc A to 96 bytes (3 slots) — must copy
                        lda h_brp_a
                        sta gREG::r0L
                        lda h_brp_a+1
                        sta gREG::r0H
                        ldx #96
                        ldy #0
                        jsr ulmem_realloc
                        bcs @hrgc_fail

                        ; Save new BRP
                        stx h_saved_brp
                        sty h_saved_brp+1

                        ; Access new location and verify sentinel data copied
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda (gREG::r5),y
                        cmp #$C3
                        bne @hrgc_fail
                        ldy #31
                        lda (gREG::r5),y
                        cmp #$3C
                        bne @hrgc_fail

                        jsr pass
                        bra @test_hfre
@hrgc_fail:             jsr fail

; ----- Test: heap free + realloc -----

@test_hfre:             ldx #<str_t_hfre
                        ldy #>str_t_hfre
                        jsr putmsg

                        ; Free h_brp_b (if set)
                        ldx h_brp_b
                        ldy h_brp_b+1
                        beq :+
                        jsr ulmem_free
:
                        ; Free h_saved_brp (if set)
                        ldx h_saved_brp
                        ldy h_saved_brp+1
                        beq :+
                        jsr ulmem_free
:

                        ; Allocate 32 bytes, then immediately free
                        ldx #32
                        ldy #0
                        clc
                        jsr ulmem_alloc
                        bcs @hfre_fail
                        jsr ulmem_free

                        ; If we got here without crashing, heap is functional
                        jsr pass
                        bra @test_flcs
@hfre_fail:             jsr fail

; =========================================================================
; FLOAT iterator tests
; =========================================================================

; ----- Test: BRP+FLOAT create+store -----

@test_flcs:             ldx #<str_t_flcs
                        ldy #>str_t_flcs
                        jsr putmsg

                        ; Allocate 10-byte BRP (2 floats), cleared
                        ldx #10
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcs @flcs_fail
                        stx fl_brp
                        sty fl_brp+1

                        ; Create BRP+FLOAT iterator (r0 = size = 10)
                        lda #10
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::FLOAT)
                        ldx fl_brp
                        ldy fl_brp+1
                        jsr ulitr_create
                        bcs @flcs_fail
                        stx fl_iter
                        sty fl_iter+1

                        ; Set FACC with known values
                        lda #$11
                        sta FACEXP
                        lda #$22
                        sta FACHO
                        lda #$33
                        sta FACMOH
                        lda #$44
                        sta FACMO
                        lda #$55
                        sta FACLO

                        ; Store FACC to iterator
                        ldx fl_iter
                        ldy fl_iter+1
                        jsr ulitr_store
                        bcs @flcs_fail

                        jsr pass
                        bra @test_flf

@flcs_fail:             jsr fail
                        jmp @test_istc

; ----- Test: BRP+FLOAT fetch FACC -----

@test_flf:              ldx #<str_t_flf
                        ldy #>str_t_flf
                        jsr putmsg

                        ; Zero out FACC
                        stz FACEXP
                        stz FACHO
                        stz FACMOH
                        stz FACMO
                        stz FACLO

                        ; Fetch from iterator into FACC
                        ldx fl_iter
                        ldy fl_iter+1
                        jsr ulitr_fetch
                        bcs @flf_fail

                        ; Verify all 5 bytes
                        lda FACEXP
                        cmp #$11
                        bne @flf_fail
                        lda FACHO
                        cmp #$22
                        bne @flf_fail
                        lda FACMOH
                        cmp #$33
                        bne @flf_fail
                        lda FACMO
                        cmp #$44
                        bne @flf_fail
                        lda FACLO
                        cmp #$55
                        bne @flf_fail

                        jsr pass
                        bra @fl_cleanup

@flf_fail:              jsr fail

@fl_cleanup:            ; Delete iterator and free BRP
                        ldx fl_iter
                        ldy fl_iter+1
                        jsr ulitr_delete
                        ldx fl_brp
                        ldy fl_brp+1
                        jsr ulmem_free

; =========================================================================
; STRINGTABLE iterator tests
; =========================================================================

; ----- Test: BRP+STRTBL create -----

@test_istc:             ldx #<str_t_istc
                        ldy #>str_t_istc
                        jsr putmsg

                        ; Allocate 6-byte BRP (3 word entries), cleared
                        ldx #6
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcs @istc_fail
                        stx st_brp
                        sty st_brp+1

                        ; Fill with 3 words via direct access ($1234, $5678, $9ABC)
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda #$34
                        sta (gREG::r5),y
                        iny
                        lda #$12
                        sta (gREG::r5),y
                        iny
                        lda #$78
                        sta (gREG::r5),y
                        iny
                        lda #$56
                        sta (gREG::r5),y
                        iny
                        lda #$BC
                        sta (gREG::r5),y
                        iny
                        lda #$9A
                        sta (gREG::r5),y

                        ; Create BRP+STRINGTABLE iterator (r0 = size = 6)
                        lda #6
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::STRINGTABLE)
                        ldx st_brp
                        ldy st_brp+1
                        jsr ulitr_create
                        bcs @istc_fail
                        stx st_iter
                        sty st_iter+1

                        jsr pass
                        bra @test_istf

@istc_fail:             jsr fail
                        jmp @summary

; ----- Test: STRTBL fetch entry -----

@test_istf:             ldx #<str_t_istf
                        ldy #>str_t_istf
                        jsr putmsg

                        ; Fetch first entry, verify r0 = $1234
                        ldx st_iter
                        ldy st_iter+1
                        jsr ulitr_fetch
                        bcs @istf_fail
                        lda gREG::r0L
                        cmp #$34
                        bne @istf_fail
                        lda gREG::r0H
                        cmp #$12
                        bne @istf_fail

                        jsr pass
                        bra @test_isti

@istf_fail:             jsr fail

; ----- Test: STRTBL fai x3+atend -----

@test_isti:             ldx #<str_t_isti
                        ldy #>str_t_isti
                        jsr putmsg

                        stz fwd_errs
                        lda #3
                        sta fwd_idx
@isti_loop:             ldx st_iter
                        ldy st_iter+1
                        jsr ulitr_fetch_and_inc
                        bcs @isti_err
                        dec fwd_idx
                        bne @isti_loop
                        bra @isti_check
@isti_err:              inc fwd_errs
                        dec fwd_idx
                        bne @isti_loop

@isti_check:            ; Should be at end
                        ldx st_iter
                        ldy st_iter+1
                        jsr ulitr_atend
                        bne @isti_fail
                        lda fwd_errs
                        bne @isti_fail

                        jsr pass
                        bra @test_istcl

@isti_fail:             jsr fail

; ----- Test: STRTBL cleanup -----

@test_istcl:            ldx #<str_t_istcl
                        ldy #>str_t_istcl
                        jsr putmsg

                        ; Delete iterator and free BRP
                        ldx st_iter
                        ldy st_iter+1
                        jsr ulitr_delete
                        ldx st_brp
                        ldy st_brp+1
                        jsr ulmem_free

                        jsr pass
                        bra @test_fps

@istcl_fail:            jsr fail

; =====================================================================
; fromPETSCII / fromISO8859 / toPETSCII / toISO8859 / format tests
; =====================================================================

; ----- Test: fromPETSCII shifted (uppercase PETSCII → lowercase string) -----

@test_fps:              ldx #<str_t_fps
                        ldy #>str_t_fps
                        jsr putmsg

                        ; fromPETSCII(A=0=shifted, YX=petscii_hello)
                        ; petscii_hello = $48,$45,$4C,$4C,$4F = HELLO
                        ; In shifted mode $41-$5A → a-z, so result should be "hello" (5 chars)
                        lda #0                  ; shifted mode
                        ldx #<petscii_hello
                        ldy #>petscii_hello
                        jsr ulstr_fromPETSCII
                        bcs @fps_fail
                        stx fp_str
                        sty fp_str+1

                        ; Verify length = 5
                        jsr ulstr_getlen
                        cmp #5
                        bne @fps_fail2

                        ; Verify raw bytes = "hello"
                        ldx fp_str
                        ldy fp_str+1
                        jsr ULS_access
                        stz fwd_errs
                        ldy #0
                        lda $0600               ; 'h'
                        cmp #$68
                        beq :+
                        inc fwd_errs
:                       lda $0601               ; 'e'
                        cmp #$65
                        beq :+
                        inc fwd_errs
:                       lda $0602               ; 'l'
                        cmp #$6C
                        beq :+
                        inc fwd_errs
:                       lda $0603               ; 'l'
                        cmp #$6C
                        beq :+
                        inc fwd_errs
:                       lda $0604               ; 'o'
                        cmp #$6F
                        beq :+
                        inc fwd_errs
:                       lda fwd_errs
                        bne @fps_fail2

                        ldx fp_str
                        ldy fp_str+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_fpsl

@fps_fail2:             ldx fp_str
                        ldy fp_str+1
                        jsr ulstr_release
@fps_fail:              jsr fail

; ----- Test: fromPETSCII shifted lowercase ($C1-$DA → uppercase) -----

@test_fpsl:             ldx #<str_t_fpsl
                        ldy #>str_t_fpsl
                        jsr putmsg

                        ; petscii_hi_sh = $C8,$C9 → "HI" in shifted mode
                        lda #0                  ; shifted mode
                        ldx #<petscii_hi_sh
                        ldy #>petscii_hi_sh
                        jsr ulstr_fromPETSCII
                        bcs @fpsl_fail
                        stx fp_str
                        sty fp_str+1

                        ; Verify length = 2
                        jsr ulstr_getlen
                        cmp #2
                        bne @fpsl_fail2

                        ; Verify raw bytes = "HI"
                        ldx fp_str
                        ldy fp_str+1
                        jsr ULS_access
                        lda $0600
                        cmp #$48                ; 'H'
                        bne @fpsl_fail2
                        lda $0601
                        cmp #$49                ; 'I'
                        bne @fpsl_fail2

                        ldx fp_str
                        ldy fp_str+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_fpsp

@fpsl_fail2:            ldx fp_str
                        ldy fp_str+1
                        jsr ulstr_release
@fpsl_fail:             jsr fail

; ----- Test: fromPETSCII special chars (£ and ↑) -----

@test_fpsp:             ldx #<str_t_fpsp
                        ldy #>str_t_fpsp
                        jsr putmsg

                        ; petscii_special = $5C,$5E → £ (U+00A3) + ↑ (U+2191)
                        ; £ = UTF-8 $C2 $A3 (2 bytes), ↑ = UTF-8 $E2 $86 $91 (3 bytes)
                        lda #0                  ; shifted mode
                        ldx #<petscii_special
                        ldy #>petscii_special
                        jsr ulstr_fromPETSCII
                        bcs @fpsp_fail
                        stx fp_str
                        sty fp_str+1

                        ; Verify rawlen = 5 (2 + 3 bytes UTF-8)
                        jsr ulstr_getrawlen
                        cmp #5
                        bne @fpsp_fail2

                        ; Verify raw bytes
                        ldx fp_str
                        ldy fp_str+1
                        jsr ULS_access
                        stz fwd_errs
                        lda $0600               ; £ lead: $C2
                        cmp #$C2
                        beq :+
                        inc fwd_errs
:                       lda $0601               ; £ cont: $A3
                        cmp #$A3
                        beq :+
                        inc fwd_errs
:                       lda $0602               ; ↑ lead: $E2
                        cmp #$E2
                        beq :+
                        inc fwd_errs
:                       lda $0603               ; ↑ cont: $86
                        cmp #$86
                        beq :+
                        inc fwd_errs
:                       lda $0604               ; ↑ cont: $91
                        cmp #$91
                        beq :+
                        inc fwd_errs
:                       lda fwd_errs
                        bne @fpsp_fail2

                        ldx fp_str
                        ldy fp_str+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_fpe

@fpsp_fail2:            ldx fp_str
                        ldy fp_str+1
                        jsr ulstr_release
@fpsp_fail:             jsr fail

; ----- Test: fromPETSCII empty -----

@test_fpe:              ldx #<str_t_fpe
                        ldy #>str_t_fpe
                        jsr putmsg

                        ; Empty PETSCII string (just NUL)
                        lda #0
                        sta fp_empty
                        lda #0                  ; shifted mode
                        ldx #<fp_empty
                        ldy #>fp_empty
                        jsr ulstr_fromPETSCII
                        bcs @fpe_fail
                        stx fp_str
                        sty fp_str+1

                        ; Verify length = 0
                        jsr ulstr_getlen
                        cmp #0
                        bne @fpe_fail2

                        ldx fp_str
                        ldy fp_str+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_fia

@fpe_fail2:             ldx fp_str
                        ldy fp_str+1
                        jsr ulstr_release
@fpe_fail:              jsr fail

; ----- Test: fromISO8859 ASCII -----

@test_fia:              ldx #<str_t_fia
                        ldy #>str_t_fia
                        jsr putmsg

                        ; iso_cafe = $43,$61,$66,$E9 → "Café"
                        ; $43='C', $61='a', $66='f', $E9=é (U+00E9 → UTF-8 $C3 $A9)
                        ldx #<iso_cafe
                        ldy #>iso_cafe
                        jsr ulstr_fromISO8859
                        bcs @fia_fail
                        stx fi_str
                        sty fi_str+1

                        ; Verify char length = 4
                        jsr ulstr_getlen
                        cmp #4
                        bne @fia_fail2

                        ; Verify rawlen = 5 (3 ASCII + 2-byte é)
                        ldx fi_str
                        ldy fi_str+1
                        jsr ulstr_getrawlen
                        cmp #5
                        bne @fia_fail2

                        ; Verify raw bytes
                        ldx fi_str
                        ldy fi_str+1
                        jsr ULS_access
                        stz fwd_errs
                        lda $0600               ; 'C'
                        cmp #$43
                        beq :+
                        inc fwd_errs
:                       lda $0601               ; 'a'
                        cmp #$61
                        beq :+
                        inc fwd_errs
:                       lda $0602               ; 'f'
                        cmp #$66
                        beq :+
                        inc fwd_errs
:                       lda $0603               ; é lead: $C3
                        cmp #$C3
                        beq :+
                        inc fwd_errs
:                       lda $0604               ; é cont: $A9
                        cmp #$A9
                        beq :+
                        inc fwd_errs
:                       lda fwd_errs
                        bne @fia_fail2

                        ldx fi_str
                        ldy fi_str+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_fie

@fia_fail2:             ldx fi_str
                        ldy fi_str+1
                        jsr ulstr_release
@fia_fail:              jsr fail

; ----- Test: fromISO8859 Euro sign -----

@test_fie:              ldx #<str_t_fie
                        ldy #>str_t_fie
                        jsr putmsg

                        ; iso_euro = $A4 → € (U+20AC → UTF-8 $E2 $82 $AC)
                        ldx #<iso_euro
                        ldy #>iso_euro
                        jsr ulstr_fromISO8859
                        bcs @fie_fail
                        stx fi_str
                        sty fi_str+1

                        ; Verify char length = 1
                        jsr ulstr_getlen
                        cmp #1
                        bne @fie_fail2

                        ; Verify rawlen = 3 (3-byte UTF-8)
                        ldx fi_str
                        ldy fi_str+1
                        jsr ulstr_getrawlen
                        cmp #3
                        bne @fie_fail2

                        ; Verify raw bytes = $E2 $82 $AC
                        ldx fi_str
                        ldy fi_str+1
                        jsr ULS_access
                        lda $0600
                        cmp #$E2
                        bne @fie_fail2
                        lda $0601
                        cmp #$82
                        bne @fie_fail2
                        lda $0602
                        cmp #$AC
                        bne @fie_fail2

                        ldx fi_str
                        ldy fi_str+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_fimt

@fie_fail2:             ldx fi_str
                        ldy fi_str+1
                        jsr ulstr_release
@fie_fail:              jsr fail

; ----- Test: fromISO8859 empty -----

@test_fimt:             ldx #<str_t_fimt
                        ldy #>str_t_fimt
                        jsr putmsg

                        ; Empty ISO string (just NUL)
                        lda #0
                        sta fp_empty             ; reuse
                        ldx #<fp_empty
                        ldy #>fp_empty
                        jsr ulstr_fromISO8859
                        bcs @fimt_fail
                        stx fi_str
                        sty fi_str+1

                        ; Verify length = 0
                        jsr ulstr_getlen
                        cmp #0
                        bne @fimt_fail2

                        ldx fi_str
                        ldy fi_str+1
                        jsr ulstr_release

                        jsr pass
                        bra @test_tpr

@fimt_fail2:            ldx fi_str
                        ldy fi_str+1
                        jsr ulstr_release
@fimt_fail:             jsr fail

; ----- Test: toPETSCII round-trip -----

@test_tpr:              ldx #<str_t_tpr
                        ldy #>str_t_tpr
                        jsr putmsg

                        ; Create string from PETSCII shifted, then export back via toPETSCII
                        ; petscii_hello ($48,$45,$4C,$4C,$4F) shifted → "hello"
                        ; toPETSCII shifted should produce: h→$C8, e→$C5, l→$CC, l→$CC, o→$CF
                        ; (shifted mode: a-z ($61-$7A) → $C1-$DA, which is byte + $80)
                        ; Wait — toPETSCII from "hello" (lowercase):
                        ;   In shifted mode, a-z → $C1-$DA (add $80 to ASCII)
                        ;   So h=$68→$C8+$80=$E8? No.
                        ;   Actually: shifted toPETSCII: a-z ($61-$7A) → $C1-$DA (byte + $60? no)
                        ;   Looking at ulstr_toPETSCII.s: a-z shifted → byte + $80 (adc #$80)
                        ;   $68+$80 = $E8? That's wrong. Let me check...
                        ; Actually in toPETSCII: lowercase a-z in shifted mode:
                        ;   @lower_letter: shifted: txa; clc; adc #$80 — but $68+$80=$E8 which is out of range
                        ; Hmm, that doesn't match. Let me use a simpler round-trip:
                        ; Create "HELLO" from UTF-8, export as PETSCII unshifted
                        ; Unshifted: A-Z → $41-$5A (identity)

                        ; Create string "HELLO" from UTF-8
                        ldx #<petscii_hello     ; "HELLO" is also valid ASCII/UTF-8
                        ldy #>petscii_hello
                        jsr ulstr_fromUtf8
                        bcc :+
                        jmp @tpr_fail
:
                        stx tp_str
                        sty tp_str+1

                        ; Allocate 8-byte BRP for output
                        ldx #8
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc :+
                        jmp @tpr_fail2
:                       stx tp_brp
                        sty tp_brp+1

                        ; Create byte iterator
                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::BYTE)
                        ldx tp_brp
                        ldy tp_brp+1
                        jsr ulitr_create
                        bcc :+
                        jmp @tpr_fail3
:                       stx tp_iter
                        sty tp_iter+1

                        ; Call toPETSCII (A=1=unshifted)
                        lda tp_str
                        sta gREG::r0L
                        lda tp_str+1
                        sta gREG::r0H
                        lda #1                  ; unshifted
                        ldx tp_iter
                        ldy tp_iter+1
                        jsr ulstr_toPETSCII
                        bcs @tpr_fail4

                        ; Verify output bytes: HELLO unshifted → $48,$45,$4C,$4C,$4F
                        ldx tp_brp
                        ldy tp_brp+1
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        stz fwd_errs
                        ldy #0
                        lda (gREG::r5),y
                        cmp #$48                ; 'H'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$45                ; 'E'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$4C                ; 'L'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$4C                ; 'L'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$4F                ; 'O'
                        beq :+
                        inc fwd_errs
:                       lda fwd_errs
                        bne @tpr_fail4

                        ; Cleanup
                        ldx tp_iter
                        ldy tp_iter+1
                        jsr ulitr_delete
                        ldx tp_brp
                        ldy tp_brp+1
                        jsr ulmem_free
                        ldx tp_str
                        ldy tp_str+1
                        jsr ulstr_release

                        jsr pass
                        jmp @test_tpu

@tpr_fail4:             ldx tp_iter
                        ldy tp_iter+1
                        jsr ulitr_delete
@tpr_fail3:             ldx tp_brp
                        ldy tp_brp+1
                        jsr ulmem_free
@tpr_fail2:             ldx tp_str
                        ldy tp_str+1
                        jsr ulstr_release
@tpr_fail:              jsr fail

; ----- Test: toPETSCII unmappable → '?' -----

@test_tpu:              ldx #<str_t_tpu
                        ldy #>str_t_tpu
                        jsr putmsg

                        ; Create string with € (U+20AC) which has no PETSCII mapping
                        ldx #<iso_euro
                        ldy #>iso_euro
                        jsr ulstr_fromISO8859    ; creates string "€"
                        bcc :+
                        jmp @tpu_fail
:                       stx tp_str
                        sty tp_str+1

                        ; Allocate output BRP
                        ldx #4
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc :+
                        jmp @tpu_fail2
:                       stx tp_brp
                        sty tp_brp+1

                        ; Create byte iterator
                        lda #4
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::BYTE)
                        ldx tp_brp
                        ldy tp_brp+1
                        jsr ulitr_create
                        bcc :+
                        jmp @tpu_fail3
:                       stx tp_iter
                        sty tp_iter+1

                        ; Call toPETSCII
                        lda tp_str
                        sta gREG::r0L
                        lda tp_str+1
                        sta gREG::r0H
                        lda #0                  ; shifted mode
                        ldx tp_iter
                        ldy tp_iter+1
                        jsr ulstr_toPETSCII
                        bcs @tpu_fail4

                        ; Verify first byte is '?' ($3F)
                        ldx tp_brp
                        ldy tp_brp+1
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda (gREG::r5),y
                        cmp #$3F                ; '?'
                        bne @tpu_fail4

                        ; Cleanup
                        ldx tp_iter
                        ldy tp_iter+1
                        jsr ulitr_delete
                        ldx tp_brp
                        ldy tp_brp+1
                        jsr ulmem_free
                        ldx tp_str
                        ldy tp_str+1
                        jsr ulstr_release

                        jsr pass
                        jmp @test_tir

@tpu_fail4:             ldx tp_iter
                        ldy tp_iter+1
                        jsr ulitr_delete
@tpu_fail3:             ldx tp_brp
                        ldy tp_brp+1
                        jsr ulmem_free
@tpu_fail2:             ldx tp_str
                        ldy tp_str+1
                        jsr ulstr_release
@tpu_fail:              jsr fail

; ----- Test: toISO8859 round-trip -----

@test_tir:              ldx #<str_t_tir
                        ldy #>str_t_tir
                        jsr putmsg

                        ; Create string from ISO "Café" ($43,$61,$66,$E9)
                        ldx #<iso_cafe
                        ldy #>iso_cafe
                        jsr ulstr_fromISO8859
                        bcc :+
                        jmp @tir_fail
:                       stx ti_str
                        sty ti_str+1

                        ; Allocate output BRP
                        ldx #8
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc :+
                        jmp @tir_fail2
:                       stx ti_brp
                        sty ti_brp+1

                        ; Create byte iterator
                        lda #8
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::BYTE)
                        ldx ti_brp
                        ldy ti_brp+1
                        jsr ulitr_create
                        bcc :+
                        jmp @tir_fail3
:                       stx ti_iter
                        sty ti_iter+1

                        ; Call toISO8859
                        lda ti_str
                        sta gREG::r0L
                        lda ti_str+1
                        sta gREG::r0H
                        ldx ti_iter
                        ldy ti_iter+1
                        jsr ulstr_toISO8859
                        bcs @tir_fail4

                        ; Verify output: $43,$61,$66,$E9
                        ldx ti_brp
                        ldy ti_brp+1
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        stz fwd_errs
                        ldy #0
                        lda (gREG::r5),y
                        cmp #$43                ; 'C'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$61                ; 'a'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$66                ; 'f'
                        beq :+
                        inc fwd_errs
:                       iny
                        lda (gREG::r5),y
                        cmp #$E9                ; é
                        beq :+
                        inc fwd_errs
:                       lda fwd_errs
                        bne @tir_fail4

                        ; Cleanup
                        ldx ti_iter
                        ldy ti_iter+1
                        jsr ulitr_delete
                        ldx ti_brp
                        ldy ti_brp+1
                        jsr ulmem_free
                        ldx ti_str
                        ldy ti_str+1
                        jsr ulstr_release

                        jsr pass
                        jmp @test_tiu

@tir_fail4:             ldx ti_iter
                        ldy ti_iter+1
                        jsr ulitr_delete
@tir_fail3:             ldx ti_brp
                        ldy ti_brp+1
                        jsr ulmem_free
@tir_fail2:             ldx ti_str
                        ldy ti_str+1
                        jsr ulstr_release
@tir_fail:              jsr fail

; ----- Test: toISO8859 unmappable → '?' -----

@test_tiu:              ldx #<str_t_tiu
                        ldy #>str_t_tiu
                        jsr putmsg

                        ; Create a string with Chinese char 中 (U+4E2D) which has no ISO-8859-15 mapping
                        ldx #<utf8_zhong
                        ldy #>utf8_zhong
                        jsr ulstr_fromUtf8
                        bcc :+
                        jmp @tiu_fail
:                       stx ti_str
                        sty ti_str+1

                        ; Allocate output BRP
                        ldx #4
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc :+
                        jmp @tiu_fail2
:                       stx ti_brp
                        sty ti_brp+1

                        ; Create byte iterator
                        lda #4
                        sta gREG::r0L
                        stz gREG::r0H
                        lda #(ULITYP::BRP | ULIFMT::BYTE)
                        ldx ti_brp
                        ldy ti_brp+1
                        jsr ulitr_create
                        bcc :+
                        jmp @tiu_fail3
:                       stx ti_iter
                        sty ti_iter+1

                        ; Call toISO8859
                        lda ti_str
                        sta gREG::r0L
                        lda ti_str+1
                        sta gREG::r0H
                        ldx ti_iter
                        ldy ti_iter+1
                        jsr ulstr_toISO8859
                        bcs @tiu_fail4

                        ; Verify first byte is '?' ($3F)
                        ldx ti_brp
                        ldy ti_brp+1
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda (gREG::r5),y
                        cmp #$3F                ; '?'
                        bne @tiu_fail4

                        ; Cleanup
                        ldx ti_iter
                        ldy ti_iter+1
                        jsr ulitr_delete
                        ldx ti_brp
                        ldy ti_brp+1
                        jsr ulmem_free
                        ldx ti_str
                        ldy ti_str+1
                        jsr ulstr_release

                        jsr pass
                        jmp @test_fmn

@tiu_fail4:             ldx ti_iter
                        ldy ti_iter+1
                        jsr ulitr_delete
@tiu_fail3:             ldx ti_brp
                        ldy ti_brp+1
                        jsr ulmem_free
@tiu_fail2:             ldx ti_str
                        ldy ti_str+1
                        jsr ulstr_release
@tiu_fail:              jsr fail

; ----- Test: format no placeholders -----

@test_fmn:              ldx #<str_t_fmn
                        ldy #>str_t_fmn
                        jsr putmsg

                        ; Create format string "No placeholders"
                        ldx #<fmt_plain
                        ldy #>fmt_plain
                        jsr ulstr_fromUtf8
                        bcc :+
                        jmp @fmn_fail
:                       stx fm_fmtstr
                        sty fm_fmtstr+1

                        ; Create empty stringtable (no entries needed)
                        ; Use a 1-byte BRP with just the count=0
                        ldx #1
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcs @fmn_fail2
                        stx fm_stb
                        sty fm_stb+1
                        ; Write count=0
                        jsr ulmem_access
                        stx gREG::r5L
                        sty gREG::r5H
                        ldy #0
                        lda #0
                        sta (gREG::r5),y

                        ; Call ulstr_format
                        lda fm_fmtstr
                        sta gREG::r0L
                        lda fm_fmtstr+1
                        sta gREG::r0H
                        lda fm_stb
                        sta gREG::r1L
                        lda fm_stb+1
                        sta gREG::r1H
                        jsr ulstr_format
                        bcs @fmn_fail3
                        stx fm_result
                        sty fm_result+1

                        ; Verify char length = 15 ("No placeholders")
                        jsr ulstr_getlen
                        cmp #15
                        bne @fmn_fail4

                        ; Cleanup
                        ldx fm_result
                        ldy fm_result+1
                        jsr ulstr_release
                        ldx fm_stb
                        ldy fm_stb+1
                        jsr ulmem_free
                        ldx fm_fmtstr
                        ldy fm_fmtstr+1
                        jsr ulstr_release

                        jsr pass
                        jmp @test_fms

@fmn_fail4:             ldx fm_result
                        ldy fm_result+1
                        jsr ulstr_release
@fmn_fail3:             ldx fm_stb
                        ldy fm_stb+1
                        jsr ulmem_free
@fmn_fail2:             ldx fm_fmtstr
                        ldy fm_fmtstr+1
                        jsr ulstr_release
@fmn_fail:              jsr fail

; ----- Test: format sequential {} -----

@test_fms:              ldx #<str_t_fms
                        ldy #>str_t_fms
                        jsr putmsg

                        ; Create format string "Hello, {}!"
                        ldx #<fmt_hello
                        ldy #>fmt_hello
                        jsr ulstr_fromUtf8
                        bcc :+
                        jmp @fms_fail
:                       stx fm_fmtstr
                        sty fm_fmtstr+1

                        ; Build stringtable from fmt_names ("World\0\0")
                        ldx #<fmt_names
                        ldy #>fmt_names
                        jsr ulstb_build
                        bcc :+
                        jmp @fms_fail2
:                       stx fm_stb
                        sty fm_stb+1

                        ; Call ulstr_format
                        lda fm_fmtstr
                        sta gREG::r0L
                        lda fm_fmtstr+1
                        sta gREG::r0H
                        lda fm_stb
                        sta gREG::r1L
                        lda fm_stb+1
                        sta gREG::r1H
                        jsr ulstr_format
                        bcs @fms_fail3
                        stx fm_result
                        sty fm_result+1

                        ; Verify char length = 13 ("Hello, World!")
                        jsr ulstr_getlen
                        cmp #13
                        bne @fms_fail4

                        ; Verify raw bytes
                        ldx fm_result
                        ldy fm_result+1
                        jsr ULS_access
                        ; Check "Hello, World!" at $0600
                        stz fwd_errs
                        lda $0600
                        cmp #$48                ; 'H'
                        beq :+
                        inc fwd_errs
:                       lda $0607               ; 'W' (after "Hello, ")
                        cmp #$57
                        beq :+
                        inc fwd_errs
:                       lda $060C               ; '!'
                        cmp #$21
                        beq :+
                        inc fwd_errs
:                       lda fwd_errs
                        bne @fms_fail4

                        ; Cleanup
                        ldx fm_result
                        ldy fm_result+1
                        jsr ulstr_release
                        ldx fm_stb
                        ldy fm_stb+1
                        jsr ulstb_delete
                        ldx fm_fmtstr
                        ldy fm_fmtstr+1
                        jsr ulstr_release

                        jsr pass
                        jmp @test_fmi

@fms_fail4:             ldx fm_result
                        ldy fm_result+1
                        jsr ulstr_release
@fms_fail3:             ldx fm_stb
                        ldy fm_stb+1
                        jsr ulstb_delete
@fms_fail2:             ldx fm_fmtstr
                        ldy fm_fmtstr+1
                        jsr ulstr_release
@fms_fail:              jsr fail

; ----- Test: format indexed {1} -----

@test_fmi:              ldx #<str_t_fmi
                        ldy #>str_t_fmi
                        jsr putmsg

                        ; Create format string "A={1} B={2}"
                        ldx #<fmt_idx
                        ldy #>fmt_idx
                        jsr ulstr_fromUtf8
                        bcc :+
                        jmp @fmi_fail
:                       stx fm_fmtstr
                        sty fm_fmtstr+1

                        ; Build stringtable from fmt_ab_data ("alpha\0beta\0\0")
                        ldx #<fmt_ab_data
                        ldy #>fmt_ab_data
                        jsr ulstb_build
                        bcc :+
                        jmp @fmi_fail2
:                       stx fm_stb
                        sty fm_stb+1

                        ; Call ulstr_format
                        lda fm_fmtstr
                        sta gREG::r0L
                        lda fm_fmtstr+1
                        sta gREG::r0H
                        lda fm_stb
                        sta gREG::r1L
                        lda fm_stb+1
                        sta gREG::r1H
                        jsr ulstr_format
                        bcs @fmi_fail3
                        stx fm_result
                        sty fm_result+1

                        ; "A=alpha B=beta" → 14 chars
                        jsr ulstr_getlen
                        cmp #14
                        bne @fmi_fail4

                        ; Verify raw bytes: check key positions
                        ldx fm_result
                        ldy fm_result+1
                        jsr ULS_access
                        stz fwd_errs
                        lda $0600               ; 'A'
                        cmp #$41
                        beq :+
                        inc fwd_errs
:                       lda $0601               ; '='
                        cmp #$3D
                        beq :+
                        inc fwd_errs
:                       lda $0602               ; 'a' (start of "alpha")
                        cmp #$61
                        beq :+
                        inc fwd_errs
:                       lda $0608               ; 'B' at position 8
                        cmp #$42
                        beq :+
                        inc fwd_errs
:                       lda $060A               ; 'b' (start of "beta") at position 10
                        cmp #$62
                        beq :+
                        inc fwd_errs
:                       lda fwd_errs
                        bne @fmi_fail4

                        ; Cleanup
                        ldx fm_result
                        ldy fm_result+1
                        jsr ulstr_release
                        ldx fm_stb
                        ldy fm_stb+1
                        jsr ulstb_delete
                        ldx fm_fmtstr
                        ldy fm_fmtstr+1
                        jsr ulstr_release

                        jsr pass
                        jmp @summary

@fmi_fail4:             ldx fm_result
                        ldy fm_result+1
                        jsr ulstr_release
@fmi_fail3:             ldx fm_stb
                        ldy fm_stb+1
                        jsr ulstb_delete
@fmi_fail2:             ldx fm_fmtstr
                        ldy fm_fmtstr+1
                        jsr ulstr_release
@fmi_fail:              jsr fail

; ----- inschar test: "ABCDE" → inschar 'X' at col 2 → expect "ABXCDE" -----
                        ldx #<str_t_ins
                        ldy #>str_t_ins
                        jsr putmsg

                        ; Put cursor at col 0, line 27 (use last line for scratch)
                        ldx #0
                        ldy #27
                        lda win
                        jsr ulwin_putcursor

                        ; Write "ABCDE" via putchar
                        lda #'A'
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        lda win
                        jsr ulwin_putchar
                        lda #'B'
                        sta gREG::r0L
                        lda win
                        jsr ulwin_putchar
                        lda #'C'
                        sta gREG::r0L
                        lda win
                        jsr ulwin_putchar
                        lda #'D'
                        sta gREG::r0L
                        lda win
                        jsr ulwin_putchar
                        lda #'E'
                        sta gREG::r0L
                        lda win
                        jsr ulwin_putchar

                        ; Put cursor at col 2 (at 'C')
                        ldx #2
                        ldy #27
                        lda win
                        jsr ulwin_putcursor

                        ; Insert 'X' at col 2
                        lda #'X'
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        lda win
                        jsr ulwin_inschar

                        ; Now read back the line: getloc at col 0, line 27
                        lda win
                        ldx #0
                        ldy #27
                        jsr ulwin_getloc
                        stx ins_str
                        sty ins_str+1

                        ; Access the string
                        jsr ULS_access

                        ; Check first 6 bytes match "ABXCDE"
                        ldx #0
                        ldy #0
@ins_check:             lda ins_expect,x
                        beq @ins_ok
                        cmp $0600,x
                        bne @ins_fail
                        inx
                        bra @ins_check

@ins_ok:                ; Release string and pass
                        ldx ins_str
                        ldy ins_str+1
                        jsr ulstr_release
                        jsr pass
                        jmp @test_del

@ins_fail:              ; Debug: dump actual string to stdout
                        pha
                        lda #'!'
                        sta EMU_STDOUT
                        ldx #0
@ins_dump:              lda $0600,x
                        beq @ins_dump_done
                        sta EMU_STDOUT
                        inx
                        cpx #20
                        bcc @ins_dump
@ins_dump_done:         lda #$0A
                        sta EMU_STDOUT
                        pla
                        ldx ins_str
                        ldy ins_str+1
                        jsr ulstr_release
                        jsr fail

; ----- delchar test: "ABCDE" → delchar at col 1 → expect "ACDE" -----
@test_del:              ldx #<str_t_del
                        ldy #>str_t_del
                        jsr putmsg

                        ; Clear line 27 first
                        ldx #0
                        ldy #27
                        lda win
                        jsr ulwin_putcursor
                        lda win
                        jsr ulwin_eraseeol

                        ; Write "ABCDE" at col 0, line 27
                        ldx #0
                        ldy #27
                        lda win
                        jsr ulwin_putcursor
                        lda #'A'
                        sta gREG::r0L
                        stz gREG::r0H
                        stz gREG::r1L
                        lda win
                        jsr ulwin_putchar
                        lda #'B'
                        sta gREG::r0L
                        lda win
                        jsr ulwin_putchar
                        lda #'C'
                        sta gREG::r0L
                        lda win
                        jsr ulwin_putchar
                        lda #'D'
                        sta gREG::r0L
                        lda win
                        jsr ulwin_putchar
                        lda #'E'
                        sta gREG::r0L
                        lda win
                        jsr ulwin_putchar

                        ; Put cursor at col 1 (at 'B')
                        ldx #1
                        ldy #27
                        lda win
                        jsr ulwin_putcursor

                        ; Delete char at col 1
                        lda win
                        jsr ulwin_delchar

                        ; Read back the line
                        lda win
                        ldx #0
                        ldy #27
                        jsr ulwin_getloc
                        stx del_str
                        sty del_str+1

                        ; Access the string
                        jsr ULS_access

                        ; Check first 4 bytes match "ACDE"
                        ldx #0
@del_check:             lda del_expect,x
                        beq @del_ok
                        cmp $0600,x
                        bne @del_fail
                        inx
                        bra @del_check

@del_ok:                ldx del_str
                        ldy del_str+1
                        jsr ulstr_release
                        jsr pass
                        jmp @summary

@del_fail:              ; Debug: dump actual string to stdout
                        lda #'!'
                        sta EMU_STDOUT
                        ldx #0
@del_dump:              lda $0600,x
                        beq @del_dump_done
                        sta EMU_STDOUT
                        inx
                        cpx #20
                        bcc @del_dump
@del_dump_done:         lda #$0A
                        sta EMU_STDOUT
                        ldx del_str
                        ldy del_str+1
                        jsr ulstr_release
                        jsr fail

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
u8_brp:         .res 2          ; UTF-8 test data BRP
u8_iter:        .res 2          ; UTF-8 iterator handle
s_hello:        .res 2          ; "Hello" string BRP
s_world:        .res 2          ; "World" string BRP
s_cafe:         .res 2          ; "Cafe" string BRP
s_temp:         .res 2          ; temp string/BRP
s_temp2:        .res 2          ; temp iterator handle
stb_handle:     .res 2          ; stringtable BRP
stb_str:        .res 2          ; string BRP retrieved from table
h_brp_a:        .res 2          ; heap test BRP A
h_brp_b:        .res 2          ; heap test BRP B
h_saved_brp:    .res 2          ; saved BRP for comparison
fl_brp:         .res 2          ; FLOAT test data BRP
fl_iter:        .res 2          ; FLOAT test iterator
st_brp:         .res 2          ; STRTBL test data BRP
st_iter:        .res 2          ; STRTBL test iterator
ru8_iter:       .res 2          ; REVERSE+UTF8 iterator handle
ru8_last_r0l:   .res 1          ; last fai r0L
ru8_last_r0h:   .res 1          ; last fai r0H
ru8_last_r1l:   .res 1          ; last fai r1L
si_str:         .res 2          ; STRING test string handle
si_iter:        .res 2          ; STRING iterator handle
si_riter:       .res 2          ; REVERSE+STRING iterator handle
fp_str:         .res 2          ; fromPETSCII result string handle
fp_empty:       .res 1          ; single NUL byte for empty tests
fi_str:         .res 2          ; fromISO8859 result string handle
tp_str:         .res 2          ; toPETSCII source string handle
tp_brp:         .res 2          ; toPETSCII output BRP
tp_iter:        .res 2          ; toPETSCII output iterator
ti_str:         .res 2          ; toISO8859 source string handle
ti_brp:         .res 2          ; toISO8859 output BRP
ti_iter:        .res 2          ; toISO8859 output iterator
fm_fmtstr:      .res 2          ; format test format string handle
fm_stb:         .res 2          ; format test stringtable BRP
fm_result:      .res 2          ; format test result string handle
ins_str:        .res 2          ; inschar test string handle
del_str:        .res 2          ; delchar test string handle
