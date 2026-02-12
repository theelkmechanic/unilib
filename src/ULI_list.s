.include "unilib_impl.inc"

.code

; =============================================================================
; ULI_list_load_block - Load a message block's data address range
;   In: YX              - message block handle (pool index)
;  Out: ULI_list_scratch+4..+6 = block data start (lo, hi, bank)
;       ULI_list_scratch+7..+9 = block data end (lo, hi, bank)
;  Clobbers: ULI_list_scratch+10..+12 (temp base addr)
; =============================================================================
.proc ULI_list_load_block
                        ; Access message block to read fields
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Read data_block handle
                        ldy #ULMSG_BLOCK::data_block
                        lda (UL_varptr),y
                        sta ULI_list_scratch+4
                        iny
                        lda (UL_varptr),y
                        sta ULI_list_scratch+5

                        ; Read rd_ptr
                        ldy #ULMSG_BLOCK::rd_ptr
                        lda (UL_varptr),y
                        sta ULI_list_scratch+6
                        iny
                        lda (UL_varptr),y
                        sta ULI_list_scratch+7

                        ; Read wr_ptr
                        ldy #ULMSG_BLOCK::wr_ptr
                        lda (UL_varptr),y
                        sta ULI_list_scratch+8
                        iny
                        lda (UL_varptr),y
                        sta ULI_list_scratch+9

                        ; Get base address of data block's data
                        ldx ULI_list_scratch+4
                        ldy ULI_list_scratch+5
                        jsr uldb_getbrp         ; YX = data BRP
                        jsr ulmem_access        ; YX = base address, bank set

                        ; Save base address
                        stx ULI_list_scratch+10
                        sty ULI_list_scratch+11
                        lda BANKSEL::RAM
                        sta ULI_list_scratch+12

                        ; addr = base + rd_ptr
                        lda ULI_list_scratch+10
                        clc
                        adc ULI_list_scratch+6
                        sta ULI_list_scratch+4  ; addr_lo
                        lda ULI_list_scratch+11
                        adc ULI_list_scratch+7
                        sta ULI_list_scratch+5  ; addr_hi
                        lda ULI_list_scratch+12
                        adc #0
                        sta ULI_list_scratch+6  ; addr_bank

                        ; end = base + wr_ptr
                        lda ULI_list_scratch+10
                        clc
                        adc ULI_list_scratch+8
                        sta ULI_list_scratch+7  ; end_lo
                        lda ULI_list_scratch+11
                        adc ULI_list_scratch+9
                        sta ULI_list_scratch+8  ; end_hi
                        lda ULI_list_scratch+12
                        adc #0
                        sta ULI_list_scratch+9  ; end_bank
                        rts
.endproc

; =============================================================================
; ULI_list_create - Create a LIST iterator over a blocklist
;   In: ULI_scratch+0 = type_format
;       ULI_scratch+1/+2 = list handle (pool index)
;       Caller's bank on stack
;  Out: YX = iterator handle (BRP), carry set on error
; =============================================================================
.proc ULI_list_create
                        ; Check list is non-empty
                        ldx ULI_scratch+1
                        ldy ULI_scratch+2
                        jsr ullist_getsize      ; YX = size
                        cpx #0
                        bne @has_blocks
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

