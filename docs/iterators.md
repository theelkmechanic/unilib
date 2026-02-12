# Iterators (ulitr_*)

Iterators provide a unified interface for stepping through data stored in different locations -- regular memory, video RAM, banked RAM, or across multiple data blocks in a blocklist. They support multiple data formats and can iterate forward or backward.

## Iterator Types (ULITYP)

| Value | Name | Description |
|-------|------|-------------|
| `$00` | `ZPPTR` | Zero-page pointer (16/24-bit), fastest type |
| `$01` | `MEM` | Regular memory range |
| `$02` | `VRAM` | VERA video RAM |
| `$03` | `BRP` | Banked RAM pointer |
| `$04` | `LIST` | Blocklist (seamless iteration across multiple data blocks) |
| `$80` | `REVERSE` | Flag -- OR with any type to reverse iteration direction |

### ZPPTR Details

The zero-page pointer type is a special case that doesn't allocate state. The iterator handle **is** the zero-page address itself (X = ZP address, Y = 0). The pointer at that ZP address is a 2 or 3 byte little-endian value:

- If the high byte is `$A0`-`$BF`, the third byte is treated as a RAM bank, and bank switching is automatic.
- High byte of `$9F` is invalid (device region).
- Increment stops at `$9F00` and wraps at `$C000` (crossing into the next bank).
- `atstart`/`atend` do not work for ZPPTR.
- Cannot be combined with multi-byte formats.

### MEM Details

Iterates over a range of regular memory starting at the address passed to `ulitr_create`. If the address is in banked RAM (`$A000`-`$BFFF`), the caller's RAM bank is captured and used. `atend` is true when the iterator reaches one step past `start + size`.

### VRAM Details

Iterates over VERA video RAM. Pass the low 16 bits of the VRAM address in YX and the 17th bit (bit 16) in the carry flag. `atstart` is true at the beginning of VRAM, `atend` is true one step past the end.

### BRP Details

Iterates over the data stored in a banked RAM allocation. Pass the BRP in YX. If `r0` is 0, the iterator covers the full allocated capacity; otherwise `r0` specifies the byte count. Iteration is bounded to the allocation.

### LIST Details

Iterates seamlessly across all data blocks in a blocklist. Pass the blocklist handle in YX. The iterator automatically crosses data block boundaries -- when it reaches the end of one block, it continues at the start of the next. The iterator state is 20 bytes (vs. 10 for other types) to track the current block index and block boundaries.

## Iterator Formats (ULIFMT)

Formats determine the step size and how values are passed to/from `fetch`/`store`:

| Value | Name | Step | Value Location |
|-------|------|------|----------------|
| `$00` | `BYTE` | 1 byte | A register |
| `$10` | `WORD` | 2 bytes | r0 (r0L = low, r0H = high) |
| `$20` | `TBYTE` | 3 bytes | r0 + r1L |
| `$30` | `DWORD` | 4 bytes | r0 + r1 |
| `$40` | `FLOAT` | 5 bytes | FACC (floating-point accumulator) |
| `$50` | `UTF8` | variable | r0 + r1L (Unicode codepoint) |
| `$60` | `STRINGTABLE` | variable | r0 (string pointer) |

Combine a type and format with OR when creating an iterator:

```asm
    lda #ULITYP::BRP | ULIFMT::WORD
```

## Reverse Flag

OR `ULITYP::REVERSE` (`$80`) with any type to create a reversed iterator. A reversed iterator:
- Starts at the last entry instead of the first
- `inc`/`adv`/`fetch_and_inc` move toward the beginning
- `dec`/`rew`/`fetch_and_dec` move toward the end
- `atstart`/`atend` are swapped

## Functions

### ulitr_create

Create a new iterator.

