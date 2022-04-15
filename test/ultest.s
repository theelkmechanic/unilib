.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

.global ULV_plotchar

.segment "EXEHDR"

    ; Stub launcher
    .byte $0b, $08, $b0, $07, $9e, $32, $30, $36, $31, $00, $00, $00

.segment "LOWCODE"

   jmp start

.code

font_fn: .byte "unilib.ulf"
end_filenames:

start:
   ; Set font name in r0 and length/device in r1
   lda #(end_filenames-font_fn)
   sta gREG::r1L
   lda #8
   sta gREG::r1H
   lda #<font_fn
   sta gREG::r0L
   lda #>font_fn
   sta gREG::r0H

   ; Use white on blue by default
   lda #ULCOLOR::WHITE
   sta gREG::r2L
   lda #ULCOLOR::DGREY
   sta gREG::r2H

   ; Initialize the Unilib library
   jsr ul_init

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


;   ; Test memory alloc/free
;memhammer:   ldx #0
;:  lda $500,x
;   bne :+
;   phx
;   jsr ENTROPY_GET
;   tya
;   and #$1f
;   tay
;   clc
;   jsr ulmem_alloc
;   jsr validate_heap
;   txa
;   plx
;   sta $400,x
;   tya
;   sta $500,x
;:  inx
;   bne :--
;   nop
;:  phx
;   jsr ENTROPY_GET
;   lda $500,x
;   stz $500,x
;   tay
;   lda $400,x
;   stz $400,x
;   tax
;   jsr ulmem_free
;   jsr validate_heap
;   plx
;   inx
;   bne :-
;
;@loop: bra memhammer
;
;.proc validate_heap
;   pha
;   phx
;   phy
;   lda $00
;   pha
;
;   stz $00
;@next_bank:
;   inc $00
;   beq @done
;
;   ldy #0
;   ldx #8
;:  lda $a000,x
;   bne :+
;   iny
;:  inx
;   bne :--
;
;   cpy $a000
;   beq @check_smalls
;
;@bad_free:
;   nop
;   stp
;   brk
;   nop
;
;@check_smalls:
;   stz val_smallentries
;   ldy #7
;:  lda $a000,y
;   beq :+
;   tax
;   tya
;   clc
;   adc val_smallentries
;   sta val_smallentries
;   lda $a000,x
;   beq :+
;
;@bad_small_1:
;   nop
;   stp
;   brk
;   nop
;
;:  dey
;   bne :--
;
;   lda val_smallentries
;   cmp $a000
;   bcc @done
;   beq @done
;
;@bad_small_2:
;   nop
;   stp
;   brk
;   nop
;
;
;@done:
;   pla
;   sta $00
;   ply
;   plx
;   pla
;   rts
;.endproc

.data

val_smallentries: .res  1
