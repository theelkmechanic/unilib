.include "unilib_impl.inc"

UL_CODE

; ULI_utf8_charlen - Get byte-length of a UTF-8 character from its leading byte
;   In: A = leading byte
;  Out: A = 1-4 (1 for ASCII, invalid, or continuation bytes)
.proc ULI_utf8_charlen
                        cmp #$80
                        bcc @one                ; $00-$7F: ASCII
                        cmp #$C0
                        bcc @one                ; $80-$BF: continuation (treat as 1)
                        cmp #$E0
                        bcc @two                ; $C0-$DF: 2-byte
                        cmp #$F0
                        bcc @three              ; $E0-$EF: 3-byte
                        cmp #$F8
                        bcc @four               ; $F0-$F7: 4-byte
@one:                   lda #1
                        rts
@two:                   lda #2
                        rts
@three:                 lda #3
                        rts
@four:                  lda #4
                        rts
.endproc

; ULI_utf8_phys_forward - Step ULI_cur forward one UTF-8 character in physical memory
;   In: ULI_cur/ULI_cur_bank valid
;  Out: ULI_cur advanced past one UTF-8 character
.proc ULI_utf8_phys_forward
                        lda ULI_cur_bank
                        sta BANKSEL::RAM
                        lda (ULI_cur)
                        jsr ULI_utf8_charlen
                        jmp ULI_inc_cur
.endproc

; ULI_utf8_phys_backward - Step ULI_cur backward one UTF-8 character in physical memory
;   In: ULI_cur/ULI_cur_bank valid
;  Out: ULI_cur moved back to the leading byte of the previous character
.proc ULI_utf8_phys_backward
                        lda ULI_cur_bank
                        sta BANKSEL::RAM
                        ; Decrement by 1 and check if continuation byte; repeat up to 3 more times
                        lda #1
                        jsr ULI_dec_cur
                        lda (ULI_cur)
                        and #$C0
                        cmp #$80
                        bne @done               ; not continuation, we found the leader

                        lda #1
                        jsr ULI_dec_cur
                        lda (ULI_cur)
                        and #$C0
                        cmp #$80
                        bne @done

                        lda #1
                        jsr ULI_dec_cur
                        lda (ULI_cur)
                        and #$C0
                        cmp #$80
                        bne @done

                        ; Max 4-byte sequence: one more step back
                        lda #1
                        jmp ULI_dec_cur

@done:                  rts
.endproc

; ULI_utf8_step_forward - Direction-aware forward step for UTF-8
;   In: ULI_type_format cached (bit 7 = REVERSE)
;       ULI_cur/ULI_cur_bank valid
;  Out: ULI_cur updated
.proc ULI_utf8_step_forward
                        bit ULI_type_format
                        bmi ULI_utf8_phys_backward
                        bra ULI_utf8_phys_forward
.endproc

; ULI_utf8_step_backward - Direction-aware backward step for UTF-8
;   In: ULI_type_format cached (bit 7 = REVERSE)
;       ULI_cur/ULI_cur_bank valid
;  Out: ULI_cur updated
.proc ULI_utf8_step_backward
                        bit ULI_type_format
                        bmi ULI_utf8_phys_forward
                        bra ULI_utf8_phys_backward
.endproc

; ULI_utf8_fetch - Decode UTF-8 codepoint at ULI_cur into r0/r1L
;   In: ULI_cur/ULI_cur_bank valid
;  Out: r0L = low byte, r0H = mid byte, r1L = high byte of codepoint
;       A/ULI_scratch = r0L
.proc ULI_utf8_fetch
                        lda ULI_cur_bank
                        sta BANKSEL::RAM
                        ldy #0
                        stz gREG::r0H
                        stz gREG::r1L

                        ; Read leading byte
                        lda (ULI_cur),y
                        cmp #$80
                        bcs @multi

                        ; 1-byte ASCII: codepoint = byte value
                        sta gREG::r0L
                        sta ULI_scratch
                        rts

@multi:                 cmp #$E0
                        bcs @three_or_four

                        ; 2-byte: 110xxxxx 10xxxxxx
                        and #$1F
                        sta gREG::r0H           ; high 5 bits temporarily in r0H
                        iny
                        lda (ULI_cur),y
                        and #$3F                ; low 6 bits
                        sta gREG::r0L
                        ; Combine: codepoint = (r0H << 6) | r0L
                        ; Shift r0H left 6 = shift left 6 bits into r0H:r0L
                        lda gREG::r0H
                        lsr                     ; top 3 bits go into r0H
                        lsr
                        sta gREG::r0H
                        lda gREG::r0H           ; save shifted high
                        ; Original 5 bits: need bits 4-3-2 as top of r0H, bits 1-0 shifted to bits 7-6 of r0L
                        ; Redo: val = (lead & $1F)<<6 | (cont & $3F)
                        ; Let's just compute it properly
                        ldy #0
                        lda (ULI_cur),y         ; re-read lead
                        and #$1F
                        sta gREG::r0H
                        iny
                        lda (ULI_cur),y         ; continuation
                        and #$3F
                        ; Now combine: shift r0H left by 6, OR in low 6 bits
                        ; r0H has 5 bits (max $1F). Result max = $07FF
                        ; high byte = r0H >> 2, low byte = (r0H & 3) << 6 | cont
                        pha                     ; save continuation bits
                        lda gREG::r0H
                        lsr
                        lsr
                        sta gREG::r0H           ; high byte of codepoint
                        pla
                        pha
                        lda gREG::r0H
                        ; Need: low byte = (original_r0H & $03) << 6 | continuation
                        ldy #0
                        lda (ULI_cur),y
                        and #$1F
                        asl
                        asl
                        asl
                        asl
                        asl
                        asl                     ; (lead & $1F) << 6, but only bottom 2 bits survive in low byte
                        sta gREG::r0L
                        pla                     ; continuation bits
                        ora gREG::r0L
                        sta gREG::r0L
                        ; r0H already has the high bits from >> 2
                        lda gREG::r0L
                        sta ULI_scratch
                        rts

@three_or_four:         cmp #$F0
                        bcs @four

                        ; 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
                        ; codepoint = (b0 & $0F) << 12 | (b1 & $3F) << 6 | (b2 & $3F)
                        and #$0F
                        sta gREG::r0H           ; 4 bits of lead
                        iny
                        lda (ULI_cur),y
                        and #$3F
                        sta gREG::r0L           ; 6 bits of cont1
                        iny
                        lda (ULI_cur),y
                        and #$3F                ; 6 bits of cont2

                        ; Build codepoint: r0H has lead(4 bits), r0L has cont1(6 bits), A has cont2(6 bits)
                        ; Result high byte = (lead << 4) | (cont1 >> 2)
                        ; Result low byte = (cont1 & $03) << 6 | cont2
                        pha                     ; save cont2
                        lda gREG::r0H
                        asl
                        asl
                        asl
                        asl                     ; lead << 4
                        sta gREG::r0H
                        lda gREG::r0L           ; cont1
                        lsr
                        lsr                     ; cont1 >> 2
                        ora gREG::r0H
                        sta gREG::r0H           ; high byte done

                        lda gREG::r0L           ; cont1 again
                        and #$03
                        asl
                        asl
                        asl
                        asl
                        asl
                        asl                     ; (cont1 & 3) << 6
                        sta gREG::r0L
                        pla                     ; cont2
                        ora gREG::r0L
                        sta gREG::r0L           ; low byte done

                        lda gREG::r0L
                        sta ULI_scratch
                        rts

@four:                  ; 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
                        ; codepoint = (b0 & $07) << 18 | (b1 & $3F) << 12 | (b2 & $3F) << 6 | (b3 & $3F)
                        ; Direct computation:
                        ;   r1L = (lead << 2) | (cont1 >> 4)
                        ;   r0H = ((cont1 & $0F) << 4) | (cont2 >> 2)
                        ;   r0L = ((cont2 & $03) << 6) | cont3
                        and #$07
                        sta ULI_scratch+4       ; lead
                        iny
                        lda (ULI_cur),y
                        and #$3F
                        sta ULI_scratch+5       ; cont1
                        iny
                        lda (ULI_cur),y
                        and #$3F
                        sta ULI_scratch+6       ; cont2
                        iny
                        lda (ULI_cur),y
                        and #$3F
                        sta ULI_scratch+7       ; cont3

                        ; r1L = (lead << 2) | (cont1 >> 4)
                        lda ULI_scratch+4
                        asl
                        asl
                        sta gREG::r1L
                        lda ULI_scratch+5
                        lsr
                        lsr
                        lsr
                        lsr
                        ora gREG::r1L
                        sta gREG::r1L

                        ; r0H = ((cont1 & $0F) << 4) | (cont2 >> 2)
                        lda ULI_scratch+5
                        and #$0F
                        asl
                        asl
                        asl
                        asl
                        sta gREG::r0H
                        lda ULI_scratch+6
                        lsr
                        lsr
                        ora gREG::r0H
                        sta gREG::r0H

                        ; r0L = ((cont2 & $03) << 6) | cont3
                        lda ULI_scratch+6
                        and #$03
                        asl
                        asl
                        asl
                        asl
                        asl
                        asl
                        ora ULI_scratch+7
                        sta gREG::r0L

                        lda gREG::r0L
                        sta ULI_scratch
                        rts
