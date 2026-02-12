.include "unilib_impl.inc"

.code

; =============================================================================
; Internal helper
; =============================================================================

; ULDB_access_handle - Access a data block handle BRP, store pointer in UL_varptr
;   In: YX              - handle BRP
;  Out: UL_varptr       - pointer to ULDATA_BLOCK struct
;       BANKSEL::RAM    - set to handle's bank
.proc ULDB_access_handle
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1
                        rts
.endproc

; =============================================================================
; Creation functions
; =============================================================================

; uldb_create - Allocate a new uninitialized data block of given size
;   In: YX              - size of data to allocate
;  Out: YX              - data block handle BRP
;       carry           - set on success
.proc uldb_create
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save requested size in r1
                        stx gREG::r1L
                        sty gREG::r1H

                        ; Allocate data BRP of requested size
                        clc                     ; don't clear
                        jsr ulmem_alloc
                        bcc @fail

                        ; Save data BRP in r0
                        stx gREG::r0L
                        sty gREG::r0H

                        ; Restore caller's bank and tail-call uldb_fromBRP
                        pla
                        sta BANKSEL::RAM
                        jmp uldb_fromBRP

@fail:                  pla
                        sta BANKSEL::RAM
                        clc
                        rts
.endproc

; uldb_fromBRP - Create a data block handle wrapping an existing BRP
;   In: r0              - BRP to wrap (takes ownership)
;       r1              - logical data size
;  Out: YX              - data block handle BRP
;       carry           - set on success
.proc uldb_fromBRP
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Cache ulmem_access(r0) result for dataptr
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulmem_access
                        ; Save dataptr, data BRP, and size to scratch
                        ; (ulmem_alloc will clobber BANKSEL::RAM)
                        stx ULDB_scratch        ; dataptr lo
                        sty ULDB_scratch+1      ; dataptr hi
                        lda gREG::r0L
                        sta ULDB_scratch+2      ; data BRP lo (slot)
                        lda gREG::r0H
                        sta ULDB_scratch+3      ; data BRP hi (bank)
                        lda gREG::r1L
                        sta ULDB_scratch+4      ; size lo
                        lda gREG::r1H
                        sta ULDB_scratch+5      ; size hi

                        ; Allocate 8-byte handle BRP for ULDATA_BLOCK struct
                        ldx #.sizeof(ULDATA_BLOCK)
                        ldy #0
                        clc                     ; don't clear
                        jsr ulmem_alloc
                        bcc @fail

                        ; Save handle BRP before calling ulmem_access
                        stx ULDB_scratch+6      ; handle BRP lo (slot)
                        sty ULDB_scratch+7      ; handle BRP hi (bank)

                        ; Access the handle to write struct fields
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Write refcount = 1
                        lda #1
                        ldy #ULDATA_BLOCK::refcount
                        sta (UL_varptr),y
                        lda #0
                        iny
                        sta (UL_varptr),y

                        ; Write size
                        ldy #ULDATA_BLOCK::size
                        lda ULDB_scratch+4
                        sta (UL_varptr),y
                        iny
                        lda ULDB_scratch+5
                        sta (UL_varptr),y

                        ; Write brp
                        ldy #ULDATA_BLOCK::brp
                        lda ULDB_scratch+2
                        sta (UL_varptr),y
                        iny
                        lda ULDB_scratch+3
                        sta (UL_varptr),y

                        ; Write dataptr
                        ldy #ULDATA_BLOCK::dataptr
                        lda ULDB_scratch
                        sta (UL_varptr),y
                        iny
                        lda ULDB_scratch+1
                        sta (UL_varptr),y

                        ; Return handle BRP in YX
                        ldx ULDB_scratch+6
                        ldy ULDB_scratch+7

                        ; Restore caller's bank
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

@fail:                  pla
                        sta BANKSEL::RAM
                        clc
                        rts
.endproc