@has_blocks:            ; Access blocklist header to get head/tail MB handles
                        ldx ULI_scratch+1
                        ldy ULI_scratch+2
                        lda #ULPOOL::BLOCKLIST
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Read head MB handle
                        ldy #ULBLOCK_LIST::head
                        lda (UL_varptr),y
                        sta ULI_list_scratch+0  ; head_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULI_list_scratch+1  ; head_mb hi

                        ; Read tail MB handle
                        ldy #ULBLOCK_LIST::tail
                        lda (UL_varptr),y
                        sta ULI_list_scratch+2  ; tail_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULI_list_scratch+3  ; tail_mb hi

                        ; Load first block (head MB)
                        ldx ULI_list_scratch+0
                        ldy ULI_list_scratch+1
                        jsr ULI_list_load_block
                        ; Results: scratch+4..+6 = first addr, +7..+9 = first end

                        ; Save first block results to stack (6 bytes)
                        lda ULI_list_scratch+4
                        pha
                        lda ULI_list_scratch+5
                        pha
                        lda ULI_list_scratch+6
                        pha
                        lda ULI_list_scratch+7
                        pha
                        lda ULI_list_scratch+8
                        pha
                        lda ULI_list_scratch+9
                        pha

                        ; Load last block (tail MB)
                        ldx ULI_list_scratch+2
                        ldy ULI_list_scratch+3
                        jsr ULI_list_load_block
                        ; Results: scratch+4..+6 = last addr, +7..+9 = last end

                        ; Move last block results to scratch+10..+15
                        lda ULI_list_scratch+4
                        sta ULI_list_scratch+10
                        lda ULI_list_scratch+5
                        sta ULI_list_scratch+11
                        lda ULI_list_scratch+6
                        sta ULI_list_scratch+12
                        lda ULI_list_scratch+7
                        sta ULI_list_scratch+13
                        lda ULI_list_scratch+8
                        sta ULI_list_scratch+14
                        lda ULI_list_scratch+9
                        sta ULI_list_scratch+15

                        ; Restore first block results from stack
                        pla
                        sta ULI_list_scratch+9
                        pla
                        sta ULI_list_scratch+8
                        pla
                        sta ULI_list_scratch+7
                        pla
                        sta ULI_list_scratch+6
                        pla
                        sta ULI_list_scratch+5
                        pla
                        sta ULI_list_scratch+4

                        ; Now: +0/+1 = head_mb, +2/+3 = tail_mb
                        ;      +4..+6 = first_addr, +7..+9 = first_end
                        ;      +10..+12 = last_addr, +13..+15 = last_end

                        ; Check reverse flag
                        lda ULI_scratch
                        bpl :+
                        jmp @setup_reverse
:
                        ; --- FORWARD setup ---
                        ldx #ULI_LIST_STATE_SIZE
                        ldy #0
                        sec                     ; clear memory
                        jsr ulmem_alloc
                        bcc @fwd_alloc_ok
                        jmp @fail

@fwd_alloc_ok:          phx
                        phy

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

                        ; term_mb = tail (forward: terminal is last)
                        ldy #ULI_STATE_TERM_MB
                        lda ULI_list_scratch+2
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+3
                        sta (ULI_ptr),y

                        ; cur_mb = head (forward: start at first)
                        ldy #ULI_STATE_CUR_MB
                        lda ULI_list_scratch+0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+1
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
@setup_reverse:         lda ULI_scratch
                        jsr ULI_get_step
                        sta ULI_list_scratch+16 ; step

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
                        lda ULI_list_scratch+13
                        sec
                        sbc ULI_list_scratch+16
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+14
                        sbc #0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+15
                        sbc #0
                        sta (ULI_ptr),y

                        ; start = last_end - step
                        ldy #ULI_STATE_START
                        lda ULI_list_scratch+13
                        sec
                        sbc ULI_list_scratch+16
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+14
                        sbc #0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+15
                        sbc #0
                        sta (ULI_ptr),y

                        ; end = first_addr - step
                        ldy #ULI_STATE_END
                        lda ULI_list_scratch+4
                        sec
                        sbc ULI_list_scratch+16
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+5
                        sbc #0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+6
                        sbc #0
                        sta (ULI_ptr),y

                        ; term_mb = head (reverse: terminal is first)
                        ldy #ULI_STATE_TERM_MB
                        lda ULI_list_scratch+0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+1
                        sta (ULI_ptr),y

                        ; cur_mb = tail (reverse: start at last)
                        ldy #ULI_STATE_CUR_MB
                        lda ULI_list_scratch+2
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+3
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
                        ldy #ULI_STATE_BLK_END+2
                        lda ULI_cur_bank
                        cmp (ULI_ptr),y
                        bcc @no_cross
                        bne @forward_cross
                        ldy #ULI_STATE_BLK_END+1
                        lda ULI_cur+1
                        cmp (ULI_ptr),y
                        bcc @no_cross
                        bne @forward_cross
                        ldy #ULI_STATE_BLK_END
                        lda ULI_cur
                        cmp (ULI_ptr),y
                        bcs @forward_cross

