.include "unilib_impl.inc"

.import __EXTZP_RUN__, __EXTZP_SIZE__

UL_CODE

; ul_init - Initialize UniLib
;   In: r0              Font filename
;       r1L             Font filename length
;       r1H             Drive # to load from
;       r2L             Initial screen foreground color
;       r2H             Initial screen background color
;  Out: A               Error code (0 = OK)
.proc ul_init
                        ; Save caller's r0-r4 (KERNAL convention)
                        lda gREG::r0L
                        pha
                        lda gREG::r0H
                        pha
                        lda gREG::r1L
                        pha
                        lda gREG::r1H
                        pha
                        lda gREG::r2L
                        pha
                        lda gREG::r2H
                        pha
                        lda gREG::r3L
                        pha
                        lda gREG::r3H
                        pha
                        lda gREG::r4L
                        pha
                        lda gREG::r4H
                        pha

                        ; Zero BSS in non-banked low RAM ($0400-$05FF) FIRST,
                        ; before any code writes to BSS variables
                        lda #0
                        ldy #0
:                       sta $0400,y
                        sta $0500,y
                        iny
                        bne :-
                        ; Initialize our zeropage
                        ldx #<(__EXTZP_SIZE__-1)
:                       stz __EXTZP_RUN__,x
                        dex
                        bpl :-
                        stx ULW_screen_handle
                        stx ULW_current_handle

                        ; Initialize screen size (BSS, must be set explicitly)
                        lda #80
                        sta ULW_screen_size
                        lda #30
                        sta ULW_screen_size+1

                        ; Save whatever bank we were on and switch to bank 1
                        lda BANKSEL::RAM
                        pha
                        lda #1
                        sta BANKSEL::RAM

                        ; Initialize pool allocator (reserves banks from top, adjusts MEMTOP)
                        jsr ULPOOL_init

                        ; Initialize the heap (starts at bank 2, sees reduced MEMTOP)
                        jsr ULM_init

                        ; --- Hardcoded bank 1 initialization ---
                        ; Bank 1 layout:
                        ;   $A000-$A7FF: Math multiplication tables (2KB)
                        ;   $A800-$ACFF: Font glyph cache (5 pages)
                        ;   $AD00-$B65F: Window map (80x30)
                        ;   $B660-$B680: Math SMC code copy

                        ; Zero all of bank 1 ($A000-$BFFF, 8KB)
                        lda #1
                        sta BANKSEL::RAM
                        stz UL_varptr
                        lda #$A0
                        sta UL_varptr+1
                        ldy #0
                        tya
@zero_bank1:            sta (UL_varptr),y
                        iny
                        bne @zero_bank1
                        inc UL_varptr+1
                        ldx UL_varptr+1
                        cpx #$C0
                        bne @zero_bank1

                        ; Build multiplication tables at $A000 + copy SMC to $B660
                        jsr ULM_multbl_init

                        ; Initialize font glyph cache at $A800 (bank 1 already zeroed)
                        XCALL ULFT_initfontcache, UNILIB_BANK_B

                        ; Window map at $AD00 is already zeroed

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

                        ; Load font to $08000 in VRAM
.ifdef ROM_BUILD
                        ; ROM mode: if no filename provided (r1L=0), decompress from ROM bank C
                        lda gREG::r1L
                        bne @load_font_from_file

                        ; --- Decompress font from ROM bank C to VRAM ---

                        ; Copy font reader routine to low RAM at $02E2
                        ldx #UL_font_reader_end - UL_font_reader - 1
:                       lda UL_font_reader,x
                        sta $02E2,x
                        dex
                        bpl :-

                        ; Set up VERA data port 0 at $08000 with auto-increment 1
                        lda VERA::CTRL
                        and #$FE
                        sta VERA::CTRL
                        lda #VERA::INC1
                        sta VERA::ADDR+2
                        lda #$80
                        sta VERA::ADDR+1
                        stz VERA::ADDR

                        ; r0 = $C000 (start of compressed data in ROM bank C)
                        lda #$00
                        sta gREG::r0L
                        lda #$C0
                        sta gREG::r0H

                        ; r1 = VERA::DATA0 ($9F23) for VRAM output
                        lda #$23
                        sta gREG::r1L
                        lda #$9F
                        sta gREG::r1H

                        ; r4 = font reader function at $02E2
                        lda #$E2
                        sta gREG::r4L
                        lda #$02
                        sta gREG::r4H

                        ; Call memory_decompress_internal via extapi #15
                        lda #15
                        jsr $FEAB

                        bra @font_loaded

@load_font_from_file:
.endif
                        ; Load font from file (headerless, to VRAM $08000)
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
                        bcc @font_loaded

                        ; Font load failed, so restore RAM bank, set and return error
                        lda #ULERR::LOAD_FAILED
                        sta UL_lasterr
                        jmp @init_done

@font_loaded:
                        ; Clear screen memory
                        lda VERA::CTRL
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
                        XCALL ULV_setpaletteentry, UNILIB_BANK_B
                        tax
                        dex
                        bne :-

                        ; Initialize double buffering
                        stz ULV_backbuf_offset
                        XCALL ULV_swap, UNILIB_BANK_B

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
                        XCALL ulwin_open, UNILIB_BANK_B

                        ; Restore the RAM bank and return success/failure
@init_done:             pla
                        sta BANKSEL::RAM
                        ; Restore caller's r0-r4
                        pla
                        sta gREG::r4H
                        pla
                        sta gREG::r4L
                        pla
                        sta gREG::r3H
                        pla
                        sta gREG::r3L
                        pla
                        sta gREG::r2H
                        pla
                        sta gREG::r2L
                        pla
                        sta gREG::r1H
                        pla
                        sta gREG::r1L
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        lda UL_lasterr
                        rts
.endproc

UL_RODATA

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

.ifdef ROM_BUILD
; Font byte reader for memory_decompress_internal
; Copied to low RAM at $02E2 during init, called indirectly via r4
; Reads one byte from ROM bank C, advances r0, returns byte in A
; Preserves X, Y; disables interrupts while ROM bank C is active
UL_font_reader:
                        sei
                        lda #UNILIB_BANK_C
                        sta $0001               ; switch to ROM bank C
                        lda (gREG::r0L)         ; read byte from compressed data
                        inc gREG::r0L
                        bne :+
                        inc gREG::r0H
:                       stz $0001               ; restore KERNAL bank 0
                        cli
                        rts
UL_font_reader_end:
.endif

UL_DATA

ULW_keyfg:              .byte   ULCOLOR::WHITE      ; keyboard entry window foreground color
ULW_keybg:              .byte   ULCOLOR::BLUE       ; keyboard entry window background color

UL_BSS

ULW_keyidle:            .res    2       ; keyboard idle routine address

ULW_screen_handle:      .res    1       ; Window handle of screen
ULW_current_handle:     .res    1       ; Window handle of current topmost window

; ULW_screen_size must be in BSS (non-banked RAM), not DATA (ROM bank A),
; because ulwin_open in Bank B needs to read it. Initialized by ul_init.
ULW_screen_size:        .res    2       ; Size of screen (lo=columns, hi=lines)
