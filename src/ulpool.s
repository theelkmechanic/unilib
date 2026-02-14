.include "unilib_impl.inc"

; Pool descriptor layout (8 bytes per descriptor, 3 descriptors = 24 bytes)
; Offsets within each descriptor:
ULPD_BASE_BANK      = 0
ULPD_NUM_BANKS      = 1
ULPD_ITEMS_SHIFT    = 2    ; log2(items per bank): 10 or 9
ULPD_ADDR_SHIFT     = 3    ; log2(item size): 3 or 4
ULPD_FREE_HEAD      = 4    ; 2 bytes
ULPD_FREE_COUNT     = 6    ; 2 bytes
ULPD_SIZE           = 8

UL_CODE

; =============================================================================
; ulpool_access - Convert pool handle to banked RAM address
;   In: A               - pool type (ULPOOL::DATABLOCK/BLOCKLIST/MSGBLOCK)
;       YX              - handle (16-bit pool index)
;  Out: YX              - 16-bit address
;       BANKSEL::RAM    - set to correct bank
; =============================================================================
.proc ulpool_access
                        ; Save index
                        stx ULPOOL_scratch
                        sty ULPOOL_scratch+1

                        ; Get descriptor offset (pool_type * 8)
                        asl
                        asl
                        asl
                        tax

                        ; Load base_bank and addr_shift
                        lda ULPOOL_descs + ULPD_BASE_BANK, x
                        sta ULPOOL_scratch+2    ; base_bank
                        lda ULPOOL_descs + ULPD_ADDR_SHIFT, x

                        cmp #4
                        beq @access_16

                        ; --- 8-byte items (addr_shift=3, items_shift=10) ---
@access_8:
                        ; bank = base_bank + (index_hi >> 2)
                        lda ULPOOL_scratch+1    ; index_hi
                        lsr
                        lsr
                        clc
                        adc ULPOOL_scratch+2    ; + base_bank
                        sta BANKSEL::RAM

                        ; addr_lo = index_lo << 3
                        lda ULPOOL_scratch      ; index_lo
                        asl
                        asl
                        asl
                        pha                     ; save addr_lo

                        ; addr_hi = ((index_lo >> 5) | ((index_hi & $03) << 3)) + $A0
                        lda ULPOOL_scratch      ; index_lo
                        lsr
                        lsr
                        lsr
                        lsr
                        lsr                     ; index_lo >> 5
                        sta ULPOOL_scratch+3
                        lda ULPOOL_scratch+1    ; index_hi
                        and #$03
                        asl
                        asl
                        asl                     ; (index_hi & $03) << 3
                        ora ULPOOL_scratch+3
                        clc
                        adc #$A0
                        tay                     ; Y = addr_hi
                        plx                     ; X = addr_lo
                        rts

                        ; --- 16-byte items (addr_shift=4, items_shift=9) ---
@access_16:
                        ; bank = base_bank + (index_hi >> 1)
                        lda ULPOOL_scratch+1    ; index_hi
                        lsr
                        clc
                        adc ULPOOL_scratch+2    ; + base_bank
                        sta BANKSEL::RAM

                        ; addr_lo = index_lo << 4
                        lda ULPOOL_scratch      ; index_lo
                        asl
                        asl
                        asl
                        asl
                        pha                     ; save addr_lo

                        ; addr_hi = ((index_lo >> 4) | ((index_hi & $01) << 4)) + $A0
                        lda ULPOOL_scratch      ; index_lo
                        lsr
                        lsr
                        lsr
                        lsr                     ; index_lo >> 4
                        sta ULPOOL_scratch+3
                        lda ULPOOL_scratch+1    ; index_hi
                        and #$01
                        asl
                        asl
                        asl
                        asl                     ; (index_hi & $01) << 4
                        ora ULPOOL_scratch+3
                        clc
                        adc #$A0
                        tay                     ; Y = addr_hi
                        plx                     ; X = addr_lo
                        rts
.endproc

