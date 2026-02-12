.include "unilib_impl.inc"

.code

; =============================================================================
; Internal helper
; =============================================================================

; ULLIST_access_handle - Access a blocklist handle BRP, store pointer in UL_varptr
;   In: YX              - handle BRP
;  Out: UL_varptr       - pointer to ULBLOCK_LIST struct
;       BANKSEL::RAM    - set to handle's bank
.proc ULLIST_access_handle
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1
                        rts
.endproc

; =============================================================================
; Creation
; =============================================================================

; ullist_create - Create a new blocklist
;   In: YX              - initial data block handle (0/0 = empty list)
;  Out: YX              - list handle BRP
;       carry           - set on success
.proc ullist_create
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save initial handle
                        stx ULLIST_scratch      ; initial handle lo
                        sty ULLIST_scratch+1    ; initial handle hi

                        ; Allocate brps array BRP: capacity 4 entries = 8 bytes, cleared
                        ldx #8
                        ldy #0
                        sec                     ; clear allocated memory
                        jsr ulmem_alloc
                        bcs :+
                        jmp @fail
:
                        ; Save brps BRP
                        stx ULLIST_scratch+2    ; brps BRP lo
                        sty ULLIST_scratch+3    ; brps BRP hi

                        ; Allocate 8-byte handle BRP for ULBLOCK_LIST struct
                        ldx #.sizeof(ULBLOCK_LIST)
                        ldy #0
                        clc                     ; don't clear
                        jsr ulmem_alloc
                        bcs :+
                        jmp @fail_free_brps
:

                        ; Save handle BRP
                        stx ULLIST_scratch+4    ; handle BRP lo
                        sty ULLIST_scratch+5    ; handle BRP hi

                        ; Access the handle to write struct fields
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Write refcount = 1
                        lda #1
                        ldy #ULBLOCK_LIST::refcount
                        sta (UL_varptr),y
                        lda #0
                        iny
                        sta (UL_varptr),y

                        ; Write size = 0
                        ldy #ULBLOCK_LIST::size
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; Write capacity = 4
                        ldy #ULBLOCK_LIST::capacity
                        lda #4
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; Write brps BRP
                        ldy #ULBLOCK_LIST::brps
                        lda ULLIST_scratch+2
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+3
                        sta (UL_varptr),y

                        ; Check if initial handle is non-zero
                        lda ULLIST_scratch
                        ora ULLIST_scratch+1
                        beq @return_handle

                        ; Store initial handle at brps[0] and set size=1
                        ; Access brps array
                        ldx ULLIST_scratch+2
                        ldy ULLIST_scratch+3
                        jsr ulmem_access
                        stx UL_var2ptr
                        sty UL_var2ptr+1

                        ; Write handle at offset 0
                        lda ULLIST_scratch
                        ldy #0
                        sta (UL_var2ptr),y
                        lda ULLIST_scratch+1
                        iny
                        sta (UL_var2ptr),y

                        ; Update size to 1 in list struct
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1
                        lda #1
                        ldy #ULBLOCK_LIST::size
                        sta (UL_varptr),y
                        lda #0
                        iny
                        sta (UL_varptr),y

                        ; addref on the initial data block
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_addref

@return_handle:         ; Return handle BRP in YX
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

@fail_free_brps:        ldx ULLIST_scratch+2
                        ldy ULLIST_scratch+3
                        jsr ulmem_free

@fail:                  pla
                        sta BANKSEL::RAM
                        clc
                        rts
.endproc

; =============================================================================
; Accessors
; =============================================================================

; ullist_getrefcount - Get reference count
;   In: YX              - list handle BRP
;  Out: YX              - reference count
.proc ullist_getrefcount
                        lda BANKSEL::RAM
                        pha
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::refcount
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

; ullist_addref - Increment reference count
;   In: YX              - list handle BRP
.proc ullist_addref
                        lda BANKSEL::RAM
                        pha
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::refcount
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

