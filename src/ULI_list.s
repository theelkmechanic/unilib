.include "unilib_impl.inc"

.code

; =============================================================================
; ULI_list_load_block - Load a block's data address and size
;   In: A = block index
;       ULI_list_scratch+2/+3 = list handle
;  Out: ULI_list_scratch+4..+6 = block data addr (lo, hi, bank)
;       ULI_list_scratch+7..+9 = block data end (lo, hi, bank)
; =============================================================================
.proc ULI_list_load_block
                        ; Get data block handle at index A
                        pha
                        lda ULI_list_scratch+2
                        sta gREG::r0L
                        lda ULI_list_scratch+3
                        sta gREG::r0H
                        pla
                        jsr ullist_getat        ; YX = data block handle

                        ; Save data block handle for size lookup
                        phx
                        phy

                        ; Get data BRP and access to get address
                        jsr uldb_getbrp         ; YX = data BRP
                        jsr ulmem_access        ; YX = address, bank set
                        stx ULI_list_scratch+4  ; addr_lo
                        sty ULI_list_scratch+5  ; addr_hi
                        lda BANKSEL::RAM
                        sta ULI_list_scratch+6  ; addr_bank

                        ; Restore data block handle, get size
                        ply
                        plx
                        jsr uldb_getsize        ; YX = size (NOT capacity!)

                        ; end = addr + size
                        txa
                        clc
                        adc ULI_list_scratch+4
                        sta ULI_list_scratch+7  ; end_lo
                        tya
                        adc ULI_list_scratch+5
                        sta ULI_list_scratch+8  ; end_hi
                        lda ULI_list_scratch+6
                        adc #0
                        sta ULI_list_scratch+9  ; end_bank
                        rts
.endproc

; =============================================================================
; ULI_list_create - Create a LIST iterator over a blocklist
;   In: ULI_scratch+0 = type_format
;       ULI_scratch+1/+2 = list handle (BRP)
;       Caller's bank on stack
;  Out: YX = iterator handle (BRP), carry set on error
; =============================================================================
.proc ULI_list_create
                        ; Get block count via ullist_getsize
                        ldx ULI_scratch+1
                        ldy ULI_scratch+2
                        jsr ullist_getsize      ; YX = size
                        cpx #0
                        bne @has_blocks
                        ; Empty list - fail
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

@has_blocks:            stx ULI_list_scratch+0  ; block_count (lo byte only)
                        ; Save list handle in list_scratch for ULI_list_load_block
                        lda ULI_scratch+1
                        sta ULI_list_scratch+2  ; list_handle lo
                        lda ULI_scratch+2
                        sta ULI_list_scratch+3  ; list_handle hi

                        ; --- Get first block (index 0) ---
                        lda #0
                        jsr ULI_list_load_block
                        ; Results: scratch+4..+6 = first_addr, +7..+9 = first_end

                        ; Save first block results to stack (6 bytes)
                        lda ULI_list_scratch+4  ; first_addr_lo
                        pha
                        lda ULI_list_scratch+5  ; first_addr_hi
                        pha
                        lda ULI_list_scratch+6  ; first_addr_bank
                        pha
                        lda ULI_list_scratch+7  ; first_end_lo
                        pha
                        lda ULI_list_scratch+8  ; first_end_hi
                        pha
                        lda ULI_list_scratch+9  ; first_end_bank
                        pha

                        ; --- Get last block ---
                        lda ULI_list_scratch+0  ; block_count
                        dec                     ; last index = count - 1
                        jsr ULI_list_load_block
                        ; Results: scratch+4..+6 = last_addr, +7..+9 = last_end

                        ; Move last block results to scratch+10..+15
                        lda ULI_list_scratch+4
                        sta ULI_list_scratch+10 ; last_addr_lo
                        lda ULI_list_scratch+5
                        sta ULI_list_scratch+11 ; last_addr_hi
                        lda ULI_list_scratch+6
                        sta ULI_list_scratch+12 ; last_addr_bank
                        lda ULI_list_scratch+7
                        sta ULI_list_scratch+13 ; last_end_lo
                        lda ULI_list_scratch+8
                        sta ULI_list_scratch+14 ; last_end_hi
                        lda ULI_list_scratch+9
                        sta ULI_list_scratch+15 ; last_end_bank

                        ; Restore first block results from stack to scratch+4..+9
                        pla
                        sta ULI_list_scratch+9  ; first_end_bank
                        pla
                        sta ULI_list_scratch+8  ; first_end_hi
                        pla
                        sta ULI_list_scratch+7  ; first_end_lo
                        pla
                        sta ULI_list_scratch+6  ; first_addr_bank
                        pla
                        sta ULI_list_scratch+5  ; first_addr_hi
                        pla
                        sta ULI_list_scratch+4  ; first_addr_lo

                        ; Now: scratch+4..+6 = first_addr, +7..+9 = first_end
                        ;      scratch+10..+12 = last_addr, +13..+15 = last_end

                        ; Check reverse flag
                        lda ULI_scratch         ; type_format
                        bpl :+
                        jmp @setup_reverse