.endproc

; ULI_utf8_store - Encode codepoint from r0/r1L to UTF-8 at ULI_cur
;   In: r0L = low byte, r0H = mid byte, r1L = high byte of codepoint
;       ULI_cur/ULI_cur_bank valid
;  Out: bytes written at (ULI_cur)
.proc ULI_utf8_store
                        lda ULI_cur_bank
                        sta BANKSEL::RAM

                        ; Check codepoint range
                        lda gREG::r1L
                        bne @four               ; > $FFFF -> 4 bytes
                        lda gREG::r0H
                        bne @check2or3
                        lda gREG::r0L
                        cmp #$80
                        bcs @two_byte
                        ; 1-byte ASCII
                        ldy #0
                        sta (ULI_cur),y
                        rts

@two_byte:              ; Should not happen for $00-$7F but handle $0080-$00FF as 2-byte
                        ; Actually r0H=0 and r0L >= $80 means codepoint $0080-$00FF
                        ; 2-byte: 110xxxxx 10xxxxxx
                        ; bits: 5 high + 6 low
                        ; lead = $C0 | (cp >> 6), cont = $80 | (cp & $3F)
                        lda gREG::r0L
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$C0
                        ldy #0
                        sta (ULI_cur),y
                        lda gREG::r0L
                        and #$3F
                        ora #$80
                        iny
                        sta (ULI_cur),y
                        rts

@check2or3:             ; r0H != 0, r1L == 0 -> codepoint $0100-$FFFF
                        lda gREG::r0H
                        cmp #$08
                        bcs @three              ; >= $0800 -> 3 bytes
                        ; $0100-$07FF -> 2 bytes
                        ; lead = $C0 | (cp >> 6)
                        ; cp >> 6: r0H:r0L >> 6 = (r0H << 2) | (r0L >> 6)
                        lda gREG::r0L
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr                     ; r0L >> 6 (2 bits)
                        sta ULI_scratch+7       ; temp
                        lda gREG::r0H
                        asl
                        asl                     ; r0H << 2
                        ora ULI_scratch+7
                        ora #$C0
                        ldy #0
                        sta (ULI_cur),y
                        lda gREG::r0L
                        and #$3F
                        ora #$80
                        iny
                        sta (ULI_cur),y
                        rts

@three:                 ; $0800-$FFFF -> 3 bytes: 1110xxxx 10xxxxxx 10xxxxxx
                        ; lead = $E0 | (cp >> 12)
                        ; cont1 = $80 | ((cp >> 6) & $3F)
                        ; cont2 = $80 | (cp & $3F)
                        ; cp >> 12 = r0H >> 4
                        lda gREG::r0H
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$E0
                        ldy #0
                        sta (ULI_cur),y

                        ; (cp >> 6) & $3F = ((r0H << 2) | (r0L >> 6)) & $3F
                        lda gREG::r0L
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        sta ULI_scratch+7
                        lda gREG::r0H
                        asl
                        asl
                        ora ULI_scratch+7
                        and #$3F
                        ora #$80
                        iny
                        sta (ULI_cur),y

                        lda gREG::r0L
                        and #$3F
                        ora #$80
                        iny
                        sta (ULI_cur),y
                        rts

@four:                  ; $10000+ -> 4 bytes: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
                        ; lead = $F0 | (cp >> 18)
                        ; cont1 = $80 | ((cp >> 12) & $3F)
                        ; cont2 = $80 | ((cp >> 6) & $3F)
                        ; cont3 = $80 | (cp & $3F)

                        ; cp >> 18 = r1L >> 2 (r1L has bits 20-16)
                        lda gREG::r1L
                        lsr
                        lsr
                        ora #$F0
                        ldy #0
                        sta (ULI_cur),y

                        ; (cp >> 12) & $3F = ((r1L << 4) | (r0H >> 4)) & $3F
                        lda gREG::r0H
                        lsr
                        lsr
                        lsr
                        lsr
                        sta ULI_scratch+7
                        lda gREG::r1L
                        asl
                        asl
                        asl
                        asl
                        ora ULI_scratch+7
                        and #$3F
                        ora #$80
                        iny
                        sta (ULI_cur),y

                        ; (cp >> 6) & $3F = ((r0H << 2) | (r0L >> 6)) & $3F
                        lda gREG::r0L
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        sta ULI_scratch+7
                        lda gREG::r0H
                        asl
                        asl
                        ora ULI_scratch+7
                        and #$3F
                        ora #$80
                        iny
                        sta (ULI_cur),y

                        lda gREG::r0L
                        and #$3F
                        ora #$80
                        iny
                        sta (ULI_cur),y
                        rts
.endproc
