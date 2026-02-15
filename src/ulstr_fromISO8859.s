.include "unilib_impl.inc"

UL_CODE

; ulstr_fromISO8859 - Create a string from NUL-terminated ISO-8859-15 data
;   In: YX              - Pointer to NUL-terminated ISO-8859-15 character data
;  Out: YX              - String handle (MSGBLOCK pool index)
;       carry           - Set on error
.proc ulstr_fromISO8859
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save source pointer into zero-page for indirect access
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

@setup:                 stz ULSFI_outidx

                        ; Main conversion loop
@loop:                  lda (UL_varptr)
                        beq @done               ; NUL terminator

                        ; Check output overflow (need at most 3 bytes)
                        ldy ULSFI_outidx
                        cpy #250
                        bcs @done

                        ; Is it ASCII ($01-$7F)?
                        cmp #$80
                        bcs @high_byte

                        ; 1-byte UTF-8: store directly
                        sta UL_SCRATCH2_BASE,y
                        inc ULSFI_outidx
                        bra @next

@high_byte:             ; Check the 8 ISO-8859-15 exception bytes
                        cmp #$A4
                        beq @euro

                        ; Check other 7 exceptions (all produce $C5 + continuation)
                        ldx #6
@exc_loop:              cmp iso_exc_src,x
                        beq @exc_found
                        dex
                        bpl @exc_loop

                        ; Default: 2-byte UTF-8 from ISO-8859-1 formula
                        ; lead = $C0 | (byte >> 6), cont = $80 | (byte & $3F)
@default_2byte:         pha                     ; save for cont
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr
                        ora #$C0
                        ldy ULSFI_outidx
                        sta UL_SCRATCH2_BASE,y
                        iny
                        pla
                        and #$3F
                        ora #$80
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFI_outidx
                        bra @next

@exc_found:             ; Exception: $C5 + iso_exc_dst[x]
                        ldy ULSFI_outidx
                        lda #$C5
                        sta UL_SCRATCH2_BASE,y
                        iny
                        lda iso_exc_dst,x
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFI_outidx
                        bra @next

@euro:                  ; $A4 → U+20AC (€): 3 bytes $E2 $82 $AC
                        ldy ULSFI_outidx
                        lda #$E2
                        sta UL_SCRATCH2_BASE,y
                        iny
                        lda #$82
                        sta UL_SCRATCH2_BASE,y
                        iny
                        lda #$AC
                        sta UL_SCRATCH2_BASE,y
                        iny
                        sty ULSFI_outidx
                        bra @next

@next:                  ; Advance source pointer
                        inc UL_varptr
                        bne :+
                        inc UL_varptr+1
:                       jmp @loop

@done:                  ; NUL-terminate SCRATCH2
                        ldy ULSFI_outidx
                        lda #0
                        sta UL_SCRATCH2_BASE,y

                        ; Restore caller's bank and tail-call fromUtf8
                        pla
                        sta BANKSEL::RAM
                        ldx #<UL_SCRATCH2_BASE
                        ldy #>UL_SCRATCH2_BASE
                        jmp ulstr_fromUtf8

.endproc

UL_RODATA

; ISO-8859-15 exception source bytes (all map to $C5 + continuation)
iso_exc_src:            .byte $A6, $A8, $B4, $B8, $BC, $BD, $BE
; ISO-8859-15 exception UTF-8 continuation bytes
iso_exc_dst:            .byte $A0, $A1, $BD, $BE, $92, $93, $B8

UL_BSS

ULSFI_outidx:           .res 1
