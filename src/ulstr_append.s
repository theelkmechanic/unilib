.include "unilib_impl.inc"

.code

; ulstr_append - Concatenate two strings
;   In: r0 = first string handle (MSGBLOCK pool index), r1 = second string handle
;  Out: YX = new string handle (MSGBLOCK pool index), carry set on error
.proc ulstr_append
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access string 1 via ULS_access → copies to $400
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULS_access

                        ; Get bytelen1 from MB
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulstr_getrawlen     ; A = bytelen1
                        sta ULSAP_s1_bytelen

                        ; Copy $400 data to $500
                        lda ULSAP_s1_bytelen
                        beq @copy_s2
                        tay
:                       dey
                        lda $400,y
                        sta $500,y
                        cpy #0
                        bne :-

                        ; Access string 2 via ULS_access → copies to $400
@copy_s2:               ldx gREG::r1L
                        ldy gREG::r1H
                        jsr ULS_access

                        ; Get bytelen2 from MB
                        ldx gREG::r1L
                        ldy gREG::r1H
                        jsr ulstr_getrawlen     ; A = bytelen2
                        sta ULSAP_s2_bytelen

                        ; Copy $400 data to $500 + s1_bytelen
                        lda ULSAP_s2_bytelen
                        beq @check_total
                        tax
                        ldy #0
@copy_s2_loop:          lda $400,y
                        pha
                        tya
                        clc
                        adc ULSAP_s1_bytelen
                        tay
                        pla
                        sta $500,y
                        tya
                        sec
                        sbc ULSAP_s1_bytelen
                        tay
                        iny
                        dex
                        bne @copy_s2_loop

                        ; Check total <= 252
@check_total:           lda ULSAP_s1_bytelen
                        clc
                        adc ULSAP_s2_bytelen
                        bcc :+
                        jmp @too_long           ; overflow
:                       cmp #253
                        bcc :+
                        jmp @too_long
:                       sta ULSAP_total_bytelen

                        ; Create data block with total size
                        ldx ULSAP_total_bytelen
                        ldy #0
                        jsr uldb_create
                        bcc :+
                        jmp @alloc_fail
:
                        stx ULSAP_db_handle
                        sty ULSAP_db_handle+1

                        ; Access data block BRP and copy from $500
                        jsr uldb_getbrp
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        lda ULSAP_total_bytelen
                        beq @alloc_mb
                        tay
:                       dey
                        lda $500,y
                        sta (ULS_scratch_fptr),y
                        cpy #0
                        bne :-

                        ; Allocate MSGBLOCK
@alloc_mb:              lda #ULPOOL::MSGBLOCK
                        jsr ulpool_alloc
                        bcs @fail_free_db

                        ; Save MB handle
                        stx ULSAP_mb_handle
                        sty ULSAP_mb_handle+1

                        ; Access MB to write fields
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; data_block
                        ldy #ULMSG_BLOCK::data_block
                        lda ULSAP_db_handle
                        sta (UL_varptr),y
                        iny
                        lda ULSAP_db_handle+1
                        sta (UL_varptr),y

                        ; start = 0
                        ldy #ULMSG_BLOCK::start
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; end = total_bytelen
                        ldy #ULMSG_BLOCK::end
                        lda ULSAP_total_bytelen
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; cont/next/prev = $0000
                        ldy #ULMSG_BLOCK::cont
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        ldy #ULMSG_BLOCK::next
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
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

                        ; Return MB handle
                        ; (data block already has refcount=1 from uldb_create)
                        ldx ULSAP_mb_handle
                        ldy ULSAP_mb_handle+1
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

@too_long:              lda #ULERR::STRING_TOO_LONG
                        sta UL_lasterr
@alloc_fail:            pla
                        sta BANKSEL::RAM
                        sec
                        rts

@fail_free_db:          ldx ULSAP_db_handle
                        ldy ULSAP_db_handle+1
                        jsr uldb_release
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

.endproc

.bss

ULSAP_s1_bytelen:       .res 1
ULSAP_s2_bytelen:       .res 1
ULSAP_total_bytelen:    .res 1
ULSAP_db_handle:        .res 2
ULSAP_mb_handle:        .res 2