; uldb_fromBuffer - Create data block by copying from a memory buffer
;   In: r0              - pointer to source memory
;       r1              - size to copy
;  Out: YX              - data block handle BRP
;       carry           - set on success
.proc uldb_fromBuffer
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save source pointer and size to scratch
                        lda gREG::r0L
                        sta ULDB_scratch        ; src lo
                        lda gREG::r0H
                        sta ULDB_scratch+1      ; src hi
                        lda gREG::r1L
                        sta ULDB_scratch+2      ; size lo
                        lda gREG::r1H
                        sta ULDB_scratch+3      ; size hi

                        ; Allocate data BRP of requested size
                        ldx gREG::r1L
                        ldy gREG::r1H
                        clc                     ; don't clear
                        jsr ulmem_alloc
                        bcc @fail

                        ; Save data BRP to scratch
                        stx ULDB_scratch+4      ; data BRP lo
                        sty ULDB_scratch+5      ; data BRP hi

                        ; Get destination address (also sets bank)
                        jsr ulmem_access

                        ; Set up MEMORY_COPY parameters: r0=src, r1=dest, r2=count
                        lda ULDB_scratch
                        sta gREG::r0L
                        lda ULDB_scratch+1
                        sta gREG::r0H
                        stx gREG::r1L
                        sty gREG::r1H
                        lda ULDB_scratch+2
                        sta gREG::r2L
                        lda ULDB_scratch+3
                        sta gREG::r2H

                        jsr MEMORY_COPY

                        ; Set up r0 = data BRP, r1 = size for uldb_fromBRP
                        lda ULDB_scratch+4
                        sta gREG::r0L
                        lda ULDB_scratch+5
                        sta gREG::r0H
                        lda ULDB_scratch+2
                        sta gREG::r1L
                        lda ULDB_scratch+3
                        sta gREG::r1H

                        ; Restore caller's bank and tail-call uldb_fromBRP
                        pla
                        sta BANKSEL::RAM
                        jmp uldb_fromBRP

@fail:                  pla
                        sta BANKSEL::RAM
                        clc
                        rts
.endproc

; uldb_fromIter - Create data block by reading from an iterator
;   In: r0              - iterator handle
;       r1              - number of bytes to read
;  Out: YX              - data block handle BRP
;       carry           - set on success
.proc uldb_fromIter
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save iterator and size to scratch
                        lda gREG::r0L
                        sta ULDB_scratch        ; iter lo
                        lda gREG::r0H
                        sta ULDB_scratch+1      ; iter hi
                        lda gREG::r1L
                        sta ULDB_scratch+2      ; size lo (countdown)
                        lda gREG::r1H
                        sta ULDB_scratch+3      ; size hi (countdown)

                        ; Push original size for tail call later
                        lda gREG::r1H
                        pha
                        lda gREG::r1L
                        pha

                        ; Allocate data BRP of requested size
                        ldx gREG::r1L
                        ldy gREG::r1H
                        clc                     ; don't clear
                        jsr ulmem_alloc
                        bcc @fail

                        ; Save data BRP
                        stx ULDB_scratch+4      ; data BRP lo
                        sty ULDB_scratch+5      ; data BRP hi

                        ; Get destination address and set UL_varptr for indirect stores
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Loop: fetch bytes from iterator, store to dest via (UL_varptr)
@loop:                  ; Check if countdown is zero
                        lda ULDB_scratch+2
                        ora ULDB_scratch+3
                        beq @done

                        ; Fetch byte from iterator
                        ldx ULDB_scratch
                        ldy ULDB_scratch+1
                        jsr ulitr_fetch_and_inc
                        bcs @done               ; stop on error/end

                        ; Switch to data BRP bank and store byte
                        pha
                        lda ULDB_scratch+5      ; data BRP bank
                        sta BANKSEL::RAM
                        pla
                        ldy #0
                        sta (UL_varptr),y

                        ; 16-bit increment of UL_varptr
                        inc UL_varptr
                        bne :+
                        inc UL_varptr+1
