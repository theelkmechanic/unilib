; ULV_blt - Copy a block of data from one point in VRAM to another

.include "unilib_impl.inc"

.code

; ULV_blt - Copy a block of data from one point in VRAM to another
; In:   ULV_bltsrc      - Source VRAM address (including autoincrement/decrement)
;       ULV_bltdst      - Destination VRAM address (including autoincrement/decrement)
;       ULV_bltlen      - Bytes to copy
.proc ULV_blt
    ; Put destination address in ADDR1
    pha
    phx
    phy
    lda VERA::CTRL
    ora #1
    sta VERA::CTRL
    lda ULV_bltdst
    sta VERA::ADDR
    lda ULV_bltdst+1
    sta VERA::ADDR+1
    lda ULV_bltdst+2
    sta VERA::ADDR+2

    ; Put source address in ADDR0
    lda VERA::CTRL
    and #$fe
    sta VERA::CTRL
    lda ULV_bltsrc
    sta VERA::ADDR
    lda ULV_bltsrc+1
    sta VERA::ADDR+1
    lda ULV_bltsrc+2
    sta VERA::ADDR+2

    ; Blit the data
    ldx ULV_bltlen+1
    ldy ULV_bltlen
@blit_loop:
    lda VERA::DATA0
    sta VERA::DATA1
    cpy #0
    bne :+
    dex
:   dey
    bne @blit_loop
    cpx #0
    bne @blit_loop
    ply
    plx
    pla
    rts
.endproc

.bss

ULV_bltsrc: .res 3
ULV_bltdst: .res 3
ULV_bltlen: .res 2
