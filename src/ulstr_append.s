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
                        sta @s1_bytelen

                        ; Copy $400 data to $500
                        lda @s1_bytelen
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
                        sta @s2_bytelen

                        ; Copy $400 data to $500 + s1_bytelen
                        lda @s2_bytelen
                        beq @check_total
                        tax
                        ldy #0
@copy_s2_loop:          lda $400,y
                        pha
                        tya
                        clc
                        adc @s1_bytelen
                        tay
                        pla
                        sta $500,y
                        tya
                        sec
                        sbc @s1_bytelen
                        tay
                        iny
                        dex
                        bne @copy_s2_loop

                        ; Check total <= 252
@check_total:           lda @s1_bytelen
                        clc
                        adc @s2_bytelen
                        bcc :+
                        jmp @too_long           ; overflow
:                       cmp #253
                        bcc :+
                        jmp @too_long
:                       sta @total_bytelen

                        ; Create data block with total size
                        ldx @total_bytelen
                        ldy #0
                        jsr uldb_create
                        bcc :+
                        jmp @alloc_fail
:
                        stx @db_handle
                        sty @db_handle+1

                        ; Access data block BRP and copy from $500
                        jsr uldb_getbrp
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        lda @total_bytelen
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
                        stx @mb_handle
                        sty @mb_handle+1

                        ; Access MB to write fields
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; data_block
                        ldy #ULMSG_BLOCK::data_block
                        lda @db_handle
                        sta (UL_varptr),y
                        iny
                        lda @db_handle+1
                        sta (UL_varptr),y

                        ; start = 0
                        ldy #ULMSG_BLOCK::start
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; end = total_bytelen
                        ldy #ULMSG_BLOCK::end
                        lda @total_bytelen
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
                        ldx @mb_handle
                        ldy @mb_handle+1
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

@fail_free_db:          ldx @db_handle
                        ldy @db_handle+1
                        jsr uldb_release
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

.bss
@s1_bytelen:            .res 1
@s2_bytelen:            .res 1
@total_bytelen:         .res 1
@db_handle:             .res 2
@mb_handle:             .res 2
.endproc
