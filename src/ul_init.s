.include "unilib_impl.inc"

.import __EXTZP_RUN__, __EXTZP_SIZE__

.code

; ul_init - Initialize UniLib
;   In: r0              Font filename
;       r1L             Font filename length
;       r1H             Drive # to load from
;       r2L             Initial screen foreground color
;       r2H             Initial screen background color
;  Out: A               Error code (0 = OK)
.proc ul_init
                        ; Initialize our zeropage
                        ldx #<(__EXTZP_SIZE__-1)
:                       stz __EXTZP_RUN__,x
                        dex
                        bpl :-
                        stx ULW_screen_handle
                        stx ULW_current_handle

                        ; Save whatever bank we were on and switch to bank 1
                        lda BANKSEL::RAM
                        pha
                        lda #1
                        sta BANKSEL::RAM

                        ; Initialize the heap
                        jsr ULM_init

                        ; Initialize math multiplication tables
                        ;   *** WARNING *** This MUST be the fist memory allocation call, or it will break badly; the multiplication
                        ; functions assume they're on the first page of bank RAM starting at $A100, and if this is not the first call,
                        ; they won't be
                        jsr ULM_multbl_init

                        ; Initialize the font cache
                        ;   *** WARNING *** This MUST be the second memory allocation call, or it will break badly; the font glyph info
                        ; lookup assumes it's on the first page of bank RAM starting at $A900, and if this is not the second call, it
                        ; won't be
                        jsr ULFT_initfontcache

                        ; Allocate the window map
                        ;   *** WARNING *** This MUST be the third memory allocation call, or it will break badly; the windowing code
                        ; assumes it's on the first page of bank RAM starting at $AE00, and if this is not the third call, it won't be
                        ldx #<(80*30)
                        ldy #>(80*30)
                        sec
                        jsr ulmem_alloc

                        ; Initialize VERA to display 80x30 Unicode text:
                        ;   - Map size = 128x32, tile size = 8x16
                        ;   - Layer 0 (base) text mode:
                        ;       - 1bpp, T256C=0
                        ;       - map is at $00000/$02000 (8k, double-buffered)
                        ;       - line stride is 256
                        ;       - tile set is at $10000 (4k)
                        ;   - Layer 1 (overlay) text mode
                        ;       - 2bpp (allows 1024 glyphs plus transforms)
                        ;       - map is at $04000/$06000 (8k, double-buffered)
                        ;       - line stride is 256
                        ;       - tile set is at $08000 (32k)

                        ; Load font to $08000 in VRAM (headerless, 4K layer 0 base glyphs, 32K layer 1 overlay glyphs, followed by glyph maps)
                        lda #1
                        ldx gREG::r1H
                        ldy #2
                        jsr SETLFS
                        lda gREG::r1L
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr SETNAM
                        lda #2
                        ldx #0
                        ldy #$80
                        jsr LOAD
                        bcc :+

                        ; Font load failed, so restore RAM bank, set and return error
                        lda #ULERR::LOAD_FAILED
                        sta UL_lasterr
                        jmp @init_done

                        ; Clear screen memory
:                       lda VERA::CTRL
                        and #$fe
                        sta VERA::CTRL
                        lda #VERA::INC1
                        sta VERA::ADDR+2
                        stz VERA::ADDR+1
                        stz VERA::ADDR
                        lda #' '
:                       sta VERA::DATA0
                        bit VERA::ADDR+1
                        bvc :-
