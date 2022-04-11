.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

.include "x16.inc"
.include "../src/unilib.inc"

   jmp start

unilib_fn: .byte "unilib.prg"
font_fn: .byte "unilib.ulf"
end_filenames:

start:
   ; Load the Unilib library (currently loads at $2000)
   lda #0
   sta ROM_BANK
   lda #1
   tay
   ldx #SD_DEVICE
   jsr SETLFS
   lda #(font_fn-unilib_fn)
   ldx #<unilib_fn
   ldy #>unilib_fn
   jsr SETNAM
   lda #0
   jsr LOAD

   ; Set font name in r0 and length in r1
   lda #(end_filenames-font_fn)
   sta r1L
   lda #SD_DEVICE
   sta r1H
   lda #<font_fn
   sta r0L
   lda #>font_fn
   sta r0H

   ; Initialize the Unilib library
   jsr ul_init

   ; Test memory alloc/free
memhammer:   ldx #0
:  lda $500,x
   bne :+
   phx
   jsr ENTROPY_GET
   tya
   and #$1f
   tay
   jsr mem_alloc
   jsr validate_heap
   txa
   plx
   sta $400,x
   tya
   sta $500,x
:  inx
   bne :--
   nop
:  phx
   jsr ENTROPY_GET
   lda $500,x
   stz $500,x
   tay
   lda $400,x
   stz $400,x
   tax
   jsr mem_free
   jsr validate_heap
   plx
   inx
   bne :-

@loop: bra memhammer

.proc validate_heap
   pha
   phx
   phy
   lda $00
   pha

   stz $00
@next_bank:
   inc $00
   beq @done

   ldy #0
   ldx #8
:  lda $a000,x
   bne :+
   iny
:  inx
   bne :--

   cpy $a000
   beq @check_smalls

@bad_free:
   nop
   stp
   brk
   nop

@check_smalls:
   stz val_smallentries
   ldy #7
:  lda $a000,y
   beq :+
   tax
   tya
   clc
   adc val_smallentries
   sta val_smallentries
   lda $a000,x
   beq :+

@bad_small_1:
   nop
   stp
   brk
   nop

:  dey
   bne :--

   lda val_smallentries
   cmp $a000
   bcc @done
   beq @done

@bad_small_2:
   nop
   stp
   brk
   nop


@done:
   pla
   sta $00
   ply
   plx
   pla
   rts
.endproc

.data

val_smallentries: .res  1

;   ; Draw some test characters
;   lda #ULCOLOR::WHITE
;   sta gREG::r2L
;   lda #ULCOLOR::BLACK
;   sta gREG::r2H
;
;   stz gREG::r0L
;   stz gREG::r0H
;   stz gREG::r1L
;   stz gREG::r1H
;@charloop:
;   jsr ULV_plotchar
;   bcc @incchar
;   inc gREG::r1L
;   lda gREG::r1L
;   cmp #80
;   bne @incchar
;   stz gREG::r1L
;   inc gREG::r1H
;@incchar:
;   inc gREG::r0L
;   bne @charloop
;   inc gREG::r0H
;   lda gREG::r0H
;   cmp #$ff
;   bne @charloop
