; UL_jumptable_b.s - Jump table for Bank B (Display)
;
; Must be first in link order so it starts at $C000.
; Only assembled in ROM builds.

.ifdef ROM_BUILD

.include "unilib.inc"

.segment "BANK_B_CODE"

; Each entry is a 3-byte jmp instruction.
; Order must match unilib_rom.inc jump table addresses.
; NOTE: Unimplemented functions are omitted; add them at the end when ready.

jmp ulwin_box            ; $C000
jmp ulwin_busy           ; $C003
jmp ulwin_clear          ; $C006
jmp ulwin_close          ; $C009
jmp ulwin_delchar        ; $C00C
jmp ulwin_delline        ; $C00F
jmp ulwin_eraseeol       ; $C012
jmp ulwin_errorcfg       ; $C015
jmp ulwin_error          ; $C018
jmp ulwin_flash          ; $C01B
jmp ulwin_flashwait      ; $C01E
jmp ulwin_force          ; $C021
jmp ulwin_getchar        ; $C024
jmp ulwin_getcolor       ; $C027
jmp ulwin_getcolumn      ; $C02A
jmp ulwin_getcursor      ; $C02D
jmp ulwin_gethit         ; $C030
jmp ulwin_getkey         ; $C033
jmp ulwin_getline        ; $C036
jmp ulwin_getpos         ; $C039
jmp ulwin_getsize        ; $C03C
jmp ulwin_getstr         ; $C03F
jmp ulwin_getwin         ; $C042
jmp ulwin_idlecfg        ; $C045
jmp ulwin_inschar        ; $C048
jmp ulwin_insline        ; $C04B
jmp ulwin_move           ; $C04E
jmp ulwin_open           ; $C051
jmp ulwin_putchar        ; $C054
jmp ulwin_putcolor       ; $C057
jmp ulwin_putcursor      ; $C05A
jmp ulwin_putloc         ; $C05D
jmp ulwin_putstr         ; $C060
jmp ulwin_puttitle       ; $C063
jmp ulwin_refresh        ; $C066
jmp ulwin_scroll         ; $C069
jmp ulwin_select         ; $C06C
; Future (add at end when implemented):
; jmp ulwin_getloc       ; ulwin_getloc
; jmp ulwin_joinlines    ; ulwin_joinlines
; jmp ulwin_joincolumns  ; ulwin_joincolumns
; jmp ulwin_resize       ; ulwin_resize
; jmp ulwin_splitline    ; ulwin_splitline
; jmp ulwin_splitcolumn  ; ulwin_splitcolumn

.endif ; ROM_BUILD