; ullist_getsize - Get current number of entries
;   In: YX              - list handle BRP
;  Out: YX              - size
.proc ullist_getsize
                        lda BANKSEL::RAM
                        pha
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        pla
                        sta BANKSEL::RAM
                        rts
.endproc

; ullist_getat - Get data block handle at position
;   In: r0              - list handle BRP
;       A               - position
;  Out: YX              - data block handle at position
;       carry           - set on success, clear if position >= size
.proc ullist_getat
                        pha
                        lda BANKSEL::RAM
                        pha

                        ; Access list struct
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULLIST_access_handle

                        ; Read size
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y

                        ; Save size lo in scratch
                        sta ULLIST_scratch

                        ; Get requested position (from stack, 3rd byte)
                        tsx
                        lda $102,x              ; the pushed A value

                        ; Compare position to size
                        cmp ULLIST_scratch
                        bcs @out_of_range

                        ; Compute offset = position * 2
                        asl
                        sta ULLIST_scratch+1    ; offset

                        ; Read brps BRP from struct
                        ldy #ULBLOCK_LIST::brps
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay

                        ; Access brps array
                        jsr ulmem_access
                        stx UL_var2ptr
                        sty UL_var2ptr+1

                        ; Read entry at offset
                        ldy ULLIST_scratch+1
                        lda (UL_var2ptr),y
                        tax
                        iny
                        lda (UL_var2ptr),y
                        tay

                        ; Restore bank, clean stack, return success
                        pla
                        sta BANKSEL::RAM
                        pla                     ; discard saved A
                        sec
                        rts

@out_of_range:          pla
                        sta BANKSEL::RAM
                        pla                     ; discard saved A
                        ldx #0
                        ldy #0
                        clc
                        rts
.endproc

; =============================================================================
; Mutation
; =============================================================================

; ullist_insert - Insert a data block into the list
;   In: r0              - list handle BRP
;       YX              - data block handle to insert
;       A               - position (255 = end, clamped to size)
;  Out: carry           - set on success
.proc ullist_insert
                        ; Save caller's bank
                        pha
                        lda BANKSEL::RAM
                        pha

                        ; Save insert params
                        stx ULLIST_scratch      ; db handle lo
                        sty ULLIST_scratch+1    ; db handle hi

                        ; Save list handle BRP
                        lda gREG::r0L
                        sta ULLIST_scratch+8    ; list handle lo
                        lda gREG::r0H
                        sta ULLIST_scratch+9    ; list handle hi

                        ; Save position
                        tsx
                        lda $102,x              ; original A (position)
                        sta ULLIST_scratch+2    ; position

                        ; Access list struct
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULLIST_access_handle

                        ; Read size and capacity
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y
                        sta ULLIST_scratch+3    ; size lo
                        ldy #ULBLOCK_LIST::capacity
                        lda (UL_varptr),y
                        sta ULLIST_scratch+4    ; capacity lo

                        ; Clamp position: 255 or >= size -> use size (append)
                        lda ULLIST_scratch+2
                        cmp #255
                        beq @clamp_to_size
                        cmp ULLIST_scratch+3
                        bcc @pos_ok
@clamp_to_size:         lda ULLIST_scratch+3
                        sta ULLIST_scratch+2
@pos_ok:
                        ; Check if need to grow: size == capacity?
                        lda ULLIST_scratch+3
                        cmp ULLIST_scratch+4
                        bne @do_shift

                        ; Grow: read brps BRP from struct into scratch+6/+7
                        ldy #ULBLOCK_LIST::brps
                        lda (UL_varptr),y
                        sta ULLIST_scratch+6
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+7

                        ; New capacity = old capacity * 2
                        lda ULLIST_scratch+4
                        asl
                        sta ULLIST_scratch+4

                        ; Realloc: r0 = brps BRP, YX = new_cap * 2 bytes
                        lda ULLIST_scratch+6
                        sta gREG::r0L
                        lda ULLIST_scratch+7
                        sta gREG::r0H
                        lda ULLIST_scratch+4
                        asl                     ; * 2 for bytes
                        tax
                        ldy #0
                        jsr ulmem_realloc
                        bcs @grow_ok

                        ; Realloc failed
                        pla
                        sta BANKSEL::RAM
                        pla
                        clc
                        rts

