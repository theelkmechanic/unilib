.include "unilib_impl.inc"

UL_CODE

; ulstr_format - Create a formatted string with stringtable substitutions
;   In: r0              - Format string handle (MSGBLOCK pool index)
;       r1              - Stringtable BRP
;  Out: YX              - New string handle (MSGBLOCK pool index)
;       carry           - Set on error
;
;  Format placeholders:
;   {} = replaced with successive stringtable entries (1-based, starting at 1)
;   {N} = replaced with stringtable entry N (1-based decimal number)
.proc ulstr_format
                        ; Save caller's r0 (KERNAL convention)
                        lda gREG::r0L
                        pha
                        lda gREG::r0H
                        pha

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save stringtable BRP
                        lda gREG::r1L
                        sta ULSFM_stb
                        lda gREG::r1H
                        sta ULSFM_stb+1

                        ; Access format string → data at SCRATCH ($0600)
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Get format string raw length
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulstr_getrawlen
                        sta ULSFM_fmtlen

                        ; Copy SCRATCH ($0600) to SCRATCH2 ($0700) — preserve format for both passes
                        lda ULSFM_fmtlen
                        bne :+
                        jmp @empty_format
:                       tay
                        ; Copy bytelen bytes + NUL terminator
@copy_loop:             lda UL_SCRATCH_BASE,y
                        sta UL_SCRATCH2_BASE,y
                        dey
                        bpl @copy_loop

                        ; === Pass 1: compute output size ===
                        stz ULSFM_outlen
                        stz ULSFM_fmtpos
                        lda #1
                        sta ULSFM_seqidx        ; sequential placeholder index (1-based)

@p1_loop:               ldy ULSFM_fmtpos
                        cpy ULSFM_fmtlen
                        bcc :+
                        jmp @p1_done            ; past end of format
:
                        lda UL_SCRATCH2_BASE,y
                        cmp #'{'
                        beq @p1_placeholder

                        ; Literal byte: add 1 to output length
                        inc ULSFM_outlen
                        inc ULSFM_fmtpos
                        jmp @p1_loop

@p1_placeholder:        ; Check what follows '{'
                        iny
                        cpy ULSFM_fmtlen
                        bcc :+
                        jmp @p1_literal_brace   ; '{' at end → literal
:
                        lda UL_SCRATCH2_BASE,y

                        ; '}' → sequential placeholder
                        cmp #'}'
                        beq @p1_sequential

                        ; '0'-'9' → indexed placeholder
                        cmp #'0'
                        bcc @p1_lit_near
                        cmp #'9'+1
                        bcc @p1_parse_index_jmp
@p1_lit_near:           jmp @p1_literal_brace

@p1_parse_index_jmp:    jmp @p1_parse_index

@p1_sequential:         ; Sequential: get string at ULSFM_seqidx
                        lda ULSFM_stb
                        sta gREG::r0L
                        lda ULSFM_stb+1
                        sta gREG::r0H
                        lda ULSFM_seqidx
                        jsr ulstb_get
                        bcc :+
                        jmp @fail_p1
:
                        ; Get rawlen and add to output
                        jsr ulstr_getrawlen
                        clc
                        adc ULSFM_outlen
                        sta ULSFM_outlen
                        bcc :+
                        jmp @too_long           ; overflow
:
                        inc ULSFM_seqidx
                        ; Skip past '}'
                        inc ULSFM_fmtpos
                        inc ULSFM_fmtpos
                        jmp @p1_loop

@p1_parse_index:        ; Y points to first digit after '{'
                        ; Parse 1-3 digit decimal number
                        stz ULSFM_parseval
                        ldy ULSFM_fmtpos
                        iny                     ; skip '{'

@p1_digit:              cpy ULSFM_fmtlen
                        bcc :+
                        jmp @p1_literal_brace   ; ran off end
