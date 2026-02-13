.include "unilib_impl.inc"

.code

; ulstr_addref - Increment reference count on a string
;   In: YX = string handle (MSGBLOCK pool index)
.proc ulstr_addref
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save handle for data_block addref
                        stx ULS_str_scratch
                        sty ULS_str_scratch+1

                        ; Access MB
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Increment refcount (16-bit)
                        ldy #ULMSG_BLOCK::refcount
                        lda (UL_varptr),y
                        clc
                        adc #1
                        sta (UL_varptr),y
                        iny
                        lda (UL_varptr),y
                        adc #0
                        sta (UL_varptr),y

                        ; Restore bank
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

; ulstr_release - Decrement reference count on a string, free when zero
;   In: YX = string handle (MSGBLOCK pool index)
.proc ulstr_release
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save handle
                        stx ULS_str_scratch
                        sty ULS_str_scratch+1

                        ; Access MB
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Decrement refcount (16-bit)
                        ldy #ULMSG_BLOCK::refcount
                        lda (UL_varptr),y
                        sec
                        sbc #1
                        sta (UL_varptr),y
                        iny
                        lda (UL_varptr),y
                        sbc #0
                        sta (UL_varptr),y

                        ; Check if refcount is now zero
                        dey
                        ora (UL_varptr),y
                        bne @done

                        ; Refcount zero — read data_block handle
                        ldy #ULMSG_BLOCK::data_block
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay

                        ; Release data block
                        jsr uldb_release

                        ; Free the MB
                        lda #ULPOOL::MSGBLOCK
                        ldx ULS_str_scratch
                        ldy ULS_str_scratch+1
                        jsr ulpool_free

@done:                  pla
                        sta BANKSEL::RAM
                        rts
.endproc

.bss

ULS_str_scratch:        .res 4          ; temp storage for string operations
