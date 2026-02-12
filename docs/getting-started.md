# Getting Started

## Prerequisites

- [cc65](https://cc65.github.io/) assembler toolchain (ca65/cl65)
- GNU Make
- [Commander X16 emulator](https://github.com/X16Community/x16-emulator) (for testing)

## Building

```sh
cd unilib
make clean && make
```

This produces:
- `libunilib.a` -- static library to link into your project
- `ULTEST.PRG` -- test program

## Running Tests

Copy `ULTEST.PRG` and the font file to a run directory, then launch the emulator:

```sh
cp ULTEST.PRG run/
cp font/unilib.ulf run/
cd run
x16emu -prg ULTEST.PRG -run
```

## Using UniLib in Your Project

1. Include the API header in your assembly source:

```asm
.include "unilib.inc"
```

2. Link against `libunilib.a` when building your program.

3. Ensure `unilib.ulf` (the font file) is available at runtime in the same directory as your program or on the SD card.

## Initialization

Before calling any other UniLib function, you must call `ul_init`:

```asm
    ; Set up r0 = pointer to font filename
    ldx #<font_filename
    ldy #>font_filename
    stx gREG::r0L
    sty gREG::r0H

    ; r1L = filename length, r1H = drive number
    lda #10
    sta gREG::r1L
    lda #8
    sta gREG::r1H

    ; r2 = screen colors
    lda #ULCOLOR::WHITE
    sta gREG::r2L               ; foreground
    lda #ULCOLOR::BLUE
    sta gREG::r2H               ; background

    jsr ul_init
    ; Check A for ULERR::OK
```

This initializes the memory manager, font cache, VERA palette, and the screen window.

## Calling Convention

UniLib uses the Commander X16 register file (`r0`-`r15`, accessed via `gREG::r0L`, `gREG::r0H`, etc.) for passing parameters larger than what fits in A/X/Y. Return values use:

- **A** -- single byte results, error codes, window handles
- **YX** -- 16-bit results (Y = high byte, X = low byte), BRP handles, string handles
- **Carry flag** -- success/failure indicator (set = success for most functions)
- **Zero flag** -- boundary checks in iterators (set = at boundary)
- **r0/r1** -- multi-byte return values (for WORD/TBYTE/DWORD iterator formats)

## RAM Bank Warning

All UniLib functions may change the active RAM bank (`BANKSEL::RAM`). If your code depends on a specific bank being active, save and restore it around UniLib calls:

```asm
    lda BANKSEL::RAM
    pha
    ; ... call UniLib functions ...
    pla
    sta BANKSEL::RAM
```

## Scratch Space

UniLib uses memory at `$400`-`$7FF` as internal scratch space. Do not store data there, as it will be overwritten by UniLib calls.

## Error Handling

Most functions that can fail indicate failure via the carry flag. You can retrieve the specific error code with:

```asm
    jsr ul_geterror     ; returns error code in A
```

See [Core](core.md) for the full list of error codes.
