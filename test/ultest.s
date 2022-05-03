.include "unilib.inc"
.include "cx16.inc"
.include "cbm_kernal.inc"

.global ULV_plotchar
.global ULV_copyrect
.global ULV_backbuf_offset
.global ULV_setdirtylines
.global ULVR_srcpos
.global ULVR_destpos
.global ULVR_size
.global ULVR_color

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

   ; Use white on dark grey by default
   lda #ULCOLOR::WHITE
   sta gREG::r2L
   lda #ULCOLOR::DGREY
   sta gREG::r2H

   ; Initialize the Unilib library
   jsr ul_init

   ; Draw our character set onto the bottom of the screen

   ; Make sure $20000 screen is displaying
   lda ULV_backbuf_offset
   beq :+
   jsr ulwin_refresh

   ; First do colors: white on black/dgrey for base set, then white on dgrey/mgrey/dgrey/mgrey for overlays
:  lda VERA::CTRL
   and #$fe
   sta VERA::CTRL
   lda #VERA::INC2
   sta VERA::ADDR+2
   lda #14
   sta VERA::ADDR+1
@next_line:
   lda #1
   sta VERA::ADDR
   bit VERA::ADDR+1
   beq :+
   lda #(ULCOLOR::BLUE << 4) | ULCOLOR::WHITE
   .byte $2c
:  lda #(ULCOLOR::DGREY << 4) | ULCOLOR::WHITE
:  eor #$80
@next_cell:
   sta VERA::DATA0
   ldx VERA::ADDR
   cpx #33
   bcc :-
   lda VERA::ADDR
   tay
   lsr
   eor VERA::ADDR+1
   pha
   tya
   lsr
   lsr
   lsr
   lsr
   lsr
   tay
   pla
   lsr
   tya
   rol
   and #$03
   beq :++
   dec
   beq :+++
   dec
   bne :+++
:  lda #(ULCOLOR::BLACK << 4) | ULCOLOR::YELLOW
   .byte $2c
:  lda #(ULCOLOR::BROWN << 4) | ULCOLOR::YELLOW
   .byte $2c
:  lda #(ULCOLOR::DGREY << 4) | ULCOLOR::YELLOW
   cpx #160
   bcc @next_cell
   ldx VERA::ADDR+1
   inx
   stx VERA::ADDR+1
   cpx #30
   bcc @next_line

   ; Next set overlay bits in $40000 screen so correct characters will be displayed
   lda #14 + 64
   sta VERA::ADDR+1
:  lda #33
   sta VERA::ADDR
   lda VERA::ADDR+1
   sec
   sbc #14 + 64
   lsr
   lsr
   ora #$d0
:  sta VERA::DATA0
   ldx VERA::ADDR
   cpx #160
   bcc :-
   ldx VERA::ADDR+1
   inx
   stx VERA::ADDR+1
   cpx #30 + 64
   bcc :--

   ; Now do characters; first, base in first 16 columns
   lda #14
   sta VERA::ADDR+1
:  stz VERA::ADDR
   lda VERA::ADDR+1
   sec
   sbc #14
   asl
   asl
   asl
   asl
:  sta VERA::DATA0
   inc
   ldx VERA::ADDR
   cpx #32
   bcc :-
   ldx VERA::ADDR+1
   inx
   stx VERA::ADDR+1
   cpx #30
   bcc :--

   ; Then overlay in last 64
   lda #14 + 64
   sta VERA::ADDR+1
:  lda #32
   sta VERA::ADDR
   lda VERA::ADDR+1
   sec
   sbc #14 + 64
   asl
   asl
   asl
   asl
   asl
   asl
:  sta VERA::DATA0
   inc
   ldx VERA::ADDR
   cpx #160
   bcc :-
   ldx VERA::ADDR+1
   inx
   stx VERA::ADDR+1
   cpx #30 + 64
   bcc :--

   ; Mark bottom rows as dirty so they persist
   ldx #14
   ldy #29
   jsr ULV_setdirtylines
   jsr ulwin_refresh

   ; Draw some test characters
   lda #(ULCOLOR::BLACK << 4) | ULCOLOR::WHITE
   sta ULVR_color

   stz ULVR_destpos
   stz ULVR_destpos+1
   ldx #0
   ldy #0
@charloop:
   lda #0
   jsr ULV_plotchar
   bcc @incchar
   inc ULVR_destpos
   lda ULVR_destpos
   cmp #80
   bne @incchar
   stz ULVR_destpos
   inc ULVR_destpos+1
   jsr ulwin_refresh
@incchar:
   inx
   bne @charloop
   iny
   cpy #3
   bne :+
   ldy #$1f
   bra @charloop
:  cpy #$27
   bne :+
   ldy #$df
   bra @charloop
:  cpy #$e1
   bne @charloop
   jsr ulwin_refresh


   ; Open a white-on-blue window at 5,5-15x70 with a border and title
   lda #5
   sta gREG::r0L
   sta gREG::r0H
   lda #70
   sta gREG::r1L
   lda #15
   sta gREG::r1H
   lda #ULCOLOR::WHITE
   sta gREG::r2L
   lda #ULCOLOR::BLUE
   sta gREG::r2H
   lda #<wintitle
   sta gREG::r3L
   lda #>wintitle
   sta gREG::r3H
   stz gREG::r4L
   lda #$80
   sta gREG::r4H
   jsr ulwin_open
   jsr ulwin_refresh

@loop: bra @loop

wintitle:   .word $0160, $014d, $006d, $0117
            .word $0020, $0168, $014b, $012f
            .word $0107, $0153, $010f, $0119
            .word $0020, $012a, $0020, $0136
            .word $0148, $0151, $0175, $0000

;   ; Test memory alloc/free
;memhammer:   ldx #0
;:  lda $500,x
;   bne :+
;   phx
;   jsr ENTROPY_GET
;   and #$1f
;   sta gREG::r0H
;   stx gREG::r0L
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
;   sta gREG::r0H
;   lda $400,x
;   stz $400,x
;   sta gREG::r0L
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
