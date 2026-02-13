.include "unilib_impl.inc"

.code

; ulstr_mid - Extract substring (zero-copy via new MB sharing data block)
;   In: r0 = string handle (MSGBLOCK pool index), r1 = start index (char), r2 = length (chars)
;  Out: YX = new substring handle (MSGBLOCK pool index), carry set on error
.proc ulstr_mid
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access source MB to read data_block, start, end
                        ldx gREG::r0L
                        ldy gREG::r0H
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Read source start offset
                        ldy #ULMSG_BLOCK::start
                        lda (UL_varptr),y
                        sta @src_start

                        ; Read source data_block handle
                        ldy #ULMSG_BLOCK::data_block
                        lda (UL_varptr),y
                        sta @db_handle
                        iny
                        lda (UL_varptr),y
                        sta @db_handle+1

                        ; Access data block BRP to get base address for scanning
                        ldx @db_handle
                        ldy @db_handle+1
                        jsr uldb_getbrp
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        ; Set ULS_scratch_fptr to base + src_start
                        lda ULS_scratch_fptr
                        clc
                        adc @src_start
                        sta ULS_scratch_fptr
                        bcc :+
                        inc ULS_scratch_fptr+1
:
                        ; Save the bank for ULS_nextchar
                        lda BANKSEL::RAM
                        sta ULS_scratch_fptr+2

                        ; Save base+start for offset computation
                        lda ULS_scratch_fptr
                        sta @base_ptr
                        lda ULS_scratch_fptr+1
                        sta @base_ptr+1

                        ; Skip r1 characters to find new_start
                        lda gREG::r1L
                        beq @record_start
                        sta @skip_count
@skip_loop:             jsr ULS_nextchar
                        bcc :+
                        jmp @error              ; hit end while skipping
:
                        dec @skip_count
                        bne @skip_loop

@record_start:          ; new_start = src_start + (ULS_scratch_fptr - base_ptr)
                        lda ULS_scratch_fptr
                        sec
                        sbc @base_ptr
                        clc
                        adc @src_start
                        sta @new_start

                        ; Scan r2 characters
                        lda gREG::r2L
                        beq @calc_end
                        sta @scan_count
@scan_loop:             jsr ULS_nextchar
                        bcs @calc_end           ; hit end early
                        dec @scan_count
                        bne @scan_loop

@calc_end:              ; new_end = src_start + (ULS_scratch_fptr - base_ptr)
                        lda ULS_scratch_fptr
                        sec
                        sbc @base_ptr
                        clc
                        adc @src_start
                        sta @new_end

                        ; Allocate new MSGBLOCK
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_alloc
                        bcs @error

                        ; Save new MB handle
                        stx @mb_handle
                        sty @mb_handle+1

                        ; Access MB to write fields
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; refcount = 1 (set by pool_alloc)
                        ; data_block = same as source
                        ldy #ULMSG_BLOCK::data_block
                        lda @db_handle
                        sta (UL_varptr),y
                        iny
                        lda @db_handle+1
                        sta (UL_varptr),y

                        ; start = new_start
                        ldy #ULMSG_BLOCK::start
                        lda @new_start
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; end = new_end
                        ldy #ULMSG_BLOCK::end
                        lda @new_end
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; cont/next/prev = $0000
                        ldy #ULMSG_BLOCK::cont
                        lda #0
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

                        ; Addref the shared data block
                        ldx @db_handle
                        ldy @db_handle+1
                        jsr uldb_addref

                        ; Return new MB handle in YX
                        ldx @mb_handle
                        ldy @mb_handle+1
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

@error:                 pla
                        sta BANKSEL::RAM
                        sec
                        rts

.bss
@db_handle:             .res 2
@src_start:             .res 1
@base_ptr:              .res 2
@new_start:             .res 1
@new_end:               .res 1
@skip_count:            .res 1
@scan_count:            .res 1
@mb_handle:             .res 2
.endproc
