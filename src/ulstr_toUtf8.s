.include "unilib_impl.inc"

.code

; ulstr_toUtf8 - Copy UTF-8 bytes of a string into a byte iterator
;   In: r0 = string BRP, YX = byte iterator handle
;  Out: carry set on error
.proc ulstr_toUtf8
                        ; Save iterator handle
                        stx @iter
                        sty @iter+1

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string - copy to $500 for safe access
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        lda (ULS_scratch_fptr)  ; bytelen
                        sta @rawlen
                        clc
                        adc #4
                        tay
:                       dey
                        lda (ULS_scratch_fptr),y
                        sta $500,y
                        cpy #0
                        bne :-

                        ; Loop rawlen times: store each byte via the byte iterator
                        lda @rawlen
                        beq @done
                        sta @count
                        stz @src_idx

@loop:                  ; Load byte from $503 + src_idx
                        ldy @src_idx
                        lda $503,y

                        ; Store via ulitr_store (A = byte value, YX = iterator)
                        ldx @iter
                        ldy @iter+1
                        jsr ulitr_store
                        bcs @error

                        ; Advance iterator
                        ldx @iter
                        ldy @iter+1
                        jsr ulitr_inc

                        inc @src_idx
                        dec @count
                        bne @loop

@done:                  pla
                        sta BANKSEL::RAM
                        clc                     ; success
                        rts

@error:                 pla
                        sta BANKSEL::RAM
                        sec
                        rts

.bss
@iter:                  .res 2
@rawlen:                .res 1
@count:                 .res 1
@src_idx:               .res 1
.endproc