; =============================================================================
; ulpool_alloc - Allocate an item from a pool
;   In: A               - pool type
;  Out: YX              - handle (16-bit pool index)
;       carry           - set on error (pool exhausted)
; =============================================================================
.proc ulpool_alloc
                        sta ULPOOL_a_pool_type

                        ; Get descriptor offset
                        asl
                        asl
                        asl
                        tax
                        stx ULPOOL_a_desc_off

                        ; Check free_count > 0
                        lda ULPOOL_descs + ULPD_FREE_COUNT, x
                        ora ULPOOL_descs + ULPD_FREE_COUNT + 1, x
                        beq @fail

                        ; Read free_head (this is our allocated handle)
                        lda ULPOOL_descs + ULPD_FREE_HEAD, x
                        sta ULPOOL_a_handle
                        lda ULPOOL_descs + ULPD_FREE_HEAD + 1, x
                        sta ULPOOL_a_handle+1

                        ; Access the head item to read its next pointer
                        lda ULPOOL_a_pool_type
                        ldx ULPOOL_a_handle
                        ldy ULPOOL_a_handle+1
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Read next (offset 2) = new free_head
                        ldy #2
                        lda (UL_varptr),y
                        sta ULPOOL_a_new_head
                        iny
                        lda (UL_varptr),y
                        sta ULPOOL_a_new_head+1

                        ; Set refcount = 1 on the allocated item
                        ldy #0
                        lda #1
                        sta (UL_varptr),y
                        iny
                        lda #0
                        sta (UL_varptr),y

                        ; If new_head != $FFFF, set new_head.prev = $FFFF
                        lda ULPOOL_a_new_head
                        and ULPOOL_a_new_head+1
                        cmp #$FF
                        beq @update_desc

                        ; Access new head to clear its prev
                        lda ULPOOL_a_pool_type
                        ldx ULPOOL_a_new_head
                        ldy ULPOOL_a_new_head+1
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1
                        ldy #4                  ; prev offset
                        lda #$FF
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

@update_desc:           ldx ULPOOL_a_desc_off

                        ; free_head = new_head
                        lda ULPOOL_a_new_head
                        sta ULPOOL_descs + ULPD_FREE_HEAD, x
                        lda ULPOOL_a_new_head+1
                        sta ULPOOL_descs + ULPD_FREE_HEAD + 1, x

                        ; Decrement free_count
                        lda ULPOOL_descs + ULPD_FREE_COUNT, x
                        sec
                        sbc #1
                        sta ULPOOL_descs + ULPD_FREE_COUNT, x
                        lda ULPOOL_descs + ULPD_FREE_COUNT + 1, x
                        sbc #0
                        sta ULPOOL_descs + ULPD_FREE_COUNT + 1, x

                        ; Return handle in YX
                        ldx ULPOOL_a_handle
                        ldy ULPOOL_a_handle+1
                        clc
                        rts

@fail:                  ldx #0
                        ldy #0
                        sec
                        rts
.endproc

; =============================================================================
; ulpool_free - Return an item to a pool
;   In: A               - pool type
;       YX              - handle (16-bit pool index)
; =============================================================================
.proc ulpool_free
                        sta ULPOOL_a_pool_type
                        stx ULPOOL_a_handle
                        sty ULPOOL_a_handle+1

                        ; Get descriptor offset
                        asl
                        asl
                        asl
                        tax
                        stx ULPOOL_a_desc_off

                        ; Read current free_head (will become freed.next)
                        lda ULPOOL_descs + ULPD_FREE_HEAD, x
                        sta ULPOOL_a_new_head       ; reuse as old_head
                        lda ULPOOL_descs + ULPD_FREE_HEAD + 1, x
                        sta ULPOOL_a_new_head+1

                        ; Access the freed item
                        lda ULPOOL_a_pool_type
                        ldx ULPOOL_a_handle
                        ldy ULPOOL_a_handle+1
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Set refcount = 0
                        ldy #0
                        lda #0
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y

                        ; Set next = old free_head
                        iny                     ; y=2
                        lda ULPOOL_a_new_head
                        sta (UL_varptr),y
                        iny                     ; y=3
                        lda ULPOOL_a_new_head+1
                        sta (UL_varptr),y

                        ; Set prev = $FFFF
                        iny                     ; y=4
                        lda #$FF
                        sta (UL_varptr),y
                        iny                     ; y=5
                        sta (UL_varptr),y

                        ; If old_head != $FFFF, set old_head.prev = freed handle
                        lda ULPOOL_a_new_head
                        and ULPOOL_a_new_head+1
                        cmp #$FF
                        beq @update_desc

                        lda ULPOOL_a_pool_type
                        ldx ULPOOL_a_new_head
                        ldy ULPOOL_a_new_head+1
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1
                        ldy #4                  ; prev offset
                        lda ULPOOL_a_handle
                        sta (UL_varptr),y
                        iny
                        lda ULPOOL_a_handle+1
                        sta (UL_varptr),y