:
                        ; --- FORWARD setup ---
                        ; Allocate 20-byte state
                        ldx #ULI_LIST_STATE_SIZE
                        ldy #0
                        sec                     ; clear memory
                        jsr ulmem_alloc
                        bcc @fwd_alloc_ok
                        jmp @fail

@fwd_alloc_ok:          phx
                        phy                     ; save iterator handle

                        jsr ulmem_access
                        stx ULI_ptr
                        sty ULI_ptr+1

                        ; type_format
                        lda ULI_scratch
                        sta (ULI_ptr)

                        ; cur = first_addr
                        ldy #ULI_STATE_CUR
                        lda ULI_list_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+5
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+6
                        sta (ULI_ptr),y

                        ; start = first_addr
                        ldy #ULI_STATE_START
                        lda ULI_list_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+5
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+6
                        sta (ULI_ptr),y

                        ; end = last_end
                        ldy #ULI_STATE_END
                        lda ULI_list_scratch+13
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+14
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+15
                        sta (ULI_ptr),y

                        ; list_handle
                        ldy #ULI_STATE_LIST_HANDLE
                        lda ULI_list_scratch+2
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+3
                        sta (ULI_ptr),y

                        ; block_index = 0
                        ldy #ULI_STATE_BLK_IDX
                        lda #0
                        sta (ULI_ptr),y

                        ; block_count
                        ldy #ULI_STATE_BLK_CNT
                        lda ULI_list_scratch+0
                        sta (ULI_ptr),y

                        ; blk_start = first_addr
                        ldy #ULI_STATE_BLK_START
                        lda ULI_list_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+5
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+6
                        sta (ULI_ptr),y

                        ; blk_end = first_end
                        ldy #ULI_STATE_BLK_END
                        lda ULI_list_scratch+7
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+8
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+9
                        sta (ULI_ptr),y

                        ; Return iterator handle
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts

@fail:                  pla
                        sta BANKSEL::RAM
                        sec
                        rts

                        ; --- REVERSE setup ---
@setup_reverse:         ; For reverse:
                        ;   start = last_end - step, end = first_addr - step
                        ;   cur = last_end - step
                        ;   blk_start = last_addr, blk_end = last_end
                        ;   block_index = block_count - 1

                        ; Get step size
                        lda ULI_scratch
                        jsr ULI_get_step
                        sta ULI_list_scratch+1  ; step

                        ; Allocate 20-byte state
                        ldx #ULI_LIST_STATE_SIZE
                        ldy #0
                        sec
                        jsr ulmem_alloc
                        bcc @rev_alloc_ok
                        bra @fail

