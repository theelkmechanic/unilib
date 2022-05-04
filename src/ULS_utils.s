.include "unilib_impl.inc"

.code

; ULS_nextchar - Get UTF-8 character at current scratch pointer and step to next character
;   In: ULS_scratch_fptr - Pointer to NUL-terminated UTF-8 character sequence
;                          (NOTE: This will always be in low memory or the current bank)
;  Out: AYX              - Unicode character (0 of at end of string)
;       ULS_scratch_fptr - Advanced to next character (or end of string)
;       carry            - Set if at end of string
.proc ULS_nextchar
                        ; Read the current character; if the high bit is clear, we're done immediately
                        ; because it's either a NUL (so we can exit without advancing) or it's ASCII
                        ; (so we can advance and exit)
                        ldx #0
                        ldy #0
@restart:               lda (ULS_scratch_fptr)
                        bmi @extended
@failonzero:            sec
                        beq :+

                        ; Switch A and X for the ASCII situation
                        pha
                        txa
                        plx

                        ; Advance the pointer and exit with not at end
@advance:               clc
                        inc ULS_scratch_fptr
                        bne :+
                        inc ULS_scratch_fptr+1
:                       rts

                        ; Handle extended characters; first make sure we're not in the middle of a character,
                        ; and if we are, treat it like end of string and bail
@extended:              stz ULS_scratch_char+2
                        stz ULS_scratch_char+1
                        sta ULS_scratch_char
                        bbr6 ULS_scratch_char,@fail

                        ; Okay, see how many high bits we have set; 6 is set, so if 5 is clear we have 2 bytes,
                        ; else if 4 is clear we have 3 bytes, else if 3 is clear we have 4 bytes, else we have
                        ; an error, so see if we can find the next character
                        bbr5 ULS_scratch_char,@twobytes
                        bbr4 ULS_scratch_char,@threebytes
                        bbs3 ULS_scratch_char,@fail

                        ; Handle 4 bytes; start with low three bits of this one
                        ldx #3
                        lda #$07
@removemarker:          and ULS_scratch_char
                        sta ULS_scratch_char

                        ; Advance to the next character
@shiftloop:             jsr @advance

                        ; Make sure it's a continuation byte
                        lda (ULS_scratch_fptr)
                        bmi :+
@fail:                  lda #ULERR::INVALID_UTF8
                        sta UL_lasterr
                        lda #0
                        bra @failonzero
                        bit #$40
                        bne @fail

                        ; Shift in the next six bits
:                       asl
                        asl
                        ldy #6
:                       asl
                        rol ULS_scratch_char
                        rol ULS_scratch_char+1
                        rol ULS_scratch_char+2
                        dey
                        bne :-

                        ; Do the next continuation byte
                        dex
                        bne @shiftloop

                        ; Full character is in ULS_scratch_char, so load it and return (we've already
                        ; advanced past it)
                        ldx ULS_scratch_char
                        ldy ULS_scratch_char+1
                        lda ULS_scratch_char+2
                        bra @advance

                        ; Handle three bytes
@threebytes:            ldx #2
                        lda #$0f
                        bra @removemarker

                        ; Handle two bytes
@twobytes:              ldx #1
                        lda #$1f
                        bra @removemarker
.endproc

; ULS_length - Find length in bytes of UTF-8 string (max 252 bytes)
;   In: YX              - Pointer to NUL-terminated UTF-8 character sequence
;  Out: ULS_bytelen     - Valid UTF-8 length (in bytes)
;       ULS_charlen     - Valid UTF-8 length (in characters)
;       ULS_printlen    - Valid UTF-8 length (in printable characters)
.proc ULS_length
                        ; Save the start pointer
                        stx ULS_length_ptrsave
                        sty ULS_length_ptrsave+1
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        ; Zero the length counters
                        stz ULS_bytelen
                        stz ULS_charlen
                        stz ULS_printlen

                        ; Scan characters until we get to the end of parseable UTF-8
:                       lda ULS_scratch_fptr
                        sta @prevptrsub+1
                        jsr ULS_nextchar
                        pha
                        bcs @eos

                        ; Count bytes
                        lda ULS_scratch_fptr
                        sec
@prevptrsub:            sbc #$00
                        clc
                        adc ULS_bytelen
                        cmp #252
                        bcs @eos
                        sta ULS_bytelen
                        pla

                        ; Count characters
                        inc ULS_charlen

                        ; Count printable characters
                        jsr ul_isprint
                        bcc :-
                        inc ULS_printlen
                        bra :-

                        ; Restore YX and return
@eos:                   pla
                        ldx ULS_length_ptrsave
                        ldy ULS_length_ptrsave+1
                        rts
.endproc

.bss

ULS_length_ptrsave:     .res    2
ULS_bytelen:            .res    1
ULS_charlen:            .res    1
ULS_printlen:           .res    1

.segment "EXTZP": zeropage

ULS_scratch_fptr:       .res    3
ULS_scratch_char:       .res    3