@grow_ok:               ; Save new brps BRP
                        stx ULLIST_scratch+6
                        sty ULLIST_scratch+7

                        ; Re-access list struct to update brps and capacity
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_handle

                        ; Write new brps BRP
                        ldy #ULBLOCK_LIST::brps
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y

                        ; Write new capacity
                        ldy #ULBLOCK_LIST::capacity
                        lda ULLIST_scratch+4
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; Shift entries [pos..size-1] up by 2 bytes (backward copy within brps)
@do_shift:              ; Access brps array
                        ldy #ULBLOCK_LIST::brps
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        jsr ulmem_access
                        stx UL_var2ptr
                        sty UL_var2ptr+1

                        ; Backward copy: copy each byte from [pos*2..size*2-1] up by 2
                        lda ULLIST_scratch+3    ; size
                        beq @no_shift           ; empty list, no shift needed
                        cmp ULLIST_scratch+2    ; pos
                        beq @no_shift           ; inserting at end, no shift needed

                        ; Calculate stop point
                        lda ULLIST_scratch+2    ; pos
                        asl
                        sta ULLIST_scratch+5    ; stop at pos*2

                        ; Start at last source byte = size*2-1
                        lda ULLIST_scratch+3    ; size
                        asl                     ; size*2
                        dec                     ; size*2-1
                        tay

@shift_loop:            lda (UL_var2ptr),y      ; read source byte
                        phy
                        iny
                        iny                     ; dest = source + 2
                        sta (UL_var2ptr),y      ; write dest byte
                        ply
                        cpy ULLIST_scratch+5    ; reached pos*2?
                        beq @no_shift           ; done
                        dey                     ; previous source byte
                        bra @shift_loop

@no_shift:              ; Write new handle at pos*2
                        lda ULLIST_scratch+2
                        asl
                        tay
                        lda ULLIST_scratch      ; db handle lo
                        sta (UL_var2ptr),y
                        iny
                        lda ULLIST_scratch+1    ; db handle hi
                        sta (UL_var2ptr),y

                        ; Increment size in list struct
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y
                        clc
                        adc #1
                        sta (UL_varptr),y
                        iny
                        lda (UL_varptr),y
                        adc #0
                        sta (UL_varptr),y

                        ; addref on the inserted data block
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_addref

                        ; Return success
                        pla
                        sta BANKSEL::RAM
                        pla
                        sec
                        rts
.endproc

; ullist_delete - Remove a data block from the list
;   In: r0              - list handle BRP
;       A               - position (255 = end)
;  Out: carry           - set on success, clear if position >= size
.proc ullist_delete
                        pha
                        lda BANKSEL::RAM
                        pha

                        ; Save position
                        tsx
                        lda $102,x              ; original A
                        sta ULLIST_scratch+2    ; position

                        ; Access list struct
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULLIST_access_handle

                        ; Save list handle
                        lda gREG::r0L
                        sta ULLIST_scratch+8
                        lda gREG::r0H
                        sta ULLIST_scratch+9

                        ; Read size
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y
                        sta ULLIST_scratch+3    ; size

                        ; Empty list check
                        bne :+
                        jmp @out_of_range
:
                        ; Clamp position: 255 -> size-1 (last)
                        lda ULLIST_scratch+2
                        cmp #255
                        beq @clamp_to_last
                        cmp ULLIST_scratch+3
                        bcc @pos_ok
                        jmp @out_of_range
@clamp_to_last:         lda ULLIST_scratch+3
                        dec
                        sta ULLIST_scratch+2
