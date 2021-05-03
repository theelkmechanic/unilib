; ul_init - Initialize UniLib

.include "unilib_impl.inc"

.code

.proc ULAPI_ul_init
    ; Initialize the VERA
    jsr ULV_init

    ; Draw some test characters
    lda #ULCOLOR::WHITE
    sta gREG::r2L
    lda #ULCOLOR::BLACK
    sta gREG::r2H

    stz gREG::r0L
    stz gREG::r0H
    stz gREG::r1L
    stz gREG::r1H
@charloop:
    jsr ULV_plotchar
    bcc @incchar
    inc gREG::r1L
    lda gREG::r1L
    cmp #80
    bne @incchar
    stz gREG::r1L
    inc gREG::r1H
@incchar:
    inc gREG::r0L
    bne @charloop
    inc gREG::r0H
    lda gREG::r0H
    cmp #$ff
    bne @charloop

@loop: bra @loop

    rts
.endproc
