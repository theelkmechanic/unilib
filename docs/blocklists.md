# Blocklists (ullist_*)

Blocklists are **reference-counted, ordered collections of data block handles**. They provide a dynamically-sized array of data blocks that can be iterated seamlessly using the LIST iterator type.

## Internal Structure (ULBLOCK_LIST, 8 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 2 | `refcount` | 16-bit reference count |
| 2 | 2 | `size` | Number of data blocks currently in the list |
| 4 | 2 | `capacity` | Allocated capacity (number of slots) |
| 6 | 2 | `brps` | BRP to the array of data block handles (2 bytes each) |

The list handle is a BRP to this 8-byte struct. The `brps` field points to a separate BRP containing the array of data block handle entries. The array grows automatically (capacity doubles) when it needs more room.

## Creation

### ullist_create

Create a new blocklist.

```
Input:  YX    = initial data block handle (0/0 for empty list)
Output: YX    = list handle (BRP)
        carry = set on success, clear on failure
```

Creates a list with initial capacity of 4 entries. If a non-zero initial handle is provided, it is inserted as the first element and its reference count is incremented.

## Reference Counting

### ullist_addref

Increment the list's reference count.

```
Input:  YX    = list handle
```

### ullist_release

Decrement the reference count. When it reaches zero, releases all data blocks in the list and frees the list.

```
Input:  YX    = list handle
```

Iterates through all entries in the list calling `uldb_release` on each, then frees both the handle array BRP and the list struct BRP.

### ullist_getrefcount

Get the current reference count.

```
Input:  YX    = list handle
Output: YX    = reference count (16-bit)
```

## Accessors

### ullist_getsize

Get the number of data blocks in the list.

```
Input:  YX    = list handle
Output: YX    = entry count (16-bit)
```

### ullist_getat

Get the data block handle at a given position.

```
Input:  r0    = list handle
        A     = position (0-based)
Output: YX    = data block handle at that position
        carry = set on success, clear if position >= size
```

## Mutation

### ullist_insert

Insert a data block into the list at a given position.

```
Input:  r0    = list handle
        YX    = data block handle to insert
        A     = position (0-based; 255 = append to end)
Output: carry = set on success, clear on failure
```

The position is clamped to the current size (so 255 or any value >= size appends to the end). The data block's reference count is incremented. If the list is at capacity, the handle array is automatically reallocated to double its size.

Elements at and after the insertion point are shifted right.

### ullist_delete

Remove a data block from the list at a given position.

```
Input:  r0    = list handle
        A     = position (0-based; 255 = remove last)
Output: carry = set on success, clear if position >= size
```

The removed data block's reference count is decremented via `uldb_release`. Elements after the deletion point are shifted left.

## Usage Example

```asm
    ; Create two data blocks
    ldx #32
    ldy #0
    jsr uldb_create
    stx db1
    sty db1+1

    ldx #32
    ldy #0
    jsr uldb_create
    stx db2
    sty db2+1

    ; Create empty list
    ldx #0
    ldy #0
    jsr ullist_create
    stx list
    sty list+1

    ; Insert both blocks
    lda list
    sta gREG::r0L
    lda list+1
    sta gREG::r0H
    ldx db1
    ldy db1+1
    lda #255                ; append
    jsr ullist_insert

    lda list
    sta gREG::r0L
    lda list+1
    sta gREG::r0H
    ldx db2
    ldy db2+1
    lda #255                ; append
    jsr ullist_insert

    ; Iterate with a LIST iterator (see iterators.md)
    lda #ULITYP::LIST | ULIFMT::BYTE
    ldx list
    ldy list+1
    jsr ulitr_create

    ; Release list (releases all data blocks too)
    ldx list
    ldy list+1
    jsr ullist_release
```
