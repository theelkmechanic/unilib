.include "unilib_impl.inc"

.code

; =============================================================================
; Internal helpers
; =============================================================================

; ULLIST_access_handle - Access a blocklist handle, store pointer in UL_varptr
;   In: YX              - handle (pool index)
;  Out: UL_varptr       - pointer to ULBLOCK_LIST struct
;       BANKSEL::RAM    - set to handle's bank
.proc ULLIST_access_handle
                        lda #ULPOOL::BLOCKLIST
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1
                        rts
.endproc

; ULLIST_access_mb - Access a message block handle, store pointer in UL_varptr
;   In: YX              - mb handle (pool index)
;  Out: UL_varptr       - pointer to ULMSG_BLOCK struct
;       BANKSEL::RAM    - set to mb's bank
.proc ULLIST_access_mb
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1
                        rts
.endproc

; ULLIST_walk_to - Walk the message block chain to a given position
;   In: ULLIST_scratch+4/+5 = list handle
;       A = position to walk to (0-based)
;  Out: ULLIST_scratch+8/+9 = mb handle at that position
;       Clobbers BANKSEL::RAM, UL_varptr
.proc ULLIST_walk_to
                        sta ULLIST_walk_count

                        ; Read head from list
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::head
                        lda (UL_varptr),y
                        sta ULLIST_scratch+8    ; cur_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+9    ; cur_mb hi

                        ; Walk position times
                        lda ULLIST_walk_count
                        beq @done
@loop:                  ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::next
                        lda (UL_varptr),y
                        sta ULLIST_scratch+8
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+9
                        dec ULLIST_walk_count
                        bne @loop
@done:                  rts
.endproc

; =============================================================================
; Creation
; =============================================================================

; ullist_create - Create a new blocklist
;   In: YX              - initial data block handle (0/0 = empty list)
;  Out: YX              - list handle (pool index)
;       carry           - set on error
.proc ullist_create
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Save initial db handle
                        stx ULLIST_scratch      ; db handle lo
                        sty ULLIST_scratch+1    ; db handle hi

                        ; Allocate blocklist header from pool
                        lda #ULPOOL::BLOCKLIST
                        jsr ulpool_alloc
                        bcc :+
                        jmp @fail
:
                        ; Save list handle
                        stx ULLIST_scratch+4    ; list handle lo
                        sty ULLIST_scratch+5    ; list handle hi

                        ; Access list header to write fields
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle

                        ; refcount = 1 (already set by pool_alloc)
                        ; size = 0
                        ldy #ULBLOCK_LIST::size
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; head = $0000
                        ldy #ULBLOCK_LIST::head
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; tail = $0000
                        ldy #ULBLOCK_LIST::tail
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; Check if initial handle is non-zero
                        lda ULLIST_scratch
                        ora ULLIST_scratch+1
                        bne :+
                        jmp @return_handle
:

                        ; Get data block size for wr_ptr
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_getsize        ; YX = size
                        stx ULLIST_scratch+2    ; db_size lo
                        sty ULLIST_scratch+3    ; db_size hi

                        ; Allocate message block
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_alloc
                        bcc :+
                        jmp @fail_free_list
:
                        ; Save mb handle
                        stx ULLIST_scratch+6    ; mb handle lo
                        sty ULLIST_scratch+7    ; mb handle hi

                        ; Access MB to write fields
                        ldx ULLIST_scratch+6
                        ldy ULLIST_scratch+7
                        jsr ULLIST_access_mb

                        ; refcount = 1 (already set by pool_alloc)
                        ; data_block = db handle
                        ldy #ULMSG_BLOCK::data_block
                        lda ULLIST_scratch
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+1
                        sta (UL_varptr),y

                        ; start = 0
                        ldy #ULMSG_BLOCK::start
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; end = data block size
                        ldy #ULMSG_BLOCK::end
                        lda ULLIST_scratch+2
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+3
                        sta (UL_varptr),y

                        ; cont = $0000
                        ldy #ULMSG_BLOCK::cont
                        lda #0
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

                        ; type = LIST_ENTRY, flags = 0
                        ldy #ULMSG_BLOCK::type
                        lda #ULMBT::LIST_ENTRY
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; Update list: head=tail=mb, size=1
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle

                        ldy #ULBLOCK_LIST::size
                        lda #1
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ldy #ULBLOCK_LIST::head
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y

                        ldy #ULBLOCK_LIST::tail
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y

                        ; addref on the data block
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_addref