@update_desc:           ldx ULPOOL_a_desc_off

                        ; free_head = freed handle
                        lda ULPOOL_a_handle
                        sta ULPOOL_descs + ULPD_FREE_HEAD, x
                        lda ULPOOL_a_handle+1
                        sta ULPOOL_descs + ULPD_FREE_HEAD + 1, x

                        ; Increment free_count
                        lda ULPOOL_descs + ULPD_FREE_COUNT, x
                        clc
                        adc #1
                        sta ULPOOL_descs + ULPD_FREE_COUNT, x
                        lda ULPOOL_descs + ULPD_FREE_COUNT + 1, x
                        adc #0
                        sta ULPOOL_descs + ULPD_FREE_COUNT + 1, x

                        rts
.endproc

; =============================================================================
; ULPOOL_init - Initialize all pool types, reserve banks from top of RAM
;   Called from ul_init before ULM_init
; =============================================================================
.proc ULPOOL_init
                        ; Save caller's bank
                        lda BANKSEL::RAM
                        pha

                        ; Read total banks
                        sec
                        jsr MEMTOP              ; A = total RAM banks

                        ; Determine allocation tier
                        cmp #65
                        bcs @check_medium

                        ; Small (<=64 banks): 1 DB + 1 BL + 1 MB = 3 banks
                        ldx #1
                        stx ULPOOL_i_db_banks
                        stx ULPOOL_i_bl_banks
                        stx ULPOOL_i_mb_banks
                        ldx #3
                        stx ULPOOL_i_reserved
                        bra @compute_bases

@check_medium:          cmp #129
                        bcs @large

                        ; Medium (65-128 banks): 2 DB + 1 BL + 2 MB = 5 banks
                        ldx #2
                        stx ULPOOL_i_db_banks
                        ldx #1
                        stx ULPOOL_i_bl_banks
                        ldx #2
                        stx ULPOOL_i_mb_banks
                        ldx #5
                        stx ULPOOL_i_reserved
                        bra @compute_bases

@large:                 ; Large (>=129 banks): 4 DB + 2 BL + 4 MB = 10 banks
                        ldx #4
                        stx ULPOOL_i_db_banks
                        ldx #2
                        stx ULPOOL_i_bl_banks
                        ldx #4
                        stx ULPOOL_i_mb_banks
                        ldx #10
                        stx ULPOOL_i_reserved

