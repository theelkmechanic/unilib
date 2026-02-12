# Unicode Strings (ulstr_*)

UniLib strings are **immutable, reference-counted UTF-8 string objects** stored in banked RAM. Each string is a BRP pointing to a data layout with length metadata followed by raw UTF-8 bytes.

## Internal Layout

| Offset | Size | Description |
|--------|------|-------------|
| 0 | 1 | Byte length (raw UTF-8 bytes, excluding NUL) |
| 1 | 1 | Character length (number of Unicode codepoints) |
| 2 | 1 | Print length (number of printable characters) |
| 3 | N | UTF-8 encoded string data |
| 3+N | 1 | NUL terminator |

The three length fields allow O(1) queries without scanning the string data.

## Creation Functions

All creation functions return a string BRP in YX with carry set on error.

### ulstr_fromUtf8

Create a string from a NUL-terminated UTF-8 byte sequence.

```
Input:  YX    = address of NUL-terminated UTF-8 data
Output: YX    = string BRP
        carry = set on error
```

If the source is in banked RAM (`$A000`-`$BFFF`), the data is first copied to scratch space at `$700` to avoid conflicts with the allocation.

### ulstr_fromPETSCII

Create a string from a NUL-terminated PETSCII byte sequence.

```
Input:  YX    = address of NUL-terminated PETSCII data
Output: YX    = string BRP
        carry = set on error
```

Converts PETSCII characters to their Unicode equivalents.

### ulstr_fromISO8859

Create a string from a NUL-terminated ISO-8859-15 byte sequence.

```
Input:  YX    = address of NUL-terminated ISO-8859-15 data
Output: YX    = string BRP
        carry = set on error
```

## Length Queries

### ulstr_getlen

Get the number of Unicode characters in the string.

```
Input:  YX    = string BRP
Output: YX    = character count
```

### ulstr_getprintlen

Get the number of printable characters (characters that advance the cursor).

```
Input:  YX    = string BRP
Output: YX    = printable character count
```

### ulstr_getrawlen

Get the byte length of the UTF-8 data (not counting the NUL terminator).

```
Input:  YX    = string BRP
Output: YX    = byte count
```

## Search and Comparison

### ulstr_compare

Compare two strings.

```
Input:  r0    = first string BRP
        r1    = second string BRP
        A     = comparison flags
Output: A     = negative if first < second, 0 if equal, positive if first > second
```

### ulstr_find

Find the first occurrence of a Unicode character.

```
Input:  r0    = string BRP
        r1    = start index (character position to begin search)
        AYX   = Unicode codepoint to find
Output: YX    = index of first occurrence (-1 / $FFFF if not found)
```

### ulstr_rfind

Find the last occurrence of a Unicode character.

```
Input:  r0    = string BRP
        r1    = start index (character position to begin reverse search)
        AYX   = Unicode codepoint to find
Output: YX    = index of last occurrence (-1 / $FFFF if not found)
```

## Manipulation

String manipulation functions create **new** string objects (strings are immutable).

### ulstr_append

Concatenate two strings.

```
Input:  r0    = first string BRP
        r1    = second string BRP
Output: YX    = new string BRP (first + second)
```

### ulstr_mid

Extract a substring.

```
Input:  r0    = string BRP
        r1    = start index (character position)
        r2    = length (number of characters)
Output: YX    = new substring BRP
```

### ulstr_format

Format a string with substitutions from a string table.

```
Input:  r0    = format string BRP
        r1    = string table BRP
Output: YX    = new formatted string BRP
        carry = set on error
```

Format placeholders:
- `{}` -- replaced with the next sequential entry from the string table
- `{#}` -- replaced with the entry at index `#` in the string table

## Export Functions

### ulstr_toUtf8

Copy the string's UTF-8 data to a byte iterator.

```
Input:  r0    = string BRP
        YX    = byte iterator handle (destination; must have room for ulstr_getrawlen bytes)
Output: carry = set on error
```

### ulstr_toPETSCII

Convert and copy the string as PETSCII to a byte iterator.

```
Input:  r0    = string BRP
        YX    = byte iterator handle (destination; must have room for ulstr_getlen bytes)
Output: carry = set on error
```

### ulstr_toISO8859

Convert and copy the string as ISO-8859-15 to a byte iterator.

```
Input:  r0    = string BRP
        YX    = byte iterator handle (destination; must have room for ulstr_getlen bytes)
Output: carry = set on error
```

## Lifecycle

### ulstr_release

Release a string reference.

```
Input:  YX    = string BRP
```

Frees the underlying string buffer when no references remain.

## Usage Example

```asm
    ; Create a string from UTF-8 literal
    ldx #<hello_utf8
    ldy #>hello_utf8
    jsr ulstr_fromUtf8
    stx my_string
    sty my_string+1

    ; Get character length
    ldx my_string
    ldy my_string+1
    jsr ulstr_getlen
    ; YX = number of characters

    ; Display in a window
    lda my_window
    lda my_string
    sta gREG::r0L
    lda my_string+1
    sta gREG::r0H
    lda my_window
    clc
    jsr ulwin_putstr

    ; Release when done
    ldx my_string
    ldy my_string+1
    jsr ulstr_release

hello_utf8: .byte "Hello, world!", 0
```