@return_handle:         ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

@fail_free_list:        lda #ULPOOL::BLOCKLIST
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ulpool_free

@fail:                  pla
                        sta BANKSEL::RAM
                        sec
                        rts
.endproc

; =============================================================================
; Accessors
; =============================================================================

; ullist_getrefcount - Get reference count
;   In: YX              - list handle
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
;   In: YX              - list handle
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
;   In: YX              - list handle
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
;   In: r0              - list handle
;       A               - position
;  Out: YX              - data block handle at position
;       carry           - set on error, clear on success
.proc ullist_getat
                        pha
                        lda BANKSEL::RAM
                        pha

                        ; Save list handle
                        lda gREG::r0L
                        sta ULLIST_scratch+4
                        lda gREG::r0H
                        sta ULLIST_scratch+5

                        ; Access list to read size
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y
                        sta ULLIST_scratch+3    ; size lo

                        ; Get requested position
                        tsx
                        lda $102,x              ; saved A

                        ; Compare position to size
                        cmp ULLIST_scratch+3
                        bcs @out_of_range

                        ; Walk to position
                        jsr ULLIST_walk_to      ; result in scratch+8/+9

                        ; Access the found MB to read data_block
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::data_block
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay

                        ; Return data_block handle in YX
                        pla
                        sta BANKSEL::RAM
                        pla                     ; discard saved A
                        clc
                        rts

@out_of_range:          pla
                        sta BANKSEL::RAM
                        pla                     ; discard saved A
                        ldx #0
                        ldy #0
                        sec
                        rts
.endproc

; =============================================================================
; Mutation
; =============================================================================

; ullist_insert - Insert a data block into the list
;   In: r0              - list handle
;       YX              - data block handle to insert
;       A               - position (255 = end, clamped to size)
;  Out: carry           - set on error
.proc ullist_insert
                        ; Save caller's bank
                        pha
                        lda BANKSEL::RAM
                        pha

                        ; Save params
                        stx ULLIST_scratch      ; db handle lo
                        sty ULLIST_scratch+1    ; db handle hi
                        lda gREG::r0L
                        sta ULLIST_scratch+4    ; list handle lo
                        lda gREG::r0H
                        sta ULLIST_scratch+5    ; list handle hi

                        ; Save position
                        tsx
                        lda $102,x              ; original A (position)
                        sta ULLIST_scratch+2    ; position

                        ; Access list struct to read size
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::size
                        lda (UL_varptr),y
                        sta ULLIST_scratch+3    ; size

                        ; Clamp position: 255 or >= size -> use size (append)
                        lda ULLIST_scratch+2
                        cmp #255
                        beq @clamp
                        cmp ULLIST_scratch+3
                        bcc @pos_ok
@clamp:                 lda ULLIST_scratch+3
                        sta ULLIST_scratch+2
@pos_ok:
                        ; Get data block size for wr_ptr
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_getsize        ; YX = size
                        stx ULLIST_scratch+10   ; db_size lo
                        sty ULLIST_scratch+11   ; db_size hi

                        ; Allocate message block
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_alloc
                        bcc :+
                        jmp @fail
:
                        stx ULLIST_scratch+6    ; new mb handle lo
                        sty ULLIST_scratch+7    ; new mb handle hi

                        ; Populate common MB fields (next/prev set per case)
                        ldx ULLIST_scratch+6
                        ldy ULLIST_scratch+7
                        jsr ULLIST_access_mb

                        ; data_block
                        ldy #ULMSG_BLOCK::data_block
                        lda ULLIST_scratch
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+1
                        sta (UL_varptr),y
                        ; start = 0
                        ldy #ULMSG_BLOCK::start
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        ; end = db size
                        ldy #ULMSG_BLOCK::end
                        lda ULLIST_scratch+10
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+11
                        sta (UL_varptr),y
                        ; cont = $0000
                        ldy #ULMSG_BLOCK::cont
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        ; type = LIST_ENTRY, flags = 0
                        ldy #ULMSG_BLOCK::type
                        lda #ULMBT::LIST_ENTRY
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; Dispatch by insert case
                        lda ULLIST_scratch+3    ; size
                        beq @insert_empty

                        lda ULLIST_scratch+2    ; position
                        cmp ULLIST_scratch+3    ; == size?
                        beq @insert_append
                        cmp #0
                        bne :+
                        jmp @insert_prepend
