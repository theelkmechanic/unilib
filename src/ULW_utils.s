; ULW_utils - Window utility functions

.include "unilib_impl.inc"

.code

; ULW_getwinptr - look up the window pointer for a given window handle
;   In: A               Window handle
;  Out: A               Window far pointer bank (WARNING: also leaves in BANKSEL:RAM)
;       YX              Window far pointer address
.proc ULW_getwinptr
                        ; Get a pointer to the window list entry
                        jsr ULW_getwinentryptr

                        ; Got the pointer, now follow the BRP in it
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
                        sta BANKSEL::RAM
                        lda (ULW_scratch_fptr)
                        tax
                        inc ULW_scratch_fptr
                        lda (ULW_scratch_fptr)
                        tay
                        jsr ulmem_access
                        lda BANKSEL::RAM
                        rts
.endproc

; ULW_getwinentryptr - look up the pointer to the window list entry for a given window handle
;   In: A               Window handle
;  Out: A               Window list entry far pointer bank (WARNING: also leaves in BANKSEL::RAM)
;       YX              Window list entry far pointer address
.proc ULW_getwinentryptr
                        ; Window pointer is zero-based index into the BRP array, max 64 windows
                        asl
                        bcs @bad_handle
                        bmi @bad_handle
                        sta ULM_temp_l
                        ldx ULW_winlist
                        ldy ULW_winlist+1
                        jsr ulmem_access
                        txa
                        clc
                        adc ULM_temp_l
                        tax
                        tya
                        adc #0
                        tay
                        lda BANKSEL::RAM
                        rts
@bad_handle:            lda #ULERR::INVALID_HANDLE
                        sta UL_lasterr
                        jmp UL_terminate
.endproc
