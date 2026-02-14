.include "unilib_impl.inc"

UL_CODE

; ulstr_toUtf8 - Copy UTF-8 bytes of a string into a byte iterator
;   In: r0 = string handle (MSGBLOCK pool index), YX = byte iterator handle
;  Out: carry set on error
.proc ulstr_toUtf8
                        ; Save iterator handle
                        stx ULST_iter
                        sty ULST_iter+1

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string → copies data to UL_SCRATCH_BASE
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Get rawlen
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulstr_getrawlen
                        sta ULST_rawlen

                        ; Loop rawlen times: store each byte via the byte iterator
                        lda ULST_rawlen
                        beq @done
                        sta ULST_count
                        stz ULST_src_idx

@loop:                  ; Load byte from scratch + src_idx
                        ldy ULST_src_idx
                        lda UL_SCRATCH_BASE,y

                        ; Store via ulitr_store (A = byte value, YX = iterator)
                        ldx ULST_iter
                        ldy ULST_iter+1
                        jsr ulitr_store
                        bcs @error

                        ; Advance iterator
                        ldx ULST_iter
                        ldy ULST_iter+1
                        jsr ulitr_inc

                        inc ULST_src_idx
                        dec ULST_count
                        bne @loop

@done:                  pla
                        sta BANKSEL::RAM
                        clc                     ; success
                        rts

@error:                 pla
                        sta BANKSEL::RAM
                        sec
                        rts

.endproc

UL_BSS

ULST_iter:              .res 2
ULST_rawlen:            .res 1
ULST_count:             .res 1
ULST_src_idx:           .res 1
