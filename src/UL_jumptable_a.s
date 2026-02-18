; UL_jumptable_a.s - Jump table for Bank A (Foundation + Data)
;
; Must be first in link order so it starts at $C000.
; Only assembled in ROM builds.

.ifdef ROM_BUILD

.include "unilib.inc"
.import ULS_access          ; internal function, exposed in jump table for test

.segment "BANK_A_CODE"

; Each entry is a 3-byte jmp instruction.
; Order must match unilib_rom.inc jump table addresses.

jmp ul_init              ; $C000
jmp ul_geterror          ; $C003
jmp ulmem_alloc          ; $C006
jmp ulmem_realloc        ; $C009
jmp ulmem_free           ; $C00C
jmp ulmem_access         ; $C00F
jmp ulmem_capacity       ; $C012
jmp uldb_create          ; $C015
jmp uldb_fromBRP         ; $C018
jmp uldb_fromBuffer      ; $C01B
jmp uldb_fromIter        ; $C01E
jmp uldb_getrefcount     ; $C021
jmp uldb_addref          ; $C024
jmp uldb_release         ; $C027
jmp uldb_getsize         ; $C02A
jmp uldb_getcapacity     ; $C02D
jmp uldb_getbrp          ; $C030
jmp ullist_create        ; $C033
jmp ullist_getrefcount   ; $C036
jmp ullist_addref        ; $C039
jmp ullist_release       ; $C03C
jmp ullist_getsize       ; $C03F
jmp ullist_insert        ; $C042
jmp ullist_delete        ; $C045
jmp ullist_getat         ; $C048
jmp ulitr_create         ; $C04B
jmp ulitr_delete         ; $C04E
jmp ulitr_fetch          ; $C051
jmp ulitr_store          ; $C054
jmp ulitr_fetch_and_inc  ; $C057
jmp ulitr_fetch_and_dec  ; $C05A
jmp ulitr_inc            ; $C05D
jmp ulitr_dec            ; $C060
jmp ulitr_adv            ; $C063
jmp ulitr_rew            ; $C066
jmp ulitr_atstart        ; $C069
jmp ulitr_atend          ; $C06C
jmp ulstr_fromUtf8       ; $C06F
jmp ulstr_getlen         ; $C072
jmp ulstr_getprintlen    ; $C075
jmp ulstr_getrawlen      ; $C078
jmp ulstr_compare        ; $C07B
jmp ulstr_find           ; $C07E
jmp ulstr_rfind          ; $C081
jmp ulstr_append         ; $C084
jmp ulstr_mid            ; $C087
jmp ulstr_toUtf8         ; $C08A
jmp ulstr_addref         ; $C08D
jmp ulstr_release        ; $C090
jmp ulstb_create         ; $C093
jmp ulstb_delete         ; $C096
jmp ulstb_get            ; $C099
jmp ulstb_put            ; $C09C
jmp ulstb_build          ; $C09F
jmp ulstb_load           ; $C0A2
jmp ulmath_abs_8         ; $C0A5
jmp ulmath_negate_8      ; $C0A8
jmp ulmath_scmp8_8       ; $C0AB
jmp ulmath_udiv8_8       ; $C0AE
jmp ulmath_udiv16_8      ; $C0B1
jmp ulmath_umul8_8       ; $C0B4
jmp ulmath_umul16_8      ; $C0B7
jmp ul_isprint           ; $C0BA
jmp ULS_access           ; $C0BD (internal, exposed for test)
jmp ulstr_fromPETSCII    ; $C0C0
jmp ulstr_toPETSCII      ; $C0C3
jmp ulstr_fromISO8859    ; $C0C6
jmp ulstr_toISO8859      ; $C0C9
jmp ulstr_format         ; $C0CC

.endif ; ROM_BUILD
