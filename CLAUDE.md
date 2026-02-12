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
- BRP (Banked RAM Pointer): 2 bytes - high=bank, low=slot index. Address = $A000 + slot*32
- Data blocks (`uldb`): reference-counted wrappers around BRPs (8-byte struct: refcount, size, brp, dataptr)
- Blocklists (`ullist`): reference-counted lists of data block handles (8-byte struct: refcount, size, capacity, brps)
- `UL_varptr`/`UL_var2ptr`: zero-page pointers always accessible regardless of bank

## Common Patterns
- Save/restore caller's bank: `lda BANKSEL::RAM; pha` at entry, `pla; sta BANKSEL::RAM` at exit
- Access handle helper: `jsr ulmem_access; stx UL_varptr; sty UL_varptr+1`
- `ulmem_alloc` with `clc` = don't clear memory, `sec` = clear. Returns BRP in YX, carry set on success
- `ulmem_alloc` with `clc` preserves r0 (useful for realloc pattern)

## 6502 Stack Offset Gotcha
- After `pha; pha` (2 pushes), use `tsx; lda $102,x` to read first push, `$101,x` for second
- NOT $103 - that reads beyond the pushed values into the caller's return address
- PHA stores at $100+SP then decrements SP; after N pushes, first push is at $100+SP+N

## Assembly Pitfalls
- Branch range is -128..+127 bytes. Large functions need `bcs :+; jmp target; :` trampolines
- `ulwin_scroll`: Y=-1 ($FF) scrolls content UP, Y=1 scrolls DOWN
- ULM_scratchspace is 6 bytes; ULDB_scratch is 8 bytes; ULLIST_scratch is 10 bytes
- `.sizeof(STRUCT)` works for struct allocation sizes

## Test Window
- 78x28 window at (1,1). When outputting >28 lines, scroll with `ulwin_scroll` Y=$FF and stay on line 27
- Test helpers: `putmsg` (string), `puthex` (byte as hex), `putdec` (byte as decimal), `newline`, `pass`, `fail`
- All output is echoed to `EMU_STDOUT` ($9FBB) for testbench capture
