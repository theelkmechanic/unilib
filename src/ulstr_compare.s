.include "unilib_impl.inc"

UL_CODE

; ulstr_compare - Compare two strings
;   In: r0 = first string handle (MSGBLOCK pool index), r1 = second string handle, A = flags (ignored)
;  Out: A = negative if first < second, 0 if equal, positive if first > second
.proc ulstr_compare
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string 1 via ULS_access → data at UL_SCRATCH_BASE
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Get bytelen1
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulstr_getrawlen
                        sta ULSC_s1_bytelen

                        ; Copy UL_SCRATCH_BASE data to UL_SCRATCH2_BASE
                        lda ULSC_s1_bytelen
                        beq @do_s2
                        tay
:                       dey
                        lda UL_SCRATCH_BASE,y
                        sta UL_SCRATCH2_BASE,y
                        cpy #0
                        bne :-

                        ; Access string 2 via ULS_access → data at UL_SCRATCH_BASE
@do_s2:                 ldx gREG::r1L
                        ldy gREG::r1H
                        jsr ULS_access

                        ; Get bytelen2
                        ldx gREG::r1L
                        ldy gREG::r1H
                        jsr ulstr_getrawlen
                        sta ULSC_s2_bytelen

                        ; Compare min(bytelen1, bytelen2) data bytes
                        ; String 1 data is at UL_SCRATCH2_BASE, string 2 at UL_SCRATCH_BASE
@compare:               lda ULSC_s1_bytelen
                        cmp ULSC_s2_bytelen
                        bcc @use_s1_len
                        lda ULSC_s2_bytelen
@use_s1_len:            tax                     ; X = min len
                        beq @compare_lengths    ; both empty or one empty

                        ldy #0
@cmp_loop:              lda UL_SCRATCH2_BASE,y
                        cmp UL_SCRATCH_BASE,y
                        bcc @less
                        bne @greater
                        iny
                        dex
                        bne @cmp_loop

                        ; All compared bytes equal, compare lengths
@compare_lengths:       lda ULSC_s1_bytelen
                        cmp ULSC_s2_bytelen
                        beq @equal
                        bcc @less

@greater:               pla
                        sta BANKSEL::RAM
                        lda #1
                        rts

@less:                  pla
                        sta BANKSEL::RAM
                        lda #$FF
                        rts

@equal:                 pla
                        sta BANKSEL::RAM
                        lda #0
                        rts

.endproc

UL_BSS

ULSC_s1_bytelen:        .res 1
ULSC_s2_bytelen:        .res 1
