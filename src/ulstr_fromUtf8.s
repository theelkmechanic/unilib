.include "unilib_impl.inc"

.code

; ulstr_fromUtf8 - Create a string from a NUL-terminated UTF-8 source
;   In: YX              - Pointer to UTF-8 character sequence (must be in currently accessible memory)
;  Out: YX              - String handle (MSGBLOCK pool index)
;       carry           - Set on error
.proc ulstr_fromUtf8
                        ; Save A
                        pha

                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; How many bytes are we copying?
                        jsr ULS_length

                        ; Is the source in banked memory?
                        cpy #$A0
                        bcc @create_db
                        cpy #$C0
                        bcs @create_db

                        ; Source is in banked memory — copy to $700 to avoid bank conflicts
                        stz ULS_scratch_fptr
                        lda #$07
                        sta ULS_scratch_fptr+1
                        lda ULS_bytelen
                        jsr ULS_copystrdata

@create_db:             ; Save source pointer for later copy
                        stx ULSFU_copysrc
                        sty ULSFU_copysrc+1

                        ; Create data block with size = bytelen (raw UTF-8 only, no header, no NUL)
                        lda ULS_bytelen
                        bne :+
                        jmp @empty_string
:
                        ldx ULS_bytelen
                        ldy #0
                        jsr uldb_create         ; YX = data block handle
                        bcc :+
                        jmp @fail
:
                        ; Save data block handle
                        stx ULSFU_db_handle
                        sty ULSFU_db_handle+1

                        ; Get data block's BRP and access it for writing
                        jsr uldb_getbrp         ; YX = data BRP
                        jsr ulmem_access        ; YX = base address, bank set
                        stx ULS_scratch_fptr
                        sty ULS_scratch_fptr+1

                        ; Copy bytelen bytes from source to data block
                        lda ULS_bytelen
                        ldx ULSFU_copysrc
                        ldy ULSFU_copysrc+1
                        jsr ULS_copystrdata     ; NUL-terminates but we don't care, data block ignores it

                        ; Allocate MSGBLOCK
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_alloc
                        bcc :+
                        jmp @fail_free_db
:
                        ; Save MB handle
                        stx ULSFU_mb_handle
                        sty ULSFU_mb_handle+1

                        ; Access MB to write fields
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; refcount = 1 (already set by pool_alloc)
                        ; data_block = db handle
                        ldy #ULMSG_BLOCK::data_block
                        lda ULSFU_db_handle
                        sta (UL_varptr),y
                        iny
                        lda ULSFU_db_handle+1
                        sta (UL_varptr),y

                        ; start = 0
                        ldy #ULMSG_BLOCK::start
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; end = bytelen
                        ldy #ULMSG_BLOCK::end
                        lda ULS_bytelen
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; cont = $0000
                        ldy #ULMSG_BLOCK::cont
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; next = $0000
                        ldy #ULMSG_BLOCK::next
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; prev = $0000
                        ldy #ULMSG_BLOCK::prev
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; type = STRING_FRAG, flags = 0
                        ldy #ULMSG_BLOCK::type
                        lda #ULMBT::STRING_FRAG
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; Return MB handle in YX
                        ; (data block already has refcount=1 from uldb_create, which is the MB's ownership)
                        ldx ULSFU_mb_handle
                        ldy ULSFU_mb_handle+1
                        pla
                        sta BANKSEL::RAM
                        pla                     ; restore A
                        clc
                        rts

@empty_string:          ; Create a data block of size 0 (will still allocate a minimal BRP)
                        ldx #1                  ; minimum 1 byte allocation
                        ldy #0
                        jsr uldb_create
                        bcs @fail
                        stx ULSFU_db_handle
                        sty ULSFU_db_handle+1

                        ; Allocate MSGBLOCK
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_alloc
                        bcs @fail_free_db

                        ; Save MB handle
                        stx ULSFU_mb_handle
                        sty ULSFU_mb_handle+1

                        ; Access MB
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; data_block
                        ldy #ULMSG_BLOCK::data_block
                        lda ULSFU_db_handle
                        sta (UL_varptr),y
                        iny
                        lda ULSFU_db_handle+1
                        sta (UL_varptr),y

                        ; start = 0, end = 0
                        ldy #ULMSG_BLOCK::start
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        ldy #ULMSG_BLOCK::end
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; cont/next/prev = $0000
                        ldy #ULMSG_BLOCK::cont
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        ldy #ULMSG_BLOCK::next
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        ldy #ULMSG_BLOCK::prev
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; type = STRING_FRAG, flags = 0
                        ldy #ULMSG_BLOCK::type
                        lda #ULMBT::STRING_FRAG
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; Return MB handle
                        ; (data block already has refcount=1 from uldb_create)
                        ldx ULSFU_mb_handle
                        ldy ULSFU_mb_handle+1
                        pla
                        sta BANKSEL::RAM
                        pla                     ; restore A
                        clc
                        rts

@fail_free_db:          ldx ULSFU_db_handle
                        ldy ULSFU_db_handle+1
                        jsr uldb_release

@fail:                  pla
                        sta BANKSEL::RAM
                        pla                     ; restore A
                        sec
                        rts

.endproc

.bss

ULSFU_copysrc:          .res 2
ULSFU_db_handle:        .res 2
ULSFU_mb_handle:        .res 2
