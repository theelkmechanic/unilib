; UL_ksup.s - jsrfar + KSUP bridge vectors for UniLib ROM banks
;
; Assembled once per bank with -D ROM_BUILD and -D BANK_A or -D BANK_B.
; Each bank gets its own copy of jsrfar and the full KERNAL API bridge table.
;
; Based on the standard X16 ROM kernsup pattern.
; See x16-rom/kernsup/kernsup_audio.s for reference.

.ifdef ROM_BUILD

; --- Segment switching helpers ---
.macro KSUP_CODE_SEG
    .ifdef BANK_A
        .segment "BANK_A_CODE"
    .else
        .segment "BANK_B_CODE"
    .endif
.endmacro

.macro KSUP_VEC_SEG
    .ifdef BANK_A
        .segment "BANK_A_VEC"
    .else
        .segment "BANK_B_VEC"
    .endif
.endmacro

; --- Bridge macro ---
; Creates a thunk in CODE that calls through jsrfar to KERNAL bank 0,
; and a jmp entry in the VEC segment at the standard KERNAL API address.
.macro bridge symbol
    .local address
    KSUP_VEC_SEG
address = *
    KSUP_CODE_SEG
symbol:
    .ifdef BANK_A
        jsr uljsrfar_a
    .else
        jsr uljsrfar_b
    .endif
    .word address
    .byte 0             ; BANK_KERNAL
    rts
    KSUP_VEC_SEG
    jmp symbol
.endmacro

; --- jsrfar entry point ---
KSUP_CODE_SEG

.setcpu "65c02"

; Constants required by jsrfar.inc
ram_bank  = 0       ; CPU I/O port 0 (RAM bank select register)
rom_bank  = 1       ; CPU I/O port 1 (ROM bank select register)
jsrfar3n  = $0298   ; jsrfar: RAM part, 65C816 native mode
jsrfar3   = $02C4   ; jsrfar: RAM part
jmpfr     = $02DF   ; jsrfar: core jmp instruction
imparm    = $82     ; jsrfar: temporary byte in zero page

; Each bank exports its own jsrfar symbol to avoid duplicate symbol errors
.ifdef BANK_A
    .export uljsrfar_a
uljsrfar_a:
.else
    .export uljsrfar_b
uljsrfar_b:
.endif
.include "jsrfar.inc"

; --- KSUP vector table ---
; Mirror all KERNAL API vectors at $FEA8-$FFFF.
; Each 'bridge' entry creates a thunk that calls through jsrfar to KERNAL bank 0.
KSUP_VEC_SEG

.ifdef BANK_A
xjsrfar = uljsrfar_a
.else
xjsrfar = uljsrfar_b
.endif

.include "kernsup.inc"

; Signature / padding at $FFF6-$FFF9
.byte 0, 0, 0, 0

; $FFFA-$FFFF: Interrupt vectors filled by linker (fillval in cx16-rom.cfg).
; Non-KERNAL ROM banks on the X16 use fillval=$AA (matching the standard pattern).
; The SMC hardware resets ROM bank to 0 on NMI, so these vectors are effectively
; unused — the KERNAL bank always handles interrupts.

.endif ; ROM_BUILD
