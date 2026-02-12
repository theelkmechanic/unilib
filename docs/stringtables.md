# String Tables (ulstb_*)

String tables are fixed-size arrays of string BRPs stored in banked RAM. They are used for localization, format string substitutions, picklist options, and anywhere you need an indexed collection of strings.

## Functions

### ulstb_create

Create an empty string table with a given number of slots.

```
Input:  A     = number of string slots (1-255)
Output: YX    = string table BRP
```

All slots are initialized to empty (zero).

### ulstb_delete

Delete a string table and release all strings in it.

```
Input:  YX    = string table BRP
```

Releases every non-empty string in the table, then frees the table BRP.

### ulstb_get

Retrieve a string from the table.

```
Input:  A     = string index (1-based)
        r0    = string table BRP
Output: YX    = string BRP at that index
        carry = set on error (index out of range)
```

### ulstb_put

Store a string in the table.

```
Input:  A     = string index (1-based)
        YX    = string BRP to store
        r0    = string table BRP
Output: carry = set on error (index out of range)
```

### ulstb_build

Build a string table from a series of NUL-terminated UTF-8 strings in memory.

```
Input:  YX    = address of concatenated NUL-terminated UTF-8 strings
Output: YX    = string table BRP
```

Reads strings one after another (each NUL-terminated) until it encounters an empty string (a NUL byte immediately) or has read 255 strings.

Example input data layout:
```
.byte "First string", 0
.byte "Second string", 0
.byte "Third string", 0
.byte 0                     ; empty string = end marker
```

### ulstb_load

Load a string table from a file.

```
Input:  A     = device number (typically 8 for SD card)
        YX    = address of filename (NUL-terminated)
Output: YX    = string table BRP
```

Reads a file containing NUL-terminated UTF-8 strings (same format as `ulstb_build`). Stops at an empty string or EOF. Maximum 255 strings.

## Usage Example

```asm
    ; Build a string table from inline data
    ldx #<my_strings
    ldy #>my_strings
    jsr ulstb_build
    stx stbl
    sty stbl+1

    ; Retrieve the second string
    lda #2                  ; 1-based index
    lda stbl
    sta gREG::r0L
    lda stbl+1
    sta gREG::r0H
    lda #2
    jsr ulstb_get
    ; YX = string BRP for "World"

    ; Use with ulstr_format
    ldx #<fmt_str
    ldy #>fmt_str
    jsr ulstr_fromUtf8
    stx gREG::r0L
    sty gREG::r0H
    lda stbl
    sta gREG::r1L
    lda stbl+1
    sta gREG::r1H
    jsr ulstr_format
    ; YX = "Hello, World!"

    ; Clean up
    ldx stbl
    ldy stbl+1
    jsr ulstb_delete

my_strings:
    .byte "Hello", 0
    .byte "World", 0
    .byte 0

fmt_str:
    .byte "{}, {}!", 0
```
