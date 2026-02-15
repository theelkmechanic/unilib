.include "unilib_impl.inc"

UL_CODE

; ulstr_fromPETSCII - Create a string from NUL-terminated PETSCII data
;   In: A               - Flags: bit 0 clear (0) = shifted mode, bit 0 set (1) = unshifted mode
;       YX              - Pointer to NUL-terminated PETSCII character data
;  Out: YX              - String handle (MSGBLOCK pool index)
;       carry           - Set on error
.proc ulstr_fromPETSCII
                        ; Save flags
                        sta ULSFP_flags

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save source pointer
                        stx UL_varptr
                        sty UL_varptr+1

                        ; If source is in banked RAM ($A0-$BF), copy to SCRATCH ($0600)
                        cpy #$A0
                        bcc @setup
                        cpy #$C0
                        bcs @setup

                        ldy #0
@copy:                  lda (UL_varptr),y
                        sta UL_SCRATCH_BASE,y
                        beq @copy_done
                        iny
                        bne @copy
@copy_done:             lda #<UL_SCRATCH_BASE
                        sta UL_varptr
                        lda #>UL_SCRATCH_BASE
                        sta UL_varptr+1

@setup:                 stz ULSFP_outidx

                        ; Main conversion loop
@loop:                  lda (UL_varptr)
                        bne :+
                        jmp @done               ; NUL terminator
:
                        ; Check output overflow (need at most 3 bytes per char)
                        ldy ULSFP_outidx
                        cpy #250
                        bcc :+
                        jmp @done
:

                        ; Save source byte in X for table lookup
                        tax

                        ; Check shifted mode overrides
                        lda ULSFP_flags
                        and #$01
                        bne @table_lookup       ; unshifted -> always use table

                        ; Shifted mode: check for letter override ranges
                        txa                     ; A = source byte

                        ; $41-$5A -> lowercase a-z (byte + $20)
                        cmp #$41
                        bcc @table_lookup
                        cmp #$5B
                        bcc @shifted_lower

                        ; $61-$7A -> uppercase A-Z (byte - $20)
                        cmp #$61
                        bcc @table_lookup
                        cmp #$7B
                        bcc @shifted_upper1

                        ; $C1-$DA -> uppercase A-Z (byte - $80)
                        cmp #$C1
                        bcc @table_lookup
                        cmp #$DB
                        bcc @shifted_upper2
                        bra @table_lookup

@shifted_lower:         ; $41-$5A -> a-z: codepoint = byte + $20 (1-byte UTF-8)
                        clc
                        adc #$20
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFP_outidx
                        jmp @next

@shifted_upper1:        ; $61-$7A -> A-Z: codepoint = byte - $20 (1-byte UTF-8)
                        sec
                        sbc #$20
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFP_outidx
                        jmp @next

@shifted_upper2:        ; $C1-$DA -> A-Z: codepoint = byte - $80 (1-byte UTF-8)
                        sec
                        sbc #$80
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFP_outidx
                        jmp @next

@table_lookup:          ; Look up Unicode codepoint from shared helper (X = source byte)
                        jsr UL_petscii_to_codepoint
                        bcc :+
                        jmp @next               ; skip character ($0000)
:

                        ; X = cp_lo, Y = cp_hi
                        stx ULSFP_cp_lo
                        sty ULSFP_cp_hi

                        ; Encode codepoint as UTF-8
                        lda ULSFP_cp_hi
                        bne @multi_byte

                        ; hi = 0: codepoint $0001-$00FF
                        lda ULSFP_cp_lo
                        bmi @two_byte_00xx

                        ; 1-byte UTF-8 ($01-$7F)
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFP_outidx
                        jmp @next

@two_byte_00xx:         ; Codepoint $0080-$00FF -> 2-byte UTF-8
                        ; lead = $C0 | (lo >> 6), cont = $80 | (lo & $3F)
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$C0
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        pla
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFP_outidx
                        jmp @next

@multi_byte:            ; hi byte nonzero
                        cmp #$08
                        bcs @three_byte

                        ; 2-byte UTF-8 ($0100-$07FF)
                        ; lead = $C0 | (cp >> 6)
                        ; cp >> 6 = (hi << 2) | (lo >> 6)
                        asl
                        asl
                        sta ULSFP_temp
                        lda ULSFP_cp_lo
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULSFP_temp
                        ora #$C0
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        ; cont = $80 | (lo & $3F)
                        pla
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFP_outidx
                        jmp @next

@three_byte:            ; 3-byte UTF-8 ($0800-$FFFF)
                        ; lead = $E0 | (hi >> 4)
                        lda ULSFP_cp_hi
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$E0
                        ldy ULSFP_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny

                        ; cont1 = $80 | ((hi & $0F) << 2) | (lo >> 6)
                        lda ULSFP_cp_hi
                        and #$0F
                        asl
                        asl
                        sta ULSFP_temp
                        lda ULSFP_cp_lo
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora ULSFP_temp
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny

                        ; cont2 = $80 | (lo & $3F)
                        lda ULSFP_cp_lo
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFP_outidx
                        jmp @next

@next:                  ; Advance source pointer
                        inc UL_varptr
                        bne :+
                        inc UL_varptr+1
:                       jmp @loop

@done:                  ; NUL-terminate SCRATCH2
                        ldy ULSFP_outidx
                        lda #0
                        sta UL_SCRATCH2_BASE,y

                        ; Restore caller's bank and tail-call fromUtf8
                        pla
                        sta BANKSEL::RAM
                        ldx #<UL_SCRATCH2_BASE
                        ldy #>UL_SCRATCH2_BASE
                        jmp ulstr_fromUtf8

.endproc

UL_BSS

ULSFP_flags:            .res 1
ULSFP_outidx:           .res 1
ULSFP_cp_lo:            .res 1
ULSFP_cp_hi:            .res 1
ULSFP_temp:             .res 1
