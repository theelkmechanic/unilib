.include "unilib_impl.inc"

.code

; ulstr_mid - Extract substring
;   In: r0 = string BRP, r1 = start index (char), r2 = length (chars)
;  Out: YX = new substring BRP, carry set on success
.proc ulstr_mid
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Copy string to $500 via ULS_access
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        lda (ULS_scratch_fptr)  ; bytelen
                        clc
                        adc #4
                        tay
:                       dey
                        lda (ULS_scratch_fptr),y
                        sta $500,y
                        cpy #0
                        bne :-

                        ; Setup scanning pointer to data at $503
                        lda #$03
                        sta ULS_scratch_fptr
                        lda #$05
                        sta ULS_scratch_fptr+1
                        ; Set bank to current (data is in low RAM)
                        lda BANKSEL::RAM
                        sta ULS_scratch_fptr+2

                        ; Skip r1 characters to find start byte offset
                        lda gREG::r1L
                        beq @record_start
                        sta @skip_count
@skip_loop:             jsr ULS_nextchar
                        bcc :+
                        jmp @error              ; hit end while skipping
:
                        dec @skip_count
                        bne @skip_loop

@record_start:          ; ULS_scratch_fptr now points to start of substring
                        lda ULS_scratch_fptr
                        sta @start_ptr
                        lda ULS_scratch_fptr+1
                        sta @start_ptr+1

                        ; Scan r2 characters, count printable
                        stz @sub_printlen
                        stz @sub_charlen
                        lda gREG::r2L
                        beq @calc_bytelen
                        sta @scan_count
@scan_loop:             jsr ULS_nextchar
                        bcs @calc_bytelen       ; hit end early
                        inc @sub_charlen
                        ; Check if printable (A=high, Y=mid, X=low of codepoint)
                        jsr ul_isprint
                        bcc :+
                        inc @sub_printlen
:                       dec @scan_count
                        bne @scan_loop

@calc_bytelen:          ; sub_bytelen = current_ptr - start_ptr
                        lda ULS_scratch_fptr
                        sec
                        sbc @start_ptr
                        sta @sub_bytelen

                        ; Allocate sub_bytelen + 4
                        tax
                        beq @empty_string
                        inx
                        inx
                        inx
                        inx
                        ldy #0
                        jsr ulmem_alloc
                        bcc @error

                        ; Save new BRP
                        phx
                        phy
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        ; Write header
                        lda @sub_bytelen
                        sta (ULS_scratch_fptr)
                        ldy #1
                        lda @sub_charlen
                        sta (ULS_scratch_fptr),y
                        iny
                        lda @sub_printlen
                        sta (ULS_scratch_fptr),y

                        ; Copy data bytes
                        ldy #0
                        ldx @sub_bytelen
@copy_loop:             lda @start_ptr
                        sta UL_temp_l
                        lda @start_ptr+1
                        sta UL_temp_h
                        ; Read from start_ptr + y
                        tya
                        pha
                        clc
                        adc UL_temp_l
                        sta UL_temp_l
                        bcc :+
                        inc UL_temp_h
:                       lda (UL_temp_l)
                        sta @temp_byte
                        pla
                        tay
                        ; Write to dest at offset y+3
                        pha
                        tya
                        clc
                        adc #3
                        tay
                        lda @temp_byte
                        sta (ULS_scratch_fptr),y
                        pla
                        tay
                        iny
                        dex
                        bne @copy_loop

                        ; NUL terminate
                        tya
                        clc
                        adc #3
                        tay
                        lda #0
                        sta (ULS_scratch_fptr),y

                        ; Return new BRP
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

@empty_string:          ; Allocate minimal string (4 bytes: 3 header + NUL)
                        ldx #4
                        ldy #0
                        sec                     ; clear memory
                        jsr ulmem_alloc
                        bcc @error
                        ; Header is all zeros (0 bytelen, 0 charlen, 0 printlen, NUL)
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

@error:                 pla
                        sta BANKSEL::RAM
                        clc
                        rts

.bss
@start_ptr:             .res 2
@sub_bytelen:           .res 1
@sub_charlen:           .res 1
@sub_printlen:          .res 1
@temp_byte:             .res 1
@skip_count:            .res 1
@scan_count:            .res 1
.endproc
