.include "unilib_impl.inc"

.code

; ulstr_append - Concatenate two strings
;   In: r0 = first string BRP, r1 = second string BRP
;  Out: YX = new string BRP, carry set on error
.proc ulstr_append
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Copy string 1 to $500
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        lda (ULS_scratch_fptr)  ; bytelen1
                        sta @s1_bytelen
                        clc
                        adc #4
                        tay
:                       dey
                        lda (ULS_scratch_fptr),y
                        sta $500,y
                        cpy #0
                        bne :-

                        ; Copy string 2 to $600
                        ldx gREG::r1L
                        ldy gREG::r1H
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1
                        lda (ULS_scratch_fptr)  ; bytelen2
                        sta @s2_bytelen
                        clc
                        adc #4
                        tay
:                       dey
                        lda (ULS_scratch_fptr),y
                        sta $600,y
                        cpy #0
                        bne :-

                        ; Total bytelen = s1 + s2
                        lda @s1_bytelen
                        clc
                        adc @s2_bytelen
                        bcc :+
                        jmp @too_long           ; overflow
:                       cmp #253
                        bcc :+
                        jmp @too_long
:                       sta @total_bytelen

                        ; Allocate: total + 4 (3 header + data + NUL)
                        tax
                        inx
                        inx
                        inx
                        inx                     ; size = total + 4
                        ldy #0
                        jsr ulmem_alloc
                        bcs @alloc_fail

                        ; Save new BRP
                        phx
                        phy

                        ; Access new BRP
                        jsr ulmem_access
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        ; Write header: bytelen, charlen, printlen
                        lda @total_bytelen
                        sta (ULS_scratch_fptr)
                        ldy #1
                        ; charlen = s1_charlen + s2_charlen
                        lda $501                ; s1 charlen
                        clc
                        adc $601                ; s2 charlen
                        sta (ULS_scratch_fptr),y
                        iny
                        ; printlen = s1_printlen + s2_printlen
                        lda $502                ; s1 printlen
                        clc
                        adc $602                ; s2 printlen
                        sta (ULS_scratch_fptr),y

                        ; Copy string 1 data (from $503, s1_bytelen bytes)
                        ldy #0
                        ldx @s1_bytelen
                        beq @copy_s2
@copy_s1:               lda $503,y
                        pha
                        tya
                        clc
                        adc #3
                        tay
                        pla
                        sta (ULS_scratch_fptr),y
                        tya
                        sec
                        sbc #3
                        tay
                        iny
                        dex
                        bne @copy_s1

                        ; Copy string 2 data (from $603, s2_bytelen bytes)
@copy_s2:               ldx @s2_bytelen
                        beq @terminate
                        ; Y = s1_bytelen (offset into dest data area)
                        stz @src_idx
@copy_s2_loop:          lda @src_idx
                        pha
                        tay
                        lda $603,y              ; source byte
                        sta @temp_byte
                        pla
                        clc
                        adc @s1_bytelen
                        clc
                        adc #3                  ; dest offset = 3 + s1_bytelen + src_idx
                        tay
                        lda @temp_byte
                        sta (ULS_scratch_fptr),y
                        inc @src_idx
                        dex
                        bne @copy_s2_loop

                        ; NUL terminate
@terminate:             lda @total_bytelen
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
                        clc
                        rts

@too_long:              lda #ULERR::STRING_TOO_LONG
                        sta UL_lasterr
@alloc_fail:            pla
                        sta BANKSEL::RAM
                        sec
                        rts

.bss
@s1_bytelen:            .res 1
@s2_bytelen:            .res 1
@total_bytelen:         .res 1
@src_idx:               .res 1
@temp_byte:             .res 1
.endproc