@compute_bases:         ; Pool banks reserved at top of RAM
                        ; Layout (top to bottom): MSGBLOCK, BLOCKLIST, DATABLOCK
                        sta ULPOOL_i_total      ; save total banks
                        sec
                        sbc ULPOOL_i_mb_banks
                        sta ULPOOL_i_mb_base
                        sec
                        sbc ULPOOL_i_bl_banks
                        sta ULPOOL_i_bl_base
                        sec
                        sbc ULPOOL_i_db_banks
                        sta ULPOOL_i_db_base

                        ; --- Set DATABLOCK descriptor (offset 0) ---
                        lda ULPOOL_i_db_base
                        sta ULPOOL_descs + 0 * ULPD_SIZE + ULPD_BASE_BANK
                        lda ULPOOL_i_db_banks
                        sta ULPOOL_descs + 0 * ULPD_SIZE + ULPD_NUM_BANKS
                        lda #10
                        sta ULPOOL_descs + 0 * ULPD_SIZE + ULPD_ITEMS_SHIFT
                        lda #3
                        sta ULPOOL_descs + 0 * ULPD_SIZE + ULPD_ADDR_SHIFT
                        ; free_head = 1 (index 0 reserved as null)
                        lda #1
                        sta ULPOOL_descs + 0 * ULPD_SIZE + ULPD_FREE_HEAD
                        stz ULPOOL_descs + 0 * ULPD_SIZE + ULPD_FREE_HEAD + 1
                        ; free_count = (num_banks * 1024) - 1
                        lda #$FF
                        sta ULPOOL_descs + 0 * ULPD_SIZE + ULPD_FREE_COUNT
                        lda ULPOOL_i_db_banks
                        asl
                        asl
                        dec                     ; -1 from high byte since lo=$FF
                        sta ULPOOL_descs + 0 * ULPD_SIZE + ULPD_FREE_COUNT + 1

                        ; --- Set BLOCKLIST descriptor (offset 8) ---
                        lda ULPOOL_i_bl_base
                        sta ULPOOL_descs + 1 * ULPD_SIZE + ULPD_BASE_BANK
                        lda ULPOOL_i_bl_banks
                        sta ULPOOL_descs + 1 * ULPD_SIZE + ULPD_NUM_BANKS
                        lda #10
                        sta ULPOOL_descs + 1 * ULPD_SIZE + ULPD_ITEMS_SHIFT
                        lda #3
                        sta ULPOOL_descs + 1 * ULPD_SIZE + ULPD_ADDR_SHIFT
                        lda #1
                        sta ULPOOL_descs + 1 * ULPD_SIZE + ULPD_FREE_HEAD
                        stz ULPOOL_descs + 1 * ULPD_SIZE + ULPD_FREE_HEAD + 1
                        lda #$FF
                        sta ULPOOL_descs + 1 * ULPD_SIZE + ULPD_FREE_COUNT
                        lda ULPOOL_i_bl_banks
                        asl
                        asl
                        dec
                        sta ULPOOL_descs + 1 * ULPD_SIZE + ULPD_FREE_COUNT + 1

                        ; --- Set MSGBLOCK descriptor (offset 16) ---
                        lda ULPOOL_i_mb_base
                        sta ULPOOL_descs + 2 * ULPD_SIZE + ULPD_BASE_BANK
                        lda ULPOOL_i_mb_banks
                        sta ULPOOL_descs + 2 * ULPD_SIZE + ULPD_NUM_BANKS
                        lda #9
                        sta ULPOOL_descs + 2 * ULPD_SIZE + ULPD_ITEMS_SHIFT
                        lda #4
                        sta ULPOOL_descs + 2 * ULPD_SIZE + ULPD_ADDR_SHIFT
                        lda #1
                        sta ULPOOL_descs + 2 * ULPD_SIZE + ULPD_FREE_HEAD
                        stz ULPOOL_descs + 2 * ULPD_SIZE + ULPD_FREE_HEAD + 1
                        ; free_count = (num_banks * 512) - 1
                        lda #$FF
                        sta ULPOOL_descs + 2 * ULPD_SIZE + ULPD_FREE_COUNT
                        lda ULPOOL_i_mb_banks
                        asl
                        dec
                        sta ULPOOL_descs + 2 * ULPD_SIZE + ULPD_FREE_COUNT + 1

                        ; Adjust MEMTOP so ULM_init only sees non-pool banks
                        lda ULPOOL_i_total
                        sec
                        sbc ULPOOL_i_reserved
                        clc
                        jsr MEMTOP

                        ; Initialize free lists for each pool
                        lda #ULPOOL::DATABLOCK
                        jsr @init_pool

                        lda #ULPOOL::BLOCKLIST
                        jsr @init_pool

                        lda #ULPOOL::MSGBLOCK
                        jsr @init_pool

                        ; Restore caller's bank
                        pla
                        sta BANKSEL::RAM
                        rts

; -----------------------------------------------------------------------------
; @init_pool - Initialize all items in a pool as a linked free list
;   In: A = pool type
; -----------------------------------------------------------------------------
@init_pool:
                        ; Get descriptor
                        asl
                        asl
                        asl
                        tax

                        lda ULPOOL_descs + ULPD_BASE_BANK, x
                        sta ULPOOL_i_cur_bank
                        lda ULPOOL_descs + ULPD_NUM_BANKS, x
                        clc
                        adc ULPOOL_i_cur_bank
                        sta ULPOOL_i_end_bank

                        lda ULPOOL_descs + ULPD_ADDR_SHIFT, x
                        sta ULPOOL_i_addr_shift

                        ; Compute item_size = 1 << addr_shift
                        lda #1
                        ldx ULPOOL_i_addr_shift