@no_cross:
                        ; --- Check backward boundary: cur < blk_start? ---
                        ldy #ULI_STATE_BLK_START+2
                        lda ULI_cur_bank
                        cmp (ULI_ptr),y
                        bcs :+
                        jmp @backward_cross
:                       bne @done
                        ldy #ULI_STATE_BLK_START+1
                        lda ULI_cur+1
                        cmp (ULI_ptr),y
                        bcs :+
                        jmp @backward_cross
:                       bne @done
                        ldy #ULI_STATE_BLK_START
                        lda ULI_cur
                        cmp (ULI_ptr),y
                        bcs @done
                        jmp @backward_cross
@done:                  rts

                        ; --- Forward crossing ---
@forward_cross:
                        ; Read CUR_MB and check its next link
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        ldy #ULI_STATE_CUR_MB
                        lda (ULI_ptr),y
                        tax
                        iny
                        lda (ULI_ptr),y
                        tay                     ; YX = current MB handle

                        ; Access current MB to read next
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ldy #ULMSG_BLOCK::next
                        lda (UL_varptr),y
                        sta ULI_list_scratch+0  ; next_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULI_list_scratch+1  ; next_mb hi

                        ; Check if next == $FFFF (no next block)
                        lda ULI_list_scratch+0
                        and ULI_list_scratch+1
                        cmp #$FF
                        beq @fwd_no_cross       ; at last block
                        bra @do_forward

@fwd_no_cross:          rts

@do_forward:
                        ; Save ULI_scratch[0..2]
                        lda ULI_scratch
                        pha
                        lda ULI_scratch+1
                        pha
                        lda ULI_scratch+2
                        pha

                        ; Load new block data from next MB
                        ldx ULI_list_scratch+0
                        ldy ULI_list_scratch+1
                        jsr ULI_list_load_block

                        ; Update state
                        lda ULI_state_bank
                        sta BANKSEL::RAM

                        ; CUR_MB = next MB
                        ldy #ULI_STATE_CUR_MB
                        lda ULI_list_scratch+0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+1
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
                        ; Read CUR_MB and check its prev link
                        lda ULI_state_bank
                        sta BANKSEL::RAM
                        ldy #ULI_STATE_CUR_MB
                        lda (ULI_ptr),y
                        tax
                        iny
                        lda (ULI_ptr),y
                        tay                     ; YX = current MB handle

                        ; Access current MB to read prev
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ldy #ULMSG_BLOCK::prev
                        lda (UL_varptr),y
                        sta ULI_list_scratch+0  ; prev_mb lo
                        iny
                        lda (UL_varptr),y
                        sta ULI_list_scratch+1  ; prev_mb hi

                        ; Check if prev == $FFFF (no prev block)
                        lda ULI_list_scratch+0
                        and ULI_list_scratch+1
                        cmp #$FF
                        bne :+
                        jmp @bk_done            ; at first block
:

                        ; Save ULI_scratch[0..2]
                        lda ULI_scratch
                        pha
                        lda ULI_scratch+1
                        pha
                        lda ULI_scratch+2
                        pha

                        ; Load new block data from prev MB
                        ldx ULI_list_scratch+0
                        ldy ULI_list_scratch+1
                        jsr ULI_list_load_block

                        ; Get step size for computing cur = blk_end - step
                        lda ULI_type_format
                        jsr ULI_get_step
                        sta ULI_list_scratch+2  ; step

                        ; Update state
                        lda ULI_state_bank
                        sta BANKSEL::RAM

                        ; CUR_MB = prev MB
                        ldy #ULI_STATE_CUR_MB
                        lda ULI_list_scratch+0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_list_scratch+1
                        sta (ULI_ptr),y

                        ; cur = new block end - step
                        lda ULI_list_scratch+7
                        sec
                        sbc ULI_list_scratch+2
                        ldy #ULI_STATE_CUR
                        sta (ULI_ptr),y
                        sta ULI_cur
                        lda ULI_list_scratch+8
                        sbc #0
                        iny
                        sta (ULI_ptr),y
                        sta ULI_cur+1
                        lda ULI_list_scratch+9
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

ULI_list_scratch:       .res 17         ; 16 bytes + 1 for step during reverse create
