# Data Blocks (uldb_*)

Data blocks are **reference-counted wrappers** around BRPs. They allow multiple owners to share the same data, with automatic cleanup when the last reference is released.

## Internal Structure (ULDATA_BLOCK, 8 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 2 | `refcount` | 16-bit reference count |
| 2 | 2 | `size` | Logical data size in bytes |
| 4 | 2 | `brp` | BRP to the actual data |
| 6 | 2 | `dataptr` | Cached memory address of data (bank is high byte of BRP) |

The handle itself is also a BRP (pointing to this 8-byte struct). So a data block uses two BRPs: one for the struct, one for the data.

## Creation Functions

### uldb_create

Allocate a new uninitialized data block.

```
Input:  YX    = size in bytes
Output: YX    = data block handle (BRP)
        carry = set on success, clear on failure
```

Allocates a data BRP of the requested size and wraps it in a new data block with refcount = 1. The data content is **not** zeroed.

### uldb_fromBRP

Wrap an existing BRP in a data block, transferring ownership.

```
Input:  r0    = BRP to wrap (ownership is transferred)
        r1    = logical data size
Output: YX    = data block handle (BRP)
        carry = set on success, clear on failure
```

The passed BRP becomes owned by the data block and will be freed when the reference count reaches zero. Do not free the BRP yourself after this call.

### uldb_fromBuffer

Create a data block by copying from a memory buffer.

```
Input:  r0    = pointer to source memory
        r1    = number of bytes to copy
Output: YX    = data block handle (BRP)
        carry = set on success, clear on failure
```

Allocates a new data BRP, copies the specified bytes from the source address into it, and returns a data block handle.

### uldb_fromIter

Create a data block by reading bytes from an iterator.

```
Input:  r0    = iterator handle
        r1    = number of bytes to read
Output: YX    = data block handle (BRP)
        carry = set on success, clear on failure
```

Reads up to `r1` bytes from the iterator (using `ulitr_fetch_and_inc`) into a newly allocated data BRP. Stops early if the iterator reaches its end or encounters an error.

## Reference Counting

### uldb_addref

Increment the reference count.

```
Input:  YX    = data block handle
```

Call this when a new owner takes a reference to the data block (e.g., when inserting into a blocklist).

### uldb_release

Decrement the reference count. Frees the data block when it reaches zero.

```
Input:  YX    = data block handle
```

When the reference count drops to zero, both the data BRP and the handle BRP are freed.

### uldb_getrefcount

Get the current reference count.

```
Input:  YX    = data block handle
Output: YX    = reference count (16-bit)
```

## Accessors

### uldb_getsize

Get the logical data size.

```
Input:  YX    = data block handle
Output: YX    = size in bytes
```

### uldb_getcapacity

Get the allocated capacity of the underlying data BRP.

```
Input:  YX    = data block handle
Output: YX    = capacity in bytes
```

The capacity may be larger than the logical size (since allocations are rounded to 32-byte slot boundaries).

### uldb_getbrp

Get the underlying data BRP.

```
Input:  YX    = data block handle
Output: YX    = data BRP
```

Use this with `ulmem_access` to read or write the data directly. The data block retains ownership of the BRP -- do not free it.

## Usage Example

```asm
    ; Create a data block with 64 bytes
    ldx #64
    ldy #0
    jsr uldb_create
    bcc @error
    stx db_handle
    sty db_handle+1

    ; Write data into it via its BRP
    ldx db_handle
    ldy db_handle+1
    jsr uldb_getbrp
    jsr ulmem_access
    stx UL_varptr
    sty UL_varptr+1
    lda #$42
    ldy #0
    sta (UL_varptr),y

    ; Share with another owner
    ldx db_handle
    ldy db_handle+1
    jsr uldb_addref         ; refcount is now 2

    ; First owner is done
    ldx db_handle
    ldy db_handle+1
    jsr uldb_release        ; refcount drops to 1, data still alive

    ; Second owner is done
    ldx db_handle
    ldy db_handle+1
    jsr uldb_release        ; refcount drops to 0, data + handle freed
```