:
                        lda UL_SCRATCH2_BASE,y
                        cmp #'}'
                        beq @p1_got_index

                        ; Must be a digit
                        cmp #'0'
                        bcc @p1_notdigit
                        cmp #'9'+1
                        bcc @p1_isdigit
@p1_notdigit:           jmp @p1_literal_brace   ; not a digit → treat { as literal

@p1_isdigit:            ; Accumulate: val = val * 10 + digit
                        sec
                        sbc #'0'
                        pha                     ; save digit

                        ; Multiply current value by 10: val*8 + val*2
                        lda ULSFM_parseval
                        cmp #26                 ; max safe value for *10: 25*10=250
                        bcs @p1_overflow
                        asl                     ; *2
                        sta ULSFM_temp
                        asl                     ; *4
                        asl                     ; *8
                        clc
                        adc ULSFM_temp          ; *10
                        sta ULSFM_parseval

                        pla                     ; restore digit
                        clc
                        adc ULSFM_parseval
                        sta ULSFM_parseval

                        iny
                        bra @p1_digit

@p1_overflow:           pla                     ; discard digit
                        bra @p1_literal_brace

@p1_got_index:          ; Y points to closing '}'
                        ; ULSFM_parseval = index
                        lda ULSFM_parseval
                        beq @p1_literal_brace   ; {0} → treat as literal (stb is 1-based)

                        ; Save position past '}' before calls clobber Y
                        iny                     ; past '}'
                        sty ULSFM_fmtpos

                        ; Get string at index
                        lda ULSFM_stb
                        sta gREG::r0L
                        lda ULSFM_stb+1
                        sta gREG::r0H
                        lda ULSFM_parseval
                        jsr ulstb_get
                        bcc :+
                        jmp @fail_p1
:
                        ; Get rawlen and add to output
                        jsr ulstr_getrawlen
                        clc
                        adc ULSFM_outlen
                        sta ULSFM_outlen
                        bcc :+
                        jmp @too_long
:
                        jmp @p1_loop

@p1_literal_brace:      ; Treat '{' as a literal character
                        inc ULSFM_outlen
                        inc ULSFM_fmtpos
                        jmp @p1_loop

@too_long:              lda #ULERR::STRING_TOO_LONG
                        sta UL_lasterr
                        jmp @fail

@p1_done:               ; Check output length
                        lda ULSFM_outlen
                        cmp #253
                        bcs @too_long

                        ; === Allocate output data block ===
                        lda ULSFM_outlen
                        bne :+
                        jmp @empty_format
:
                        ldx ULSFM_outlen
                        ldy #0
                        jsr uldb_create
                        bcc :+
                        jmp @fail
:                       stx ULSFM_db
                        sty ULSFM_db+1

                        ; Get data block's base address
                        jsr uldb_getbrp
                        jsr ulmem_access
                        stx ULSFM_outptr
                        sty ULSFM_outptr+1
                        lda BANKSEL::RAM
                        sta ULSFM_outbank

                        ; === Pass 2: build output ===
                        stz ULSFM_fmtpos
                        stz ULSFM_outoff
                        lda #1
                        sta ULSFM_seqidx

@p2_loop:               ldy ULSFM_fmtpos
                        cpy ULSFM_fmtlen
                        bcc :+
                        jmp @p2_done
:
                        lda UL_SCRATCH2_BASE,y
                        cmp #'{'
                        beq @p2_placeholder

                        ; Literal byte: write to output
                        lda ULSFM_outbank
                        sta BANKSEL::RAM
                        lda ULSFM_outptr
                        sta UL_varptr
                        lda ULSFM_outptr+1
                        sta UL_varptr+1

                        ldy ULSFM_fmtpos
                        lda UL_SCRATCH2_BASE,y  ; safe: $0700 always accessible
                        ldy ULSFM_outoff
                        sta (UL_varptr),y
                        inc ULSFM_outoff
                        inc ULSFM_fmtpos
                        jmp @p2_loop

@p2_placeholder:        ; Same parsing as pass 1
                        iny
                        cpy ULSFM_fmtlen
                        bcc :+
                        jmp @p2_literal_brace
:
                        lda UL_SCRATCH2_BASE,y
                        cmp #'}'
                        beq @p2_sequential
                        cmp #'0'
                        bcc @p2_lit_near
                        cmp #'9'+1
                        bcc @p2_parse_index_jmp
@p2_lit_near:           jmp @p2_literal_brace

@p2_parse_index_jmp:    jmp @p2_parse_index

@p2_sequential:         ; Get replacement string
                        lda ULSFM_stb
                        sta gREG::r0L
                        lda ULSFM_stb+1
                        sta gREG::r0H
                        lda ULSFM_seqidx
                        jsr ulstb_get
                        ; (We know this succeeds — pass 1 validated it)

                        ; Save returned handle, get rawlen before ULS_access clobbers it
                        stx ULSFM_repstr
                        sty ULSFM_repstr+1
                        jsr ulstr_getrawlen
                        sta ULSFM_copylen

                        ; Access replacement → SCRATCH ($0600)
                        ldx ULSFM_repstr
                        ldy ULSFM_repstr+1
                        jsr ULS_access

                        ; Copy replacement to output
                        jsr @copy_replacement

                        inc ULSFM_seqidx
                        ; Skip past '{}'
                        inc ULSFM_fmtpos
                        inc ULSFM_fmtpos
                        jmp @p2_loop

@p2_parse_index:        ; Parse decimal index (same as pass 1)
                        stz ULSFM_parseval
                        ldy ULSFM_fmtpos
                        iny

@p2_digit:              cpy ULSFM_fmtlen
                        bcs @p2_literal_brace

                        lda UL_SCRATCH2_BASE,y
                        cmp #'}'
                        beq @p2_got_index
                        cmp #'0'
                        bcc @p2_literal_brace
                        cmp #'9'+1
                        bcs @p2_literal_brace

                        sec
                        sbc #'0'
                        pha
                        lda ULSFM_parseval
                        cmp #26
                        bcs @p2_idx_overflow
                        asl
                        sta ULSFM_temp
                        asl
                        asl
                        clc
                        adc ULSFM_temp
                        sta ULSFM_parseval
                        pla
                        clc
                        adc ULSFM_parseval
                        sta ULSFM_parseval
                        iny
                        bra @p2_digit

@p2_idx_overflow:       pla
                        bra @p2_literal_brace

@p2_got_index:          lda ULSFM_parseval
                        beq @p2_literal_brace

                        ; Get replacement string
                        lda ULSFM_stb
                        sta gREG::r0L
                        lda ULSFM_stb+1
                        sta gREG::r0H
                        lda ULSFM_parseval
                        jsr ulstb_get
                        stx ULSFM_repstr
                        sty ULSFM_repstr+1

                        ; Get rawlen first (before ULS_access clobbers things)
                        jsr ulstr_getrawlen
                        sta ULSFM_copylen

                        ; Access replacement → SCRATCH ($0600)
                        ldx ULSFM_repstr
                        ldy ULSFM_repstr+1
                        jsr ULS_access

                        ; Copy replacement to output
                        jsr @copy_replacement

                        ; Advance fmtpos past {N}
                        ; Y was clobbered — reload from ULSFM_fmtpos and rescan to '}'
                        ldy ULSFM_fmtpos
                        iny                     ; skip '{'
@p2_skip_idx:           lda UL_SCRATCH2_BASE,y
                        iny
                        cmp #'}'
                        bne @p2_skip_idx
                        sty ULSFM_fmtpos
                        jmp @p2_loop

@p2_literal_brace:      ; Write '{' as literal
                        lda ULSFM_outbank
                        sta BANKSEL::RAM
                        lda ULSFM_outptr
                        sta UL_varptr
                        lda ULSFM_outptr+1
                        sta UL_varptr+1

                        lda #'{'
                        ldy ULSFM_outoff
                        sta (UL_varptr),y
                        inc ULSFM_outoff
                        inc ULSFM_fmtpos
                        jmp @p2_loop

@p2_done:               ; === Allocate MSGBLOCK and fill fields ===
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_alloc
                        bcc :+
                        jmp @fail_free_db
:                       stx ULSFM_mb
                        sty ULSFM_mb+1

                        ; Access MB to write fields
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; data_block = db handle
                        ldy #ULMSG_BLOCK::data_block
                        lda ULSFM_db
                        sta (UL_varptr),y
                        iny
                        lda ULSFM_db+1
                        sta (UL_varptr),y

                        ; start = 0
                        ldy #ULMSG_BLOCK::start
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; end = outlen
                        ldy #ULMSG_BLOCK::end
                        lda ULSFM_outlen
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; cont = $0000
                        ldy #ULMSG_BLOCK::cont
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; next = $0000
                        ldy #ULMSG_BLOCK::next
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; prev = $0000
                        ldy #ULMSG_BLOCK::prev
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; type = STRING_FRAG, flags = 0
                        ldy #ULMSG_BLOCK::type
                        lda #ULMBT::STRING_FRAG
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; Return MB handle in YX
                        ldx ULSFM_mb
                        ldy ULSFM_mb+1
                        pla
                        sta BANKSEL::RAM
                        ; Restore caller's r0 (carry/YX preserved)
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        clc
                        rts

@empty_format:          ; Empty format string → create empty string
                        pla
                        sta BANKSEL::RAM
                        ; Restore caller's r0 (ulstr_fromUtf8 doesn't clobber r0)
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        ldx #<@empty_str
                        ldy #>@empty_str
                        jmp ulstr_fromUtf8

