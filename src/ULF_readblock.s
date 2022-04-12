.include "unilib_impl.inc"

.code

; ULF_readblock - read up to 1KB from the currently open file into buffer at $400
;  Out: YX          - length of data read (0 = EOF/error)
;       carry       - set if error
.proc ULF_readblock
                        ; First we try MACPTR, which will give us up to 512 bytes at a time
                        lda #0
                        tax
                        ldy #4
                        jsr MACPTR
                        rts
.endproc