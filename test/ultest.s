.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

.global ULV_plotchar
.global ULV_copyrect

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
   inc gREG::r0L
   lda gREG::r0L
   cmp #80
   bne @incchar
   stz gREG::r0L
   inc gREG::r0H
   jsr ulwin_refresh
@incchar:
   inc gREG::r1L
   bne @charloop
   inc gREG::r1H
   lda gREG::r1H
   cmp #3
   bne :+
   lda #$1f
   sta gREG::r1H
   bra @charloop
:  cmp #$27
   bne :+
   lda #$df
   sta gREG::r1H
   bra @charloop
:  cmp #$e1
   bne @charloop
   jsr ulwin_refresh

   lda #16
   sta gREG::r0H
   lda #28
   sta gREG::r0L
   lda #ULCOLOR::WHITE
   sta gREG::r2L
   lda #ULCOLOR::BLUE
   sta gREG::r2H
   ldy #0
@line1loop:
   lda line1,y
   sta gREG::r1L
   iny
   lda line1,y
   sta gREG::r1H
   jsr ULV_plotchar
   bcc @line1done
   iny
   inc gREG::r0L
   bra @line1loop
@line1done:

   lda #16
   sta gREG::r0H
   lda #35
   sta gREG::r0L
   lda #ULCOLOR::BLACK
   sta gREG::r2L
   lda #ULCOLOR::WHITE
   sta gREG::r2H
   ldy #0
@titleloop:
   lda title,y
   sta gREG::r1L
   iny
   lda title,y
   sta gREG::r1H
   jsr ULV_plotchar
   bcc @titledone
   iny
   inc gREG::r0L
   bra @titleloop
@titledone:

   lda #17
   sta gREG::r0H
   lda #28
   sta gREG::r0L
   lda #ULCOLOR::WHITE
   sta gREG::r2L
   lda #ULCOLOR::BLUE
   sta gREG::r2H
   ldy #0
@line2loop:
   lda line2,y
   sta gREG::r1L
   iny
   lda line2,y
   sta gREG::r1H
   jsr ULV_plotchar
   bcc @line2done
   iny
   inc gREG::r0L
   bra @line2loop
@line2done:

   lda #18
   sta gREG::r0H
   lda #28
   sta gREG::r0L
   lda #ULCOLOR::WHITE
   sta gREG::r2L
   lda #ULCOLOR::BLUE
   sta gREG::r2H
   ldy #0
@line3loop:
   lda line3,y
   sta gREG::r1L
   iny
   lda line3,y
   sta gREG::r1H
   jsr ULV_plotchar
   bcc @line3done
   iny
   inc gREG::r0L
   bra @line3loop
@line3done:

   lda #19
   sta gREG::r0H
   lda #28
   sta gREG::r0L
   lda #ULCOLOR::WHITE
   sta gREG::r2L
   lda #ULCOLOR::BLUE
   sta gREG::r2H
   ldy #0
@line4loop:
   lda line4,y
   sta gREG::r1L
   iny
   lda line4,y
   sta gREG::r1H
   jsr ULV_plotchar
   bcc @line4done
   iny
   inc gREG::r0L
   bra @line4loop
@line4done:

   lda #20
   sta gREG::r0H
   lda #28
   sta gREG::r0L
   lda #ULCOLOR::WHITE
   sta gREG::r2L
   lda #ULCOLOR::BLUE
   sta gREG::r2H
   ldy #0
@line5loop:
   lda line5,y
   sta gREG::r1L
   iny
   lda line5,y
   sta gREG::r1H
   jsr ULV_plotchar
   bcc @line5done
   iny
   inc gREG::r0L
   bra @line5loop
@line5done:

   jsr ulwin_refresh

   ;source
   lda #16
   sta gREG::r0H
   lda #28
   sta gREG::r0L
   lda #5
   sta gREG::r2H
   lda #22
   sta gREG::r2L

   ;dest up/right overlap
   lda #19
   sta gREG::r1H
   lda #38
   sta gREG::r1L
   jsr ULV_copyrect
   jsr ulwin_refresh

@loop: bra @loop

   ;dest up/left
   lda #5
   sta gREG::r1H
   lda #2
   sta gREG::r1L
   jsr ULV_copyrect
   jsr ulwin_refresh

   ;dest down/left
   lda #24
   sta gREG::r1H
   jsr ULV_copyrect
   jsr ulwin_refresh

   ;dest up/right
   lda #5
   sta gREG::r1H
   lda #55
   sta gREG::r1L
   jsr ULV_copyrect
   jsr ulwin_refresh

   ; dest down/right
   lda #24
   sta gREG::r1H
   jsr ULV_copyrect
   jsr ulwin_refresh

.rodata

title: .word $0020, $0057, $0069, $006e, $0064, $006f, $0077, $0020, $0000
line1: .word $250f, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2513, $0000
line2: .word $2503, $0020, $0054, $0068, $0065, $0020, $0071, $0075, $0069, $0063, $006b, $0020, $0062, $0072, $006f, $0077, $006e, $0020, $0020, $0020, $0020, $2503, $0000
line3: .word $2503, $0020, $0066, $006f, $0078, $0020, $006a, $0075, $006d, $0070, $0073, $0020, $016f, $0076, $0065, $0072, $0020, $0074, $0068, $0065, $0020, $2503, $0000
line4: .word $2503, $0020, $006c, $0061, $007a, $0079, $0020, $0064, $016f, $0067, $002e, $0020, $0020, $0020, $0020, $0020, $0020, $0020, $0020, $0020, $0020, $2503, $0000
line5: .word $2517, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $2501, $251b, $0000

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
;
;.data
;
;val_smallentries: .res  1