@shift_size:            asl
                        dex
                        bne @shift_size
                        sta ULPOOL_i_item_size  ; 8 or 16

                        ; Compute items_per_bank (hi byte only, lo is always 0)
                        ; addr_shift=3 -> 1024 items -> hi=$04
                        ; addr_shift=4 -> 512 items -> hi=$02
                        lda ULPOOL_i_addr_shift
                        cmp #4
                        beq @ipb_512
                        lda #$04                ; 1024 items
                        bra :+
@ipb_512:               lda #$02                ; 512 items
:                       sta ULPOOL_i_ipb_hi

                        ; Get total item count from free_count (already computed)
                        ; (reloading desc offset since X was clobbered)
                        ; Actually, compute total = num_banks * items_per_bank
                        ; total_hi = num_banks * ipb_hi, total_lo = 0
                        ; But items_per_bank >= 512, so total is always a multiple of 256
                        ; total = ipb_hi * num_banks (as a 16-bit multiply, but since both fit
                        ; in 8 bits and result <= 10*1024 = $2800, it fits in 16 bits)
                        ; Actually total_lo = 0 always, total_hi = num_banks * ipb_hi
                        ; But num_banks * ipb_hi could overflow 8 bits (e.g., 4 * 4 = 16 = $10)
                        ; So total = {num_banks * ipb_hi, $00}
                        lda ULPOOL_i_cur_bank
                        sta ULPOOL_scratch+2    ; save base_bank
                        lda ULPOOL_i_end_bank
                        sec
                        sbc ULPOOL_i_cur_bank   ; = num_banks
                        ; Multiply by ipb_hi
                        ldx ULPOOL_i_ipb_hi
                        stx ULPOOL_scratch+3    ; ipb_hi
                        ; A = num_banks, X = ipb_hi
                        ; Result = A * X (8x8 unsigned multiply, result fits in 16 bits)
                        ; Simple: repeated addition
                        tay                     ; Y = num_banks
                        lda #0
                        sta ULPOOL_i_total_hi
:                       clc
                        adc ULPOOL_scratch+3    ; += ipb_hi
                        bcc :+
                        inc ULPOOL_i_total_hi
:                       dey
                        bne :--
                        ; Now: A = total_lo_of_hi, ULPOOL_i_total_hi = overflow
                        ; Actually total = {ULPOOL_i_total_hi : A : $00}
                        ; But we know total <= 4096*4 = 16384 = $4000, fits in 16 bits
                        ; total_hi = A, total_lo = 0
                        sta ULPOOL_i_total_hi
                        stz ULPOOL_i_total_lo

                        ; Start at index 1 (index 0 is reserved as null)
                        lda #1
                        sta ULPOOL_i_idx_lo
                        stz ULPOOL_i_idx_hi

                        ; Loop through each bank
                        lda ULPOOL_i_cur_bank
@bank_loop:             sta BANKSEL::RAM

                        ; Compute starting address for current index within this bank
                        ; For the first bank, skip item 0: start at item_size offset
                        ; For subsequent banks, start at $A000
                        lda #$00
                        sta UL_varptr
                        lda #$A0
                        sta UL_varptr+1

                        ; Items remaining in this bank
                        stz ULPOOL_i_count_lo   ; always 0
                        lda ULPOOL_i_ipb_hi
                        sta ULPOOL_i_count_hi

                        ; On first bank, skip item 0
                        lda ULPOOL_i_cur_bank
                        cmp ULPOOL_scratch+2    ; base_bank (saved earlier)
                        bne @item_loop

                        ; First bank: advance pointer past item 0
                        lda ULPOOL_i_item_size
                        sta UL_varptr           ; addr = $A000 + item_size

                        ; Decrement count by 1 (one fewer item in first bank)
                        ; count is {count_hi, count_lo} = {ipb_hi, 0}
                        ; Subtract 1: $xx00 - 1 = $xxFF with borrow
                        lda #$FF
                        sta ULPOOL_i_count_lo
                        dec ULPOOL_i_count_hi

