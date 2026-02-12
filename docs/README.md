# UniLib API Documentation

UniLib is a UTF-8 Unicode windowing and utility library for the Commander X16, written in 65C02 assembly using the ca65/cl65 toolchain.

## Modules

| Module | Description |
|--------|-------------|
| [Getting Started](getting-started.md) | Setup, building, and basic usage |
| [Memory Management](memory.md) | Banked RAM allocation (`ulmem_*`) |
| [Data Blocks](datablocks.md) | Reference-counted data containers (`uldb_*`) |
| [Blocklists](blocklists.md) | Ordered collections of data blocks (`ullist_*`) |
| [Iterators](iterators.md) | Unified traversal over memory, VRAM, BRPs, and lists (`ulitr_*`) |
| [Strings](strings.md) | UTF-8 Unicode string handling (`ulstr_*`) |
| [String Tables](stringtables.md) | Collections of named strings (`ulstb_*`) |
| [Windowing](windowing.md) | Window creation, text I/O, scrolling, and UI (`ulwin_*`) |
| [Math](math.md) | Integer arithmetic utilities (`ulmath_*`) |
| [Core](core.md) | Initialization, error handling, character properties |

## Important Notes

- All UniLib functions may change the active RAM bank. Save and restore `BANKSEL::RAM` yourself if you need it preserved.
- UniLib uses `$400`-`$7FF` as scratch space. Do not store persistent data there.
- The library is bundled as a static library (`libunilib.a`), so applications only link the functionality they use.
- Include `unilib.inc` in your assembly source to access all API declarations.

## Quick Example

```asm
.include "unilib.inc"

    ; Initialize UniLib
    ldx #<font_fn
    ldy #>font_fn
    stx gREG::r0L
    sty gREG::r0H
    lda #10                     ; filename length
    sta gREG::r1L
    lda #8                      ; drive number
    sta gREG::r1H
    lda #ULCOLOR::WHITE
    sta gREG::r2L
    lda #ULCOLOR::BLUE
    sta gREG::r2H
    jsr ul_init

    ; Open a bordered window
    lda #5
    sta gREG::r0L               ; start column
    lda #3
    sta gREG::r0H               ; start line
    lda #30
    sta gREG::r1L               ; width
    lda #10
    sta gREG::r1H               ; height
    lda #ULCOLOR::WHITE
    sta gREG::r2L
    lda #ULCOLOR::BLACK
    sta gREG::r2H
    lda #ULWIN_FLAGS::BORDER
    sta gREG::r4H
    jsr ulwin_open              ; returns handle in A

    ; Display text and refresh
    sta my_win
    lda my_win
    ldx #<my_string
    ldy #>my_string
    stx gREG::r0L
    sty gREG::r0H
    clc                         ; no autowrap
    jsr ulwin_putstr
    jsr ulwin_refresh

font_fn:    .byte "unilib.ulf"
my_string:  .byte "Hello, UniLib!", 0
my_win:     .byte 0
```