:                       jmp @insert_middle

                        ; --- Empty list ---
@insert_empty:
                        ; Set new_mb: next=$0000, prev=$0000
                        ldx ULLIST_scratch+6
                        ldy ULLIST_scratch+7
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::next
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        ldy #ULMSG_BLOCK::prev
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; head = tail = new_mb
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::head
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y
                        ldy #ULBLOCK_LIST::tail
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y
                        jmp @finish_insert

                        ; --- Append (position == size) ---
@insert_append:
                        ; Read tail from list
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::tail
                        lda (UL_varptr),y
                        sta ULLIST_scratch+8    ; old_tail lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+9    ; old_tail hi

                        ; Set new_mb: next=$0000, prev=old_tail
                        ldx ULLIST_scratch+6
                        ldy ULLIST_scratch+7
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::next
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        ldy #ULMSG_BLOCK::prev
                        lda ULLIST_scratch+8
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+9
                        sta (UL_varptr),y

                        ; Set old_tail.next = new_mb
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::next
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y

                        ; Update list tail = new_mb
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::tail
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y
                        jmp @finish_insert

                        ; --- Prepend (position == 0) ---
@insert_prepend:
                        ; Read head from list
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::head
                        lda (UL_varptr),y
                        sta ULLIST_scratch+8    ; old_head lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+9    ; old_head hi

                        ; Set new_mb: next=old_head, prev=$0000
                        ldx ULLIST_scratch+6
                        ldy ULLIST_scratch+7
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::next
                        lda ULLIST_scratch+8
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+9
                        sta (UL_varptr),y
                        ldy #ULMSG_BLOCK::prev
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; Set old_head.prev = new_mb
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::prev
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y

                        ; Update list head = new_mb
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::head
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y
                        jmp @finish_insert

                        ; --- Middle insert (0 < position < size) ---
@insert_middle:
                        ; Walk to position to find cur_mb
                        lda ULLIST_scratch+2    ; position
                        jsr ULLIST_walk_to      ; scratch+8/+9 = cur_mb

                        ; Access cur_mb to read its .prev and set .prev = new_mb
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::prev
                        lda (UL_varptr),y
                        sta ULLIST_scratch+10   ; prev_mb lo (reusing db_size slot)
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+11   ; prev_mb hi
                        ; Set cur_mb.prev = new_mb
                        ldy #ULMSG_BLOCK::prev
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y

                        ; Set new_mb: next=cur_mb, prev=prev_mb
                        ldx ULLIST_scratch+6
                        ldy ULLIST_scratch+7
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::next
                        lda ULLIST_scratch+8
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+9
                        sta (UL_varptr),y
                        ldy #ULMSG_BLOCK::prev
                        lda ULLIST_scratch+10
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+11
                        sta (UL_varptr),y

                        ; Set prev_mb.next = new_mb
                        ldx ULLIST_scratch+10
                        ldy ULLIST_scratch+11
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::next
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y
                        ; (head/tail unchanged for middle insert)

                        ; --- Common finish: increment size, addref ---
@finish_insert:
                        ; Increment size in list struct
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
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

                        ; addref on the data block
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_addref

                        ; Return success
                        pla
                        sta BANKSEL::RAM
                        pla
                        clc
                        rts

@fail:                  pla
                        sta BANKSEL::RAM
                        pla
                        sec
                        rts
.endproc

