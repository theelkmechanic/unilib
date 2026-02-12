# Memory Management (ulmem_*)

UniLib includes a banked RAM allocator that manages the X16's banked RAM ($A000-$BFFF per bank) using a slot-based scheme. Allocated blocks are referenced by **Banked RAM Pointers (BRPs)** -- compact 16-bit handles.

## BRP Format

A BRP is a 2-byte value stored in YX (Y = high byte, X = low byte):

- **High byte (Y)** = RAM bank number
- **Low byte (X)** = slot index within the bank

To convert a BRP to an accessible address:
1. Set `BANKSEL::RAM` to the high byte (bank)
2. Address = `$A000 + (low_byte * 32)`

You don't need to do this manually -- use `ulmem_access` instead.

## Memory Layout

Each 8KB bank is divided into 256 slots of 32 bytes each. The first 8 slots (256 bytes) of each bank are reserved for the slot allocation map, leaving 248 usable slots per bank. Maximum single allocation is **7,936 bytes** (248 slots x 32 bytes).

The slot map (first byte of each bank) tracks:
- Byte 0: number of free slots in the bank
- Bytes 1-7: quick-lookup index for small free chunks (1-7 slots)
- Bytes 8-255: allocation length for each slot (0 = free, 1-248 = start of allocation with that many slots, $FF = continuation of previous allocation)

## Functions

### ulmem_alloc

Allocate a block of banked RAM.

```
Input:  YX    = size in bytes (max 7,936)
        carry = set to zero-fill the allocated memory; clear to leave uninitialized
Output: YX    = BRP of allocated block (0/0 on failure)
        carry = set on success, clear on failure
```

The allocator searches banks for the best-fit free chunk. Small allocations (1-7 slots) use a fast lookup table. Larger allocations scan all banks for an exact match first, then fall back to the smallest sufficient chunk.

When called with `clc` (don't clear), **r0 is preserved**. This is useful in reallocation patterns where you need to keep the old BRP.

### ulmem_realloc

Change the size of a previously allocated block.

```
Input:  r0    = BRP to reallocate
        YX    = new size in bytes (max 7,936)
Output: YX    = new BRP (may differ from original; 0/0 on failure)
        carry = set on success, clear on failure
```

If the block is shrinking, excess slots are freed in-place and the original BRP is returned. If growing beyond the current capacity, a new block is allocated, data is copied, and the old block is freed. On failure, the original allocation remains valid.

### ulmem_free

Free a previously allocated block.

```
Input:  YX    = BRP to free
```

Frees all slots occupied by the allocation and consolidates adjacent free chunks. Passing an invalid BRP (wrong bank, unallocated slot, or mid-allocation pointer) triggers a fatal error via `UL_terminate`.

### ulmem_access

Convert a BRP to an accessible memory address.

```
Input:  YX    = BRP
Output: YX    = 16-bit memory address
        BANKSEL::RAM = set to the BRP's bank
```

After calling this, you can read/write the data through the returned address. The RAM bank is switched as a side effect -- save it beforehand if needed.

### ulmem_capacity

Get the allocated capacity of a BRP.

```
Input:  YX    = BRP
Output: YX    = capacity in bytes
```

Returns the actual allocated size (a multiple of 32), which may be larger than the originally requested size.

## Usage Pattern

```asm
    ; Allocate 100 bytes, zero-filled
    ldx #100
    ldy #0
    sec                     ; clear memory
    jsr ulmem_alloc
    bcc @error              ; check for failure
    stx my_brp
    sty my_brp+1

    ; Access the data
    ldx my_brp
    ldy my_brp+1
    jsr ulmem_access
    stx UL_varptr
    sty UL_varptr+1
    ; Now read/write via (UL_varptr)

    ; Free when done
    ldx my_brp
    ldy my_brp+1
    jsr ulmem_free
```
