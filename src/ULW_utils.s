; ULW_utils - Window utility functions

.include "unilib_impl.inc"

.code

; ULW_getwinstruct - access window structure and copy to known location
;   In: A               - Window handle
;  Out: ULW_scratch_ptr - Pointer to actual window structure
;       BANKSEL::RAM    - Bank of actual window structure
;       ULW_WINDOW_COPY - Copy of window structure contents
.proc ULW_getwinstruct
                        jsr ULW_getwinptr
                        stx ULW_scratch_fptr
                        sty ULW_scratch_fptr+1
.endproc

; *** FALL THROUGH INTENTIONAL, DO NOT ADD CODE HERE

; ULW_copywinstruct - copy window structure to known location 
;   In: ULW_scratch_ptr - Pointer to actual window structure
;       BANKSEL::RAM    - Bank of actual window structure
;  Out: ULW_WINDOW_COPY - Copy of window structure contents
.proc ULW_copywinstruct
                        ldy #.sizeof(ULW_WINDOW)-1
:                       lda (ULW_scratch_fptr),y
                        sta ULW_WINDOW_COPY::handle,y
                        dey
                        bpl :-
                        rts
.endproc

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
                        lda (ULW_scratch_fptr)
                        tax
                        inc ULW_scratch_fptr
                        lda (ULW_scratch_fptr)
                        tay
                        jsr ULM_access
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
                        sta UL_temp_l
                        ldx ULW_winlist
                        ldy ULW_winlist+1
                        jsr ULM_access
                        txa
                        clc
                        adc UL_temp_l
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