@empty_str:             .byte 0

@fail_free_db:          ldx ULSFM_db
                        ldy ULSFM_db+1
                        jsr uldb_release
@fail_p1:
@fail:                  pla
                        sta BANKSEL::RAM
                        ; Restore caller's r0
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        sec
                        rts

                        ; --- Internal: copy replacement data from SCRATCH to output ---
                        ; ULSFM_copylen = number of bytes to copy
                        ; SCRATCH ($0600) has the replacement data
                        ; Output pointer/bank in ULSFM_outptr/outbank
@copy_replacement:
                        lda ULSFM_copylen
                        beq @copy_done

                        ; Set output bank and pointer
                        lda ULSFM_outbank
                        sta BANKSEL::RAM
                        lda ULSFM_outptr
                        sta UL_varptr
                        lda ULSFM_outptr+1
                        sta UL_varptr+1

                        ldx #0                  ; source index into SCRATCH
                        ldy ULSFM_outoff        ; dest index into output

@copy_byte:             lda UL_SCRATCH_BASE,x
                        sta (UL_varptr),y
                        inx
                        iny
                        cpx ULSFM_copylen
                        bne @copy_byte

                        sty ULSFM_outoff
@copy_done:             rts

.endproc

UL_BSS

ULSFM_stb:              .res 2          ; stringtable BRP
ULSFM_fmtlen:           .res 1          ; format string byte length
ULSFM_outlen:           .res 1          ; computed output length
ULSFM_fmtpos:           .res 1          ; current format position
ULSFM_seqidx:           .res 1          ; sequential placeholder index (1-based)
ULSFM_db:               .res 2          ; data block handle
ULSFM_mb:               .res 2          ; msgblock handle
ULSFM_outptr:           .res 2          ; output base address
ULSFM_outbank:          .res 1          ; output bank
ULSFM_outoff:           .res 1          ; output write offset
ULSFM_parseval:         .res 1          ; parsed index value
ULSFM_temp:             .res 1          ; temp for multiply
ULSFM_copylen:          .res 1          ; bytes to copy
ULSFM_repstr:           .res 2          ; replacement string handle