@rev_alloc_ok:          phx
                        phy

                        jsr ulmem_access
                        stx ULI_ptr
                        sty ULI_ptr+1

                        ; type_format
                        lda ULI_scratch
                        sta (ULI_ptr)

                        ; cur = last_end - step
                        ldy #ULI_STATE_CUR
                        lda ULI_list_scratch+13 ; last_end_lo
                        sec
                        sbc ULI_list_scratch+1  ; step
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+14
                        sbc #0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+15
                        sbc #0
                        sta (ULI_ptr),y

                        ; start (for reverse) = last_end - step
                        ldy #ULI_STATE_START
                        lda ULI_list_scratch+13
                        sec
                        sbc ULI_list_scratch+1
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+14
                        sbc #0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+15
                        sbc #0
                        sta (ULI_ptr),y

                        ; end (for reverse) = first_addr - step
                        ldy #ULI_STATE_END
                        lda ULI_list_scratch+4  ; first_addr_lo
                        sec
                        sbc ULI_list_scratch+1  ; step
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+5
                        sbc #0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+6
                        sbc #0
                        sta (ULI_ptr),y

                        ; list_handle
                        ldy #ULI_STATE_LIST_HANDLE
                        lda ULI_list_scratch+2
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+3
                        sta (ULI_ptr),y

                        ; block_index = block_count - 1
                        ldy #ULI_STATE_BLK_IDX
                        lda ULI_list_scratch+0  ; block_count
                        dec
                        sta (ULI_ptr),y

                        ; block_count
                        ldy #ULI_STATE_BLK_CNT
                        lda ULI_list_scratch+0
                        sta (ULI_ptr),y

                        ; blk_start = last_addr
                        ldy #ULI_STATE_BLK_START
                        lda ULI_list_scratch+10
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+11
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+12
                        sta (ULI_ptr),y

                        ; blk_end = last_end
                        ldy #ULI_STATE_BLK_END
                        lda ULI_list_scratch+13
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+14
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+15
                        sta (ULI_ptr),y

                        ; Return iterator handle
                        ply
                        plx
                        pla
                        sta BANKSEL::RAM
                        clc
                        rts
.endproc

; =============================================================================
; ULI_list_boundary_check - Check and handle block boundary crossing
;   Called after ULI_step_forward/ULI_step_backward for LIST iterators.
;   Preserves: ULI_scratch[0..2], ULI_ptr, ULI_state_bank
;   In: ULI_cur/ULI_cur_bank = updated position
;       ULI_type_format = cached type_format
;       ULI_ptr = pointer to state, ULI_state_bank = state bank
; =============================================================================
.proc ULI_list_boundary_check
                        ; Switch to state bank to read block bounds
                        lda ULI_state_bank
                        sta BANKSEL::RAM

                        ; --- Check forward boundary: cur >= blk_end? ---
                        ; 3-byte unsigned compare: cur vs blk_end
                        ldy #ULI_STATE_BLK_END+2
                        lda ULI_cur_bank
                        cmp (ULI_ptr),y         ; compare bank
                        bcc @no_cross           ; cur_bank < blk_end_bank: no cross
                        bne @forward_cross      ; cur_bank > blk_end_bank: forward cross
                        ldy #ULI_STATE_BLK_END+1
                        lda ULI_cur+1
                        cmp (ULI_ptr),y         ; compare hi
                        bcc @no_cross
                        bne @forward_cross
                        ldy #ULI_STATE_BLK_END
                        lda ULI_cur
                        cmp (ULI_ptr),y         ; compare lo
                        bcs @forward_cross      ; cur >= blk_end
                        ; cur < blk_end: fall through to check backward

@no_cross:
                        ; --- Check backward boundary: cur < blk_start? ---
                        ldy #ULI_STATE_BLK_START+2
                        lda ULI_cur_bank
                        cmp (ULI_ptr),y         ; compare bank
                        bcs :+
                        jmp @backward_cross     ; cur_bank < blk_start_bank
:                       bne @done               ; cur_bank > blk_start_bank: no cross
                        ldy #ULI_STATE_BLK_START+1
                        lda ULI_cur+1
                        cmp (ULI_ptr),y         ; compare hi
                        bcs :+
                        jmp @backward_cross
:                       bne @done
                        ldy #ULI_STATE_BLK_START
                        lda ULI_cur
                        cmp (ULI_ptr),y         ; compare lo
                        bcs @done
                        jmp @backward_cross     ; cur < blk_start
@done:                  rts

                        ; --- Forward crossing ---
@forward_cross:
                        ; Check if we can cross forward: block_index + 1 < block_count
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        ldy #ULI_STATE_BLK_IDX
                        lda (ULI_ptr),y
                        clc
                        adc #1
                        ldy #ULI_STATE_BLK_CNT
                        cmp (ULI_ptr),y
                        bcc @do_forward         ; index+1 < count: can cross
                        rts                     ; at last block, let at_end catch it

