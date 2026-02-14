; UL_fontdata.s - LZSA2-compressed font data for Bank C (ROM builds only)
;
; The raw unilib.ulf font (39KB) compresses to ~4KB with LZSA2.
; At init time, this data is decompressed directly to VRAM using the
; KERNAL's memory_decompress_internal with a custom ROM bank reader.

.ifdef ROM_BUILD

.segment "BANK_C_DATA"

.export UL_font_compressed

UL_font_compressed:
.incbin "run/unilib.ulf.lzsa2"

.endif ; ROM_BUILD
