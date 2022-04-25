.include "unilib_impl.inc"

.code

; ULV_calcglyphcolors - Given character flags and color nibbles, build the base and overlay color bytes
;   In: ULFT_charflags  - Character flags
;       A               - Foreground color = low nibble, background color = high nibble
;  Out: ULV_basecolor   - Base layer color byte
;       ULV_extracolor  - Overlay layer color byte
; Destroys A/X/Y
.proc ULV_calcglyphcolors
                        ; Do we need to reverse the colors?
                        ldx ULFT_charflags
                        bpl @munge_colors

                        ; Swap the colors
                        pha
                        lsr
                        lsr
                        lsr
                        lsr
                        tay
                        pla
                        sty ULV_basecolor
                        asl
                        asl
                        asl
                        asl
                        ora ULV_basecolor

                        ; Save the base color, and put the foreground color in the flags high nibble for the overlay
@munge_colors:          sta ULV_basecolor
                        txa
                        and #$0f
                        sta ULV_extracolor
                        lda ULV_basecolor
                        asl
                        asl
                        asl
                        asl
                        ora ULV_extracolor
                        sta ULV_extracolor
                        rts
.endproc

.bss

ULV_basecolor:          .res    1
ULV_extracolor:         .res    1