@do_forward:
                        ; Save ULI_scratch[0..2] (fetched value + step/count)
                        lda ULI_scratch
                        pha
                        lda ULI_scratch+1
                        pha
                        lda ULI_scratch+2
                        pha

                        ; Read list_handle from state
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        ldy #ULI_STATE_LIST_HANDLE
                        lda (ULI_ptr),y
                        sta ULI_list_scratch+2
                        iny
                        lda (ULI_ptr),y
                        sta ULI_list_scratch+3

                        ; Get new block index
                        ldy #ULI_STATE_BLK_IDX
                        lda (ULI_ptr),y
                        clc
                        adc #1
                        pha                     ; save new index

                        ; Load new block data
                        jsr ULI_list_load_block ; scratch+4..9 = new block addr/end

                        ; Update state: switch to state bank
                        lda ULI_state_bank
                        sta BANKSEL::RAM

                        ; block_index = new index
                        pla                     ; new index
                        ldy #ULI_STATE_BLK_IDX
                        sta (ULI_ptr),y

                        ; cur = new block start
                        ldy #ULI_STATE_CUR
                        lda ULI_list_scratch+4
                        sta (ULI_ptr),y
                        sta ULI_cur
                        iny
                        lda ULI_list_scratch+5
                        sta (ULI_ptr),y
                        sta ULI_cur+1
                        iny
                        lda ULI_list_scratch+6
                        sta (ULI_ptr),y
                        sta ULI_cur_bank

                        ; blk_start = new block start
                        ldy #ULI_STATE_BLK_START
                        lda ULI_list_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+5
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+6
                        sta (ULI_ptr),y

                        ; blk_end = new block end
                        ldy #ULI_STATE_BLK_END
                        lda ULI_list_scratch+7
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+8
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+9
                        sta (ULI_ptr),y

                        ; Restore ULI_scratch
                        pla
                        sta ULI_scratch+2
                        pla
                        sta ULI_scratch+1
                        pla
                        sta ULI_scratch
                        rts

                        ; --- Backward crossing ---
@backward_cross:
                        ; Check if we can cross backward: block_index > 0
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        ldy #ULI_STATE_BLK_IDX
                        lda (ULI_ptr),y
                        bne :+
                        jmp @bk_done            ; at block 0, let at_start catch it
:
                        ; Save ULI_scratch[0..2]
                        lda ULI_scratch
                        pha
                        lda ULI_scratch+1
                        pha
                        lda ULI_scratch+2
                        pha

                        ; Read list_handle
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        ldy #ULI_STATE_LIST_HANDLE
                        lda (ULI_ptr),y
                        sta ULI_list_scratch+2
                        iny
                        lda (ULI_ptr),y
                        sta ULI_list_scratch+3

                        ; Get new block index = current - 1
                        ldy #ULI_STATE_BLK_IDX
                        lda (ULI_ptr),y
                        sec
                        sbc #1
                        pha                     ; save new index

                        ; Load new block data
                        jsr ULI_list_load_block

                        ; Get step size for computing cur = blk_end - step
                        lda ULI_type_format
                        jsr ULI_get_step
                        sta ULI_list_scratch+1  ; step

                        ; Update state
                        lda ULI_state_bank
                        sta BANKSEL::RAM

                        ; block_index = new index
                        pla
                        ldy #ULI_STATE_BLK_IDX
                        sta (ULI_ptr),y

                        ; cur = new block end - step
                        lda ULI_list_scratch+7  ; end_lo
                        sec
                        sbc ULI_list_scratch+1  ; step
                        ldy #ULI_STATE_CUR
                        sta (ULI_ptr),y
                        sta ULI_cur
                        lda ULI_list_scratch+8  ; end_hi
                        sbc #0
                        iny
                        sta (ULI_ptr),y
                        sta ULI_cur+1
                        lda ULI_list_scratch+9  ; end_bank
                        sbc #0
                        iny
                        sta (ULI_ptr),y
                        sta ULI_cur_bank

                        ; blk_start = new block start
                        ldy #ULI_STATE_BLK_START
                        lda ULI_list_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+5
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+6
                        sta (ULI_ptr),y

                        ; blk_end = new block end
                        ldy #ULI_STATE_BLK_END
                        lda ULI_list_scratch+7
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+8
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+9
                        sta (ULI_ptr),y

                        ; Restore ULI_scratch
                        pla
                        sta ULI_scratch+2
                        pla
                        sta ULI_scratch+1
                        pla
                        sta ULI_scratch
@bk_done:              rts
.endproc

; =============================================================================
; BSS
; =============================================================================

.bss

ULI_list_scratch:       .res 16
