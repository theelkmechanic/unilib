.include "unilib_impl.inc"

.code

; ul_init - Initialize UniLib
;   In: r0          Font filename
;       r1L         Font filename length
;       r1H         Drive # to load from
;  Out: A           Error code (0 = OK)
.proc ul_init
                ; Initialize the banked RAM so it's ready for memory allocations; see how many RAM banks we have to work with
                sec
                jsr MEMTOP
                sta ULM_numbanks

                ; Save whatever bank we were on and switch to bank 1
                lda BANKSEL::RAM
                pha
                lda #1
                sta BANKSEL::RAM

                ; First page of each bank is slot tracking. First byte is # of free slots, then the next 7 are
                ; the index of the first free entry that is exactly 1 slot, 2 slots, etc., or 0 if there is no
                ; exact match. Since there isn't to begin with, the whole first page gets set to 0, and the first
                ; byte is set to 248 (since the slots for the first page are in use for the bitmap).
@init_bank:     lda #0
                tax
:               inx
                sta BANK::RAM,x
                bne :-
                lda #248
                sta BANK::RAM
                inc BANKSEL::RAM
                lda BANKSEL::RAM
                cmp ULM_numbanks
                bne @init_bank

                ; Initialize VERA to display 80x30 Unicode text:
                ;   - Map size = 128x32, tile size = 8x16
                ;   - Layer 0 (base) text mode:
                ;       - 1bpp, T256C=0
                ;       - map is at $00000/$10000 (8k, double-buffered)
                ;       - line stride is 256
                ;       - tile set is at $04000 (4k)
                ;   - Layer 1 (overlay) text mode
                ;       - 2bpp (allows 1024 glyphs plus transforms)
                ;       - map is at $02000/$12000 (8k, double-buffered)
                ;       - line stride is 256
                ;       - tile set is at $05000 (32k)

                ; Load font to $04000 in VRAM (4K layer 0 base glyphs, 32K layer 1 overlay glyphs, followed by glyph maps)
                lda #1
                ldx gREG::r1H
                ldy #0
                jsr SETLFS
                lda gREG::r1L
                ldx gREG::r0L
                ldy gREG::r0H
                jsr SETNAM
                lda #2
                ldx #0
                ldy #$40
                jsr LOAD
                bcc :+

                ; Font load failed, so restore RAM bank, set and return error
                pla
                sta BANKSEL::RAM
                lda #ULERR::CANT_LOAD_FONT
                sta UL_lasterr
                rts

                ; Configure the display compositor
:               lda VERA::CTRL
                and #<(~VERA::DISP::SELECT1)
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
                lda #VERA::TILE::WIDTH8 | VERA::TILE::HEIGHT16 | ($040 >> 1)
                sta VERA::L0::TILE_BASE
                stz VERA::L0::HSCROLL
                stz VERA::L0::HSCROLL+1
                stz VERA::L0::VSCROLL
                stz VERA::L0::VSCROLL+1

                ; Configure layer 1
                lda #VERA::MAP::WIDTH128 | VERA::MAP::HEIGHT32 | VERA::TILE2BPP
                sta VERA::L1::CONFIG
                lda #($020 >> 1)
                sta VERA::L1::MAP_BASE
                lda #VERA::TILE::WIDTH8 | VERA::TILE::HEIGHT16 | ($050 >> 1)
                sta VERA::L1::TILE_BASE
                stz VERA::L1::HSCROLL
                stz VERA::L1::HSCROLL+1
                stz VERA::L1::VSCROLL
                stz VERA::L1::VSCROLL+1

                ; Setup palette colors
                ldx #15
:               jsr ULV_setpaletteentry
                dex
                bne :-

                ; Clear layer 0 with 8K of white-on-black spaces and layer 1 with 8K of 0s
                lda VERA::CTRL
                and #$fe
                sta VERA::CTRL
                stz VERA::ADDR
                stz VERA::ADDR+1
                lda #$10
                sta VERA::ADDR+2
                lda VERA::CTRL
                ora #$01
                sta VERA::CTRL
                stz VERA::ADDR
                lda #$20
                sta VERA::ADDR+1
                lda #$10
                sta VERA::ADDR+2
                ldy #(ULCOLOR::BLACK << 4)  | ULCOLOR::WHITE
                lda #' '
:               stz VERA::DATA1
                stz VERA::DATA1
                sta VERA::DATA0
                sty VERA::DATA0
                bit VERA::ADDR+1
                bvc :-

                ; Lastly, initialize the windowing system by allocating the screen window

                ; Restore the RAM bank and return success
                pla
                sta BANKSEL::RAM
                lda #ULERR::OK
                rts
.endproc

.bss

ULM_numbanks:   .res    1