@item_loop:
                        ; Write refcount = 0
                        ldy #0
                        lda #0
                        sta (UL_varptr),y       ; refcount lo
                        iny
                        sta (UL_varptr),y       ; refcount hi

                        ; Compute next = current_index + 1
                        lda ULPOOL_i_idx_lo
                        clc
                        adc #1
                        sta ULPOOL_i_next_lo
                        lda ULPOOL_i_idx_hi
                        adc #0
                        sta ULPOOL_i_next_hi

                        ; If next == total, set next = $FFFF (end of pool)
                        lda ULPOOL_i_next_lo
                        cmp ULPOOL_i_total_lo
                        bne @next_ok
                        lda ULPOOL_i_next_hi
                        cmp ULPOOL_i_total_hi
                        bne @next_ok
                        lda #$FF
                        sta ULPOOL_i_next_lo
                        sta ULPOOL_i_next_hi

@next_ok:               ; Write next at offset 2
                        ldy #2
                        lda ULPOOL_i_next_lo
                        sta (UL_varptr),y
                        iny
                        lda ULPOOL_i_next_hi
                        sta (UL_varptr),y

                        ; Compute prev: if index==0 then $FFFF, else index-1
                        lda ULPOOL_i_idx_lo
                        ora ULPOOL_i_idx_hi
                        bne @has_prev

                        ; First item: prev = $FFFF
                        ldy #4
                        lda #$FF
                        sta (UL_varptr),y
                        iny
                        sta (UL_varptr),y
                        bra @advance

@has_prev:              lda ULPOOL_i_idx_lo
                        sec
                        sbc #1
                        pha                     ; prev_lo
                        lda ULPOOL_i_idx_hi
                        sbc #0
                        ldy #5
                        sta (UL_varptr),y       ; prev_hi
                        pla
                        dey
                        sta (UL_varptr),y       ; prev_lo

@advance:               ; Advance index
                        inc ULPOOL_i_idx_lo
                        bne :+
                        inc ULPOOL_i_idx_hi
:
                        ; Advance pointer by item_size
                        lda UL_varptr
                        clc
                        adc ULPOOL_i_item_size
                        sta UL_varptr
                        bcc :+
                        inc UL_varptr+1
:
                        ; Decrement items-in-bank count (16-bit)
                        lda ULPOOL_i_count_lo
                        bne :+
                        dec ULPOOL_i_count_hi
:                       dec ULPOOL_i_count_lo

                        ; Check if count == 0
                        lda ULPOOL_i_count_lo
                        ora ULPOOL_i_count_hi
                        beq :+
                        jmp @item_loop
:
                        ; Next bank
                        inc ULPOOL_i_cur_bank
                        lda ULPOOL_i_cur_bank
                        cmp ULPOOL_i_end_bank
                        beq :+
                        jmp @bank_loop
:
                        rts
.endproc

; =============================================================================
; BSS
; =============================================================================

UL_BSS

; Pool descriptors: 3 pools x 8 bytes = 24 bytes
ULPOOL_descs:           .res 3 * ULPD_SIZE

; Scratch for ulpool_access (4 bytes)
ULPOOL_scratch:         .res 4

; Scratch for ulpool_alloc/free (6 bytes, non-overlapping with ULPOOL_scratch)
ULPOOL_a_pool_type:     .res 1
ULPOOL_a_desc_off:      .res 1
ULPOOL_a_handle:        .res 2
ULPOOL_a_new_head:      .res 2

; Scratch for ULPOOL_init (reusable after init completes)
ULPOOL_i_total:         .res 1
ULPOOL_i_reserved:      .res 1
ULPOOL_i_db_banks:      .res 1
ULPOOL_i_bl_banks:      .res 1
ULPOOL_i_mb_banks:      .res 1
ULPOOL_i_db_base:       .res 1
ULPOOL_i_bl_base:       .res 1
ULPOOL_i_mb_base:       .res 1
ULPOOL_i_cur_bank:      .res 1
ULPOOL_i_end_bank:      .res 1
ULPOOL_i_addr_shift:    .res 1
ULPOOL_i_item_size:     .res 1
ULPOOL_i_ipb_hi:        .res 1
ULPOOL_i_total_lo:      .res 1
ULPOOL_i_total_hi:      .res 1
ULPOOL_i_idx_lo:        .res 1
ULPOOL_i_idx_hi:        .res 1
ULPOOL_i_count_lo:      .res 1
ULPOOL_i_count_hi:      .res 1
ULPOOL_i_next_lo:       .res 1
ULPOOL_i_next_hi:       .res 1
