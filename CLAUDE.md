# UniLib Project Notes

## Build & Test
- `cd unilib && make clean && make` builds library + ULTEST.PRG
- Emulator: `~/dev/x16/x16-emulator/build/x16emu` (fork with debug features at `theelkmechanic/x16-emulator`, branch `debug-features`)
- **Automated tests**: `make test` — runs headless via testbench mode, reports pass/fail to stdout
- **Visual mode**: `cd run && x16emu -stp-ignore -prg ULTEST.PRG -run` — shows test window, freezes on summary
- Font file `unilib.ulf` must be in the emulator's working directory (present in `run/`)
- Test output is echoed to emulator debug register `$9FBB` for testbench capture; tests terminate with `stp`
- `EMU` make variable or `X16EMU` env var overrides emulator path

## Architecture
- 65C02 assembly for Commander X16, using ca65/cl65 toolchain
- BRP (Banked RAM Pointer): 2 bytes - high=bank, low=slot index. Address = $A000 + slot*32. Used for variable-size heap allocations (data block payloads, iterator state, etc.)
- `UL_varptr`/`UL_var2ptr`: zero-page pointers always accessible regardless of bank

### Pool Allocator (`src/ulpool.s`)
- Dense typed arrays of fixed-size structs in dedicated RAM banks at top of memory
- Pool handles are 16-bit indices (not BRPs). Index 0 is reserved (never allocated) so YX=0 remains "invalid"
- Three pool types (`ULPOOL` enum in `unilib_impl.inc`):
  - `DATABLOCK` (8 bytes/item, 1024/bank): data block metadata
  - `BLOCKLIST` (8 bytes/item, 1024/bank): list headers
  - `MSGBLOCK` (16 bytes/item, 512/bank): message blocks for list entries
- Bank count auto-scales by total RAM: ≤64 banks→3 pool banks, 65-128→5, ≥129→10
- Pool banks reserved at top of RAM before `ULM_init`; heap only sees the reduced MEMTOP
- Free list: doubly-linked embedded in struct (refcount=0 = free, next/prev at offsets 2-5). Alloc/free are O(1)
- API: `ulpool_alloc` (A=type → YX=handle, C=err), `ulpool_free` (A=type, YX=handle), `ulpool_access` (A=type, YX=handle → YX=address, bank set)
- Per-pool descriptor (8 bytes BSS): base_bank, num_banks, items_shift, addr_shift, free_head, free_count

### Data Blocks (`src/uldb.s`)
- `ULDATA_BLOCK` struct (8 bytes in DATABLOCK pool): refcount, size, brp, dataptr
- Handle is a DATABLOCK pool index. Data payload is still a BRP from the heap
- `uldb_create`: allocs heap BRP for data, then pool slot for metadata
- `uldb_release`: decrements refcount; at zero, frees data BRP via `ulmem_free` then pool slot via `ulpool_free`

### Blocklists (`src/ullist.s`)
- `ULBLOCK_LIST` struct (8 bytes in BLOCKLIST pool): refcount, size, head, tail
- Entries are a doubly-linked chain of message blocks (not an array)
- `ULMSG_BLOCK` struct (16 bytes in MSGBLOCK pool): refcount, data_block, start, end, cont, next, prev, type, flags
  - `data_block`: DATABLOCK pool handle (addref'd on insert, released on delete)
  - `start`/`end`: byte offsets into data block's buffer (view window)
  - `cont`: continuation chain for multi-part data ($0000 = none)
  - `next`/`prev`: doubly-linked list pointers ($0000 = none)
  - `type`: `ULMBT::LIST_ENTRY` or `ULMBT::STRING_FRAG`; `flags`: `ULMBF::READONLY = $80`
- Insert/delete: O(n) walk to position, O(1) append via tail pointer (A=255)
- `ullist_release`: walks chain freeing all MBs and their data blocks, then frees list header

### LIST Iterator State (`src/ULI_list.s`, `src/ULI_core.s`)
- Extended state (20 bytes total, appended after standard 10-byte iterator state):
  - `ULI_STATE_TERM_MB` (offset 10, 2 bytes): terminal MB handle (tail for forward, head for reverse)
  - `ULI_STATE_CUR_MB` (offset 12, 2 bytes): current MB handle
  - `ULI_STATE_BLK_START` (offset 14, 3 bytes): current block data start addr
  - `ULI_STATE_BLK_END` (offset 17, 3 bytes): current block data end addr
- Boundary check follows MB `next`/`prev` links (no list handle needed at runtime)
- `ULI_at_end`: checks `CUR_MB == TERM_MB` (direction-independent, avoids pool access)
- `ULI_list_load_block`: takes MB handle, reads data_block/start/end, computes addr = base + start, end = base + end

## Common Patterns
- Save/restore caller's bank: `lda BANKSEL::RAM; pha` at entry, `pla; sta BANKSEL::RAM` at exit
- Access BRP handle: `jsr ulmem_access; stx UL_varptr; sty UL_varptr+1`
- Access pool handle: `lda #ULPOOL::TYPE; jsr ulpool_access; stx UL_varptr; sty UL_varptr+1`
- `ulmem_alloc` with `clc` = don't clear memory, `sec` = clear. Returns BRP in YX, carry set on error (KERNAL convention)
- `ulmem_alloc` with `clc` preserves r0 (useful for realloc pattern)

## 6502 Stack Offset Gotcha
- After `pha; pha` (2 pushes), use `tsx; lda $102,x` to read first push, `$101,x` for second
- NOT $103 - that reads beyond the pushed values into the caller's return address
- PHA stores at $100+SP then decrements SP; after N pushes, first push is at $100+SP+N

## Assembly Pitfalls
- Branch range is -128..+127 bytes. Large functions need `bcs :+; jmp target; :` trampolines
- `ulwin_scroll`: Y=-1 ($FF) scrolls content UP, Y=1 scrolls DOWN
- ULM_scratchspace is 6 bytes; ULDB_scratch is 8 bytes; ULLIST_scratch is 12 bytes; ULI_list_scratch is 17 bytes
- ULPOOL_scratch is 4 bytes; ULPOOL_a_scratch is 6 bytes (alloc); ULPOOL_init temps are 6 bytes
- `.sizeof(STRUCT)` works for struct allocation sizes

## Test Window
- 78x28 window at (1,1). When outputting >28 lines, scroll with `ulwin_scroll` Y=$FF and stay on line 27
- Test helpers: `putmsg` (string), `puthex` (byte as hex), `putdec` (byte as decimal), `newline`, `pass`, `fail`
- All output is echoed to `EMU_STDOUT` ($9FBB) for testbench capture