; ullist_delete - Remove a data block from the list
;   In: r0              - list handle
;       A               - position (255 = end)
;  Out: carry           - set on error, clear on success
.proc ullist_delete
                        pha
                        lda BANKSEL::RAM
                        pha

                        ; Save params
                        lda gREG::r0L
                        sta ULLIST_scratch+4    ; list handle lo
                        lda gREG::r0H
                        sta ULLIST_scratch+5    ; list handle hi

                        ; Save position
                        tsx
                        lda $102,x              ; original A
                        sta ULLIST_scratch+2    ; position

                        ; Access list to read size
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
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
                        ; Walk to position
                        lda ULLIST_scratch+2
                        jsr ULLIST_walk_to      ; scratch+8/+9 = target MB

                        ; Access MB to read data_block, prev, next
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::data_block
                        lda (UL_varptr),y
                        sta ULLIST_scratch      ; db handle lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+1    ; db handle hi
                        ldy #ULMSG_BLOCK::prev
                        lda (UL_varptr),y
                        sta ULLIST_scratch+6    ; prev_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+7    ; prev_mb hi
                        ldy #ULMSG_BLOCK::next
                        lda (UL_varptr),y
                        sta ULLIST_scratch+10   ; next_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+11   ; next_mb hi

                        ; Unlink: if prev != $0000, set prev.next = next
                        lda ULLIST_scratch+6
                        ora ULLIST_scratch+7
                        beq @update_head

                        ldx ULLIST_scratch+6
                        ldy ULLIST_scratch+7
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::next
                        lda ULLIST_scratch+10
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+11
                        sta (UL_varptr),y
                        bra @check_next

                        ; prev == $0000: this was the head, update list.head = next
@update_head:           ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::head
                        lda ULLIST_scratch+10
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+11
                        sta (UL_varptr),y

@check_next:            ; Unlink: if next != $0000, set next.prev = prev
                        lda ULLIST_scratch+10
                        ora ULLIST_scratch+11
                        beq @update_tail

                        ldx ULLIST_scratch+10
                        ldy ULLIST_scratch+11
                        jsr ULLIST_access_mb
                        ldy #ULMSG_BLOCK::prev
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y
                        bra @free_mb

                        ; next == $0000: this was the tail, update list.tail = prev
@update_tail:           ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ULLIST_access_handle
                        ldy #ULBLOCK_LIST::tail
                        lda ULLIST_scratch+6
                        sta (UL_varptr),y
                        iny
                        lda ULLIST_scratch+7
                        sta (UL_varptr),y

@free_mb:               ; Free the message block
                        lda #ULPOOL::MSGBLOCK
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ulpool_free

                        ; Decrement size
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
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

                        ; Release the data block
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_release

                        ; Return success
                        pla
                        sta BANKSEL::RAM
                        pla
                        clc
                        rts

@out_of_range:          pla
                        sta BANKSEL::RAM
                        pla
                        sec
                        rts
.endproc

; =============================================================================
; Lifecycle
; =============================================================================

; ullist_release - Decrement reference count, free when zero
;   In: YX              - list handle
.proc ullist_release
                        lda BANKSEL::RAM
                        pha

                        ; Save handle
                        stx ULLIST_scratch+4
                        sty ULLIST_scratch+5

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

                        ; Read head for chain walk
                        ldy #ULBLOCK_LIST::head
                        lda (UL_varptr),y
                        sta ULLIST_scratch+8    ; cur_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+9    ; cur_mb hi

                        ; Walk chain: release each data block, free each MB
@release_loop:          lda ULLIST_scratch+8
                        ora ULLIST_scratch+9
                        beq @free_list          ; end of chain

                        ; Access current MB
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ULLIST_access_mb

                        ; Read data_block and next
                        ldy #ULMSG_BLOCK::data_block
                        lda (UL_varptr),y
                        sta ULLIST_scratch      ; db lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+1    ; db hi
                        ldy #ULMSG_BLOCK::next
                        lda (UL_varptr),y
                        sta ULLIST_scratch+6    ; next_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULLIST_scratch+7    ; next_mb hi

                        ; Release data block
                        ldx ULLIST_scratch
                        ldy ULLIST_scratch+1
                        jsr uldb_release

                        ; Free this MB
                        lda #ULPOOL::MSGBLOCK
                        ldx ULLIST_scratch+8
                        ldy ULLIST_scratch+9
                        jsr ulpool_free

                        ; Advance to next MB
                        lda ULLIST_scratch+6
                        sta ULLIST_scratch+8
                        lda ULLIST_scratch+7
                        sta ULLIST_scratch+9
                        bra @release_loop

@free_list:             ; Free list header
                        lda #ULPOOL::BLOCKLIST
                        ldx ULLIST_scratch+4
                        ldy ULLIST_scratch+5
                        jsr ulpool_free

@done:                  pla
                        sta BANKSEL::RAM
                        rts
.endproc

; =============================================================================
; BSS
; =============================================================================

.bss

ULLIST_scratch:         .res 12
ULLIST_walk_count:      .res 1