:
                        ; 16-bit decrement of countdown
                        lda ULDB_scratch+2
                        bne :+
                        dec ULDB_scratch+3
:                       dec ULDB_scratch+2

                        bra @loop

@done:                  ; Pop original size into r1
                        pla
                        sta gREG::r1L
                        pla
                        sta gREG::r1H

                        ; Set up r0 = data BRP
                        lda ULDB_scratch+4
                        sta gREG::r0L
                        lda ULDB_scratch+5
                        sta gREG::r0H

                        ; Restore caller's bank and tail-call uldb_fromBRP
                        pla
                        sta BANKSEL::RAM
                        jmp uldb_fromBRP

@fail:                  ; Pop original size (discard)
                        pla
                        pla

                        pla
                        sta BANKSEL::RAM
                        clc
                        rts
.endproc

; =============================================================================
; Accessors
; =============================================================================

; uldb_getrefcount - Get reference count
;   In: YX              - handle BRP
;  Out: YX              - reference count
.proc uldb_getrefcount
                        lda BANKSEL::RAM
                        pha
                        jsr ULDB_access_handle
                        ldy #ULDATA_BLOCK::refcount
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

; uldb_addref - Increment reference count
;   In: YX              - handle BRP
.proc uldb_addref
                        lda BANKSEL::RAM
                        pha
                        jsr ULDB_access_handle
                        ldy #ULDATA_BLOCK::refcount
                        lda (UL_varptr),y
                        clc
                        adc #1
                        sta (UL_varptr),y
                        iny
                        lda (UL_varptr),y
                        adc #0
                        sta (UL_varptr),y
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

; uldb_release - Decrement reference count, free when zero
;   In: YX              - handle BRP
.proc uldb_release
                        lda BANKSEL::RAM
                        pha

                        ; Save handle BRP
                        stx ULDB_scratch
                        sty ULDB_scratch+1

                        jsr ULDB_access_handle

                        ; 16-bit decrement of refcount
                        ldy #ULDATA_BLOCK::refcount
                        lda (UL_varptr),y
                        sec
                        sbc #1
                        sta (UL_varptr),y
                        iny
                        lda (UL_varptr),y
                        sbc #0
                        sta (UL_varptr),y

                        ; Check if refcount is now zero (hi byte in A)
                        dey                     ; back to refcount lo
                        ora (UL_varptr),y
                        bne @done

                        ; Refcount is zero — free data BRP, then free handle BRP
                        ldy #ULDATA_BLOCK::brp
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        jsr ulmem_free

                        ; Free handle BRP
                        ldx ULDB_scratch
                        ldy ULDB_scratch+1
                        jsr ulmem_free

@done:                  pla
                        sta BANKSEL::RAM
                        rts
.endproc

; uldb_getsize - Get logical data size
;   In: YX              - handle BRP
;  Out: YX              - size
.proc uldb_getsize
                        lda BANKSEL::RAM
                        pha
                        jsr ULDB_access_handle
                        ldy #ULDATA_BLOCK::size
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

; uldb_getcapacity - Get capacity of data BRP
;   In: YX              - handle BRP
;  Out: YX              - capacity in bytes
.proc uldb_getcapacity
                        lda BANKSEL::RAM
                        pha
                        jsr ULDB_access_handle
                        ; Read data BRP from struct
                        ldy #ULDATA_BLOCK::brp
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        ; Get capacity of data BRP
                        jsr ulmem_capacity
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

; uldb_getbrp - Get data BRP
;   In: YX              - handle BRP
;  Out: YX              - data BRP
.proc uldb_getbrp
                        lda BANKSEL::RAM
                        pha
                        jsr ULDB_access_handle
                        ldy #ULDATA_BLOCK::brp
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

; =============================================================================
; BSS
; =============================================================================

.bss

ULDB_scratch:           .res 8          ; temp storage for intermediate BRPs/sizes