:                       stz VERA::DATA0
                        bit VERA::ADDR+1
                        bpl :-

                        ; Configure the display compositor
                        lda VERA::CTRL
                        and #<(~(VERA::DISP::SELECT1))
                        sta VERA::CTRL
                        lda VERA::DISP::VIDEO
                        and #<(~VERA::DISP::ENABLE::SPRITES)
                        ora #(VERA::DISP::ENABLE::LAYER0 | VERA::DISP::ENABLE::LAYER1)
                        sta VERA::DISP::VIDEO
                        lda #$80
                        sta VERA::DISP::HSCALE
                        sta VERA::DISP::VSCALE
                        stz VERA::DISP::FRAME
                        lda VERA::CTRL
                        ora #VERA::DISP::SELECT1
                        sta VERA::CTRL
                        stz VERA::DISP::HSTART
                        stz VERA::DISP::VSTART
                        lda #160
                        sta VERA::DISP::HSTOP
                        lda #240
                        sta VERA::DISP::VSTOP

                        ; Configure layer 0
                        lda #VERA::MAP::WIDTH128 | VERA::MAP::HEIGHT32 | VERA::TILE1BPP
                        sta VERA::L0::CONFIG
                        stz VERA::L0::MAP_BASE
                        lda #VERA::TILE::WIDTH8 | VERA::TILE::HEIGHT16 | ($100 >> 1)
                        sta VERA::L0::TILE_BASE
                        stz VERA::L0::HSCROLL
                        stz VERA::L0::HSCROLL+1
                        stz VERA::L0::VSCROLL
                        stz VERA::L0::VSCROLL+1

                        ; Configure layer 1
                        lda #VERA::MAP::WIDTH128 | VERA::MAP::HEIGHT32 | VERA::TILE2BPP
                        sta VERA::L1::CONFIG
                        lda #($040 >> 1)
                        sta VERA::L1::MAP_BASE
                        lda #VERA::TILE::WIDTH8 | VERA::TILE::HEIGHT16 | ($080 >> 1)
                        sta VERA::L1::TILE_BASE
                        stz VERA::L1::HSCROLL
                        stz VERA::L1::HSCROLL+1
                        stz VERA::L1::VSCROLL
                        stz VERA::L1::VSCROLL+1

                        ; Setup palette colors
                        ldx #15
:                       txa
                        asl
                        tay
                        lda ULV_colors,y
                        pha
                        iny
                        lda ULV_colors,y
                        tay
                        txa
                        plx
                        jsr ULV_setpaletteentry
                        tax
                        dex
                        bne :-

                        ; Initialize double buffering
                        stz ULV_backbuf_offset
                        jsr ULV_swap

                        ; Lastly, initialize the windowing system; first we need our array of window BRPs,
                        ; so allocate an array to hold 64 BRPs (128 bytes); window handle will be 0-based
                        ; index into this list
                        ldx #64*2
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        stx ULW_winlist
                        sty ULW_winlist+1

                        ; Open a window for the screen (color params are already in the right register)
                        stz gREG::r0L
                        stz gREG::r0H
                        lda #80
                        sta gREG::r1L
                        lda #30
                        sta gREG::r1H
                        stz gREG::r3L
                        stz gREG::r3H
                        stz gREG::r4L
                        stz gREG::r4H
                        stz UL_lasterr
                        jsr ulwin_open

                        ; Restore the RAM bank and return success/failure
@init_done:             pla
                        sta BANKSEL::RAM
                        lda UL_lasterr
                        rts
.endproc

.rodata

ULV_colors:
                        .word   $000    ; (color 0 not used, set to black)
                        .word   $000    ; ULCOLOR::BLACK
                        .word   $444    ; ULCOLOR::DGREY
                        .word   $888    ; ULCOLOR::MGREY
                        .word   $ccc    ; ULCOLOR::LGREY
                        .word   $fff    ; ULCOLOR::WHITE
                        .word   $a10    ; ULCOLOR::RED
                        .word   $850    ; ULCOLOR::BROWN
                        .word   $1d7    ; ULCOLOR::GREEN
                        .word   $cfe    ; ULCOLOR::CYAN
                        .word   $03b    ; ULCOLOR::BLUE
                        .word   $d6d    ; ULCOLOR::MAGENTA
                        .word   $f99    ; ULCOLOR::LIGHTRED
                        .word   $ee9    ; ULCOLOR::YELLOW
                        .word   $bf8    ; ULCOLOR::LIGHTGREEN
                        .word   $1af    ; ULCOLOR::LIGHTBLUE

.data

ULW_keyfg:              .byte   ULCOLOR::WHITE      ; keyboard entry window foreground color
ULW_keybg:              .byte   ULCOLOR::BLUE       ; keyboard entry window background color
ULW_screen_size:        .byte   80, 30              ; Size of screen (lo=columns, hi=lines)

.bss

ULW_keyidle:            .res    2       ; keyboard idle routine address

ULW_screen_handle:      .res    1       ; Window handle of screen
ULW_current_handle:     .res    1       ; Window handle of current topmost window
