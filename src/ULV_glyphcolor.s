.include "unilib_impl.inc"

.code

; ULV_calcglyphcolors - Given character flags and color nibbles, build the base and overlay color bytes
;   In: ULFT_charflags   - Character flags
;       X               - Foreground color
;       Y               - Background color
;  Out: ULV_basecolor   - Base layer color byte
;       ULV_extracolor  - Overlay layer color byte
; Destroys A/X/Y
.proc ULV_calcglyphcolors
                        ; Do we need to reverse the colors?
                        lda ULFT_charflags
                        bpl @munge_colors

                        ; Swap the colors
                        phx
                        phy
                        plx
                        ply

                        ; Put the foreground color in the flags high nibble for the overlay, and merge the foreground
                        ; and background colors for the base
@munge_colors:          and #$0f
                        sta ULV_extracolor
                        txa
                        asl
                        asl
                        asl
                        asl
                        ora ULV_extracolor
                        sta ULV_extracolor
                        txa
                        and #$0f
                        sta ULV_basecolor
                        tya
                        asl
                        asl
                        asl
                        asl
                        ora ULV_basecolor
                        sta ULV_basecolor
                        rts
.endproc

.bss

ULV_basecolor:          .res    1
ULV_extracolor:         .res    1
