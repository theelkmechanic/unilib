.include "unilib_impl.inc"

.segment "EXTZP" : zeropage

UL_src_fptr:            .res    3   ; source pointer for core functions
UL_src_rng:             .res    1   ; range check bits
UL_dst_fptr:            .res    3   ; destination pointer for core functions
UL_dst_rng:             .res    1   ; range check bits
UL_len:                 .res    2   ; length for core functions

.code

ULI_fetsto5d: ; Read/write value from (UL_src/dest_fptr) into FACC and decrement ptr
                        ldy #$ff
                        .byte $2c

ULI_fetsto5i: ; Read/write value from (UL_src/dest_fptr) into FACC and increment ptr
                        ldy #1
                        .byte $2c

ULI_fetsto5: ; Read/write value from (UL_src/dest_fptr) into FACC
                        ldy #0
                        ldx #5
                        phx
                        ldx #FAC
                        bra ULI_fetstoplx

ULI_fetsto4d: ; Read/write value from (UL_src/dest_fptr) into r0/r1 and decrement ptr
                        ldy #$ff
                        .byte $2c

ULI_fetsto4i: ; Read/write value from (UL_src/dest_fptr) into r0/r1 and increment ptr
                        ldy #1
                        .byte $2c

ULI_fetsto4: ; Read/write value from (UL_src/dest_fptr) into r0/r1
                        ldy #0
                        ldx #4
                        phx
                        bra ULI_fetstor0

ULI_fetsto3d: ; Read/write value from (UL_src/dest_fptr) into r0/r1L and decrement ptr
                        ldy #$ff
                        .byte $2c

ULI_fetsto3i: ; Read/write value from (UL_src/dest_fptr) into r0/r1L and increment ptr
                        ldy #1
                        .byte $2c

ULI_fetsto3: ; Read/write value from (UL_src/dest_fptr) into r0/r1L
                        ldy #0
                        ldx #3
                        phx
                        bra ULI_fetstor0

ULI_fetsto2d: ; Read/write value from (UL_src/dest_fptr) into r0 and decrement ptr
                        ldy #$ff
                        .byte $2c

ULI_fetsto2i: ; Read/write value from (UL_src/dest_fptr) into r0 and increment ptr
                        ldy #1
                        .byte $2c

ULI_fetsto2: ; Read/write value from (UL_src/dest_fptr) into r0
                        ldy #0
                        ldx #2
                        phx
ULI_fetstor0:           ldx #gREG::r0
                        bra ULI_fetstoplx

ULI_fetsto1d: ; Read/write value from (UL_src/dest_fptr) into A and decrement ptr
                        ldy #$ff
                        .byte $2c

ULI_fetsto1i: ; Read/write value from (UL_src/dest_fptr) into A and increment ptr
                        ldy #1
                        .byte $2c

ULI_fetsto1: ; Read/write value from (UL_src/dest_fptr) into A
                        sta UL_temp_l
                        ldy #0
                        ldx #1
                        phx
                        ldx #UL_temp_l
ULI_fetstoplx:          stx UL_var2ptr
                        stz UL_var2ptr+1
                        plx

ULI_fetsto: ; Read (clc)/write (sec) value from (UL_src/dest_fptr)
                        pha
                        bcc :+
                        lda #UL_dst_fptr
                        .byte $2c
:                       lda #UL_src_fptr
                        sta UL_varptr
                        stz UL_varptr+1
                        pla

                        ; Save X (size) and Y (inc/dec) for later
                        phy
                        phx
                        ldy #0

                        ; If carry is clear, we're reading X bytes from UL_src_fptr into whatever UL_var2ptr points at;
                        ; otherwise we're writing to it
                        bcs ULI_writeloop
ULI_readloop:           lda (UL_src_fptr),y
                        sta (UL_var2ptr),y
                        iny
                        dex
                        bne ULI_readloop
                        bra ULI_xferdone

ULI_writeloop:          lda (UL_var2ptr),y
                        sta (UL_dst_fptr),y
                        iny
                        dex
                        bne ULI_writeloop

                        ; Transfer is done, so get X and Y back to see if we need to inc/dec and by how much
ULI_xferdone:           plx
                        ply
                        pha
                        tya
                        beq ULI_done

                        ; Need to check the range of the address; if it's in I/O, don't inc/dec
                        phy
                        ldy #3
                        lda (UL_varptr),y
                        ply
                        jsr UL_chkrng
                        bvs ULI_done

                        ; Check if inc/dec
                        tya
                        php
                        ldy #0
                        plp
                        bmi ULI_decvar

                        ; Increment pointer by X bytes and fixup pointer if needed
                        jsr UL_adc16
                        bra ULI_done

                        ; Decrement pointer by X bytes and fixup pointer if needed
ULI_decvar:             jsr UL_sbc16

ULI_done:               pla
                        rts
