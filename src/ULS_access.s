.include "unilib_impl.inc"

.code

; ULS_access - Access the data in a string (MSGBLOCK pool index)
;   In: YX              - String handle (MSGBLOCK pool index)
;  Out: YX/ULS_scratch_fptr - Address of NUL-terminated UTF-8 string data at $400
;       Data is always copied to $400 scratch buffer with NUL terminator appended
.proc ULS_access
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Access the MB to read data_block, start, end
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Read start offset
                        ldy #ULMSG_BLOCK::start
                        lda (UL_varptr),y
                        sta @mb_start
                        iny
                        lda (UL_varptr),y
                        sta @mb_start+1

                        ; Read end offset
                        ldy #ULMSG_BLOCK::end
                        lda (UL_varptr),y
                        sta @mb_end
                        iny
                        lda (UL_varptr),y
                        sta @mb_end+1

                        ; Compute bytelen = end - start (low byte only, max 252)
                        lda @mb_end
                        sec
                        sbc @mb_start
                        sta @bytelen

                        ; Read data_block handle
                        ldy #ULMSG_BLOCK::data_block
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay

                        ; Get the BRP of the data block
                        jsr uldb_getbrp         ; YX = data BRP

                        ; Access the data BRP to get base address
                        jsr ulmem_access        ; YX = base address, bank set
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        ; Copy bytelen bytes from base+start to $400
                        ; Add start offset to base
                        lda ULS_scratch_fptr
                        clc
                        adc @mb_start
                        sta ULS_scratch_fptr
                        lda ULS_scratch_fptr+1
                        adc @mb_start+1
                        sta ULS_scratch_fptr+1

                        ; Copy bytelen bytes to $400
                        lda @bytelen
                        beq @nul_terminate
                        tay
:                       dey
                        lda (ULS_scratch_fptr),y
                        sta $400,y
                        cpy #0
                        bne :-

                        ; NUL-terminate at $400 + bytelen
@nul_terminate:         ldy @bytelen
                        lda #0
                        sta $400,y

                        ; Restore caller's bank
                        pla
                        sta BANKSEL::RAM
                        sta ULS_scratch_fptr+2

                        ; Set ULS_scratch_fptr and YX to $400
                        lda #$00
                        sta ULS_scratch_fptr
                        lda #$04
                        sta ULS_scratch_fptr+1
                        ldx #$00
                        ldy #$04
                        rts

.bss
@mb_start:              .res 2
@mb_end:                .res 2
@bytelen:               .res 1
.endproc