@pos_ok:

                        ; Access brps array
                        ldy #ULBLOCK_LIST::brps
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        jsr ulmem_access
                        stx UL_var2ptr
                        sty UL_var2ptr+1

                        ; Read handle at position (to release later)
                        lda ULLIST_scratch+2    ; pos
                        asl
                        tay
                        lda (UL_var2ptr),y
                        sta ULLIST_scratch      ; removed handle lo
                        iny
                        lda (UL_var2ptr),y
                        sta ULLIST_scratch+1    ; removed handle hi

                        ; Forward copy: shift [pos+1..size-1] down by 2
                        lda ULLIST_scratch+2    ; pos
                        inc                     ; pos+1
                        cmp ULLIST_scratch+3    ; size
                        bcs @no_shift           ; pos+1 >= size, nothing to shift

                        ; Stop when source reaches size*2
                        lda ULLIST_scratch+3    ; size
                        asl
                        sta ULLIST_scratch+5    ; stop at size*2

                        ; Start source at (pos+1)*2
                        lda ULLIST_scratch+2    ; pos
                        inc                     ; pos+1
                        asl                     ; (pos+1)*2
                        tay

@shift_down:            lda (UL_var2ptr),y      ; read source byte
                        phy
                        dey
                        dey                     ; dest = source - 2
                        sta (UL_var2ptr),y      ; write dest byte
                        ply
                        iny                     ; next source byte
                        cpy ULLIST_scratch+5    ; reached size*2?
                        bne @shift_down

@no_shift:              ; Decrement size in list struct
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y
                        sec
                        sbc #1
                        sta (UL_varptr),y
                        iny
                        lda (UL_varptr),y
                        sbc #0
                        sta (UL_varptr),y

                        ; Release the removed data block
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_release

                        ; Return success
                        pla
                        sta BANKSEL::RAM
                        pla                     ; discard saved A
                        sec
                        rts

@out_of_range:          pla
                        sta BANKSEL::RAM
                        pla                     ; discard saved A
                        clc
                        rts
.endproc

; =============================================================================
; Lifecycle
; =============================================================================

; ullist_release - Decrement reference count, free when zero
;   In: YX              - list handle BRP
.proc ullist_release
                        lda BANKSEL::RAM
                        pha

                        ; Save handle BRP
                        stx ULLIST_scratch
                        sty ULLIST_scratch+1

                        jsr ULLIST_access_handle

                        ; 16-bit decrement of refcount
                        ldy #ULBLOCK_LIST::refcount
                        lda (UL_varptr),y
                        sec
                        sbc #1
                        sta (UL_varptr),y
                        iny
                        lda (UL_varptr),y
                        sbc #0
                        sta (UL_varptr),y

                        ; Check if refcount is now zero
                        dey
                        ora (UL_varptr),y
                        bne @done

                        ; Read size and brps BRP before freeing
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y
                        sta ULLIST_scratch+2    ; size lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+3    ; size hi

                        ldy #ULBLOCK_LIST::brps
                        lda (UL_varptr),y
                        sta ULLIST_scratch+4    ; brps BRP lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+5    ; brps BRP hi

                        ; Release all data blocks in the list
                        lda ULLIST_scratch+2
                        ora ULLIST_scratch+3
                        beq @free_brps          ; empty list

                        ; Iterate entries and release each
                        stz ULLIST_scratch+6    ; current index

@release_loop:          ; Access brps array
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ulmem_access
                        stx UL_var2ptr
                        sty UL_var2ptr+1

                        ; Read entry at index*2
                        lda ULLIST_scratch+6
                        asl
                        tay
                        lda (UL_var2ptr),y
                        tax
                        iny
                        lda (UL_var2ptr),y
                        tay

                        ; Release this data block
                        jsr uldb_release

                        ; Next entry
                        inc ULLIST_scratch+6
                        lda ULLIST_scratch+6
                        cmp ULLIST_scratch+2    ; compare to size lo
                        bcc @release_loop

@free_brps:             ; Free brps BRP
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ulmem_free

                        ; Free list handle BRP
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr ulmem_free

@done:                  pla
                        sta BANKSEL::RAM
                        rts
.endproc

; =============================================================================
; BSS
; =============================================================================

.bss

ULLIST_scratch:         .res 10