```
Input:  A     = type | format (e.g., ULITYP::BRP | ULIFMT::BYTE)
        YX    = object to iterate over:
                  ZPPTR: X = zero-page address, Y = 0
                  MEM:   YX = memory address
                  VRAM:  YX = low 16 bits of VRAM address, carry = bit 16
                  BRP:   YX = BRP handle
                  LIST:  YX = blocklist handle
        r0    = byte count (BRP/MEM/VRAM: size of range; BRP only: 0 = use full capacity)
        carry = VRAM bit 16 (VRAM type only)
Output: YX    = iterator handle (BRP)
        carry = set on success, clear on failure
```

### ulitr_delete

Delete an iterator and free its state.

```
Input:  YX    = iterator handle
```

### ulitr_fetch

Read the value at the current iterator position.

```
Input:  YX    = iterator handle
Output: A     = value (BYTE format); r0/r1 for multi-byte formats
        carry = set if error (at end)
```

### ulitr_store

Write a value at the current iterator position.

```
Input:  YX    = iterator handle
        A     = value to store (BYTE format); r0/r1 for multi-byte formats
Output: carry = set if error (at end)
```

### ulitr_inc

Advance the iterator by one entry.

```
Input:  YX    = iterator handle
Output: carry = set if already at end (no movement)
```

### ulitr_dec

Rewind the iterator by one entry.

```
Input:  YX    = iterator handle
Output: carry = set if already at start (no movement)
```

### ulitr_fetch_and_inc

Read the current value, then advance.

```
Input:  YX    = iterator handle
Output: A     = value (BYTE format); r0/r1 for multi-byte formats
        carry = set if at end (no data returned, no advance)
```

This is the most common pattern for reading through data sequentially.

### ulitr_fetch_and_dec

Read the current value, then rewind.

```
Input:  YX    = iterator handle
Output: A     = value (BYTE format); r0/r1 for multi-byte formats
        carry = set if at end (no data returned)
```

If the iterator is at the start after the fetch, the rewind is skipped (the value is still returned).

### ulitr_adv

Advance the iterator by multiple entries.

```
Input:  YX    = iterator handle
        A     = number of entries to advance
Output: carry = set if error
```

### ulitr_rew

Rewind the iterator by multiple entries.

```
Input:  YX    = iterator handle
        A     = number of entries to rewind
Output: carry = set if error
```

### ulitr_atstart

Check if the iterator is at the beginning of its range.

```
Input:  YX    = iterator handle
Output: Z     = set if at start
```

### ulitr_atend

Check if the iterator is past the last valid entry.

```
Input:  YX    = iterator handle
Output: Z     = set if at end
```

When `atend` is true, `fetch` and `store` will fail. You must `dec` or `rew` to get back to valid data.

## Usage Examples

### Reading bytes from a BRP

```asm
    ; Create a byte iterator over a BRP
    lda #ULITYP::BRP | ULIFMT::BYTE
    ldx my_brp
    ldy my_brp+1
    stz gREG::r0L          ; 0 = use full capacity
    stz gREG::r0H
    jsr ulitr_create
    stx iter
    sty iter+1

    ; Read all bytes
@loop:
    ldx iter
    ldy iter+1
    jsr ulitr_fetch_and_inc
    bcs @done               ; carry set = at end
    ; A = byte value, process it...
    bra @loop

@done:
    ldx iter
    ldy iter+1
    jsr ulitr_delete
```

### Iterating a blocklist

```asm
    ; Create a LIST+BYTE iterator over a blocklist
    lda #ULITYP::LIST | ULIFMT::BYTE
    ldx my_list
    ldy my_list+1
    jsr ulitr_create
    stx iter
    sty iter+1

    ; Seamlessly reads across all data blocks
@loop:
    ldx iter
    ldy iter+1
    jsr ulitr_fetch_and_inc
    bcs @done
    ; A = next byte from concatenated blocks
    bra @loop

@done:
    ldx iter
    ldy iter+1
    jsr ulitr_delete
```

### Reverse iteration

```asm
    ; Iterate a BRP backward
    lda #ULITYP::BRP | ULITYP::REVERSE | ULIFMT::BYTE
    ldx my_brp
    ldy my_brp+1
    stz gREG::r0L
    stz gREG::r0H
    jsr ulitr_create
    ; fetch_and_inc now reads from last entry toward first
```
