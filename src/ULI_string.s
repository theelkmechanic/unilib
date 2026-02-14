.include "unilib_impl.inc"

UL_CODE

; =============================================================================
; ULI_string_create - Create a STRING iterator over a string handle
;   In: ULI_scratch+0 = type_format (must have ULIFMT::UTF8)
;       ULI_scratch+1/+2 = string handle (MB pool index)
;       Caller's bank on stack
;  Out: YX = iterator handle (BRP), carry set on error
; =============================================================================
.proc ULI_string_create
                        ; Reject non-UTF8 formats
                        lda ULI_scratch
                        and #$70
                        cmp #ULIFMT::UTF8
                        beq @format_ok
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

@format_ok:             ; Access string MB to read data_block, start, end
                        ldx ULI_scratch+1
                        ldy ULI_scratch+2
                        lda #ULPOOL::MSGBLOCK
                        jsr ulpool_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Read data_block handle
                        ldy #ULMSG_BLOCK::data_block
                        lda (UL_varptr),y
                        sta ULI_str_scratch+0   ; db handle lo
                        iny
                        lda (UL_varptr),y
                        sta ULI_str_scratch+1   ; db handle hi

                        ; Read start offset
                        ldy #ULMSG_BLOCK::start
                        lda (UL_varptr),y
                        sta ULI_str_scratch+2   ; start_off lo
                        iny
                        lda (UL_varptr),y
                        sta ULI_str_scratch+3   ; start_off hi

                        ; Read end offset
                        ldy #ULMSG_BLOCK::end
                        lda (UL_varptr),y
                        sta ULI_str_scratch+4   ; end_off lo
                        iny
                        lda (UL_varptr),y
                        sta ULI_str_scratch+5   ; end_off hi

                        ; Get data block BRP → base address
                        ldx ULI_str_scratch+0
                        ldy ULI_str_scratch+1
                        jsr uldb_getbrp         ; YX = data BRP
                        jsr ulmem_access        ; YX = base address, bank set
                        stx ULI_str_scratch+6   ; base_lo
                        sty ULI_str_scratch+7   ; base_hi
                        lda BANKSEL::RAM
                        sta ULI_str_scratch+8   ; base_bank

                        ; Compute data_start = base + start_offset
                        lda ULI_str_scratch+6
                        clc
                        adc ULI_str_scratch+2
                        sta ULI_str_scratch+2   ; start addr_lo
                        lda ULI_str_scratch+7
                        adc ULI_str_scratch+3
                        sta ULI_str_scratch+3   ; start addr_hi
                        lda ULI_str_scratch+8
                        adc #0
                        sta ULI_str_scratch+9   ; start addr_bank

                        ; Compute data_end = base + end_offset
                        lda ULI_str_scratch+6
                        clc
                        adc ULI_str_scratch+4
                        sta ULI_str_scratch+4   ; end addr_lo
                        lda ULI_str_scratch+7
                        adc ULI_str_scratch+5
                        sta ULI_str_scratch+5   ; end addr_hi
                        lda ULI_str_scratch+8
                        adc #0
                        sta ULI_str_scratch+10  ; end addr_bank

                        ; Check REVERSE flag
                        lda ULI_scratch
                        bpl @allocate

                        ; --- REVERSE+STRING: scan backward from data_end to find last char ---
                        lda ULI_str_scratch+4
                        sta ULI_cur
                        lda ULI_str_scratch+5
                        sta ULI_cur+1
                        lda ULI_str_scratch+10
                        sta ULI_cur_bank
                        lda ULI_scratch
                        sta ULI_type_format
                        jsr ULI_utf8_step_forward   ; REVERSE → phys_backward

                        ; ULI_cur now points at last char
                        ; Save reverse start (last char) for later
                        ; We'll store it in str_scratch+6/+7/+8 (reusing base fields)
                        lda ULI_cur
                        sta ULI_str_scratch+6   ; rev start_lo
                        lda ULI_cur+1
                        sta ULI_str_scratch+7   ; rev start_hi
                        lda ULI_cur_bank
                        sta ULI_str_scratch+8   ; rev start_bank

                        ; --- Allocate state (20 bytes, LIST-sized for extended fields) ---
@allocate:              ldx #ULI_LIST_STATE_SIZE
                        ldy #0
                        sec                     ; clear allocated memory
                        jsr ulmem_alloc
                        bcc @alloc_ok
                        pla
                        sta BANKSEL::RAM
                        sec
                        rts

@alloc_ok:              phx
                        phy
                        jsr ulmem_access
                        stx ULI_ptr
                        sty ULI_ptr+1

                        ; type_format
                        lda ULI_scratch
                        sta (ULI_ptr)

                        ; Dispatch forward vs reverse state init
                        bmi @write_reverse

                        ; --- Forward state ---
                        ; cur = start = data_start
                        ldy #ULI_STATE_CUR
                        lda ULI_str_scratch+2   ; start addr_lo
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+3   ; start addr_hi
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+9   ; start addr_bank
                        sta (ULI_ptr),y

                        ; start = data_start
                        ldy #ULI_STATE_START
                        lda ULI_str_scratch+2
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+3
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+9
                        sta (ULI_ptr),y

                        ; end = data_end
                        ldy #ULI_STATE_END
                        lda ULI_str_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+5
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+10
                        sta (ULI_ptr),y

                        ; blk_start = data_start, blk_end = data_end (same for single fragment)
                        ldy #ULI_STATE_BLK_START
                        lda ULI_str_scratch+2
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+3
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+9
                        sta (ULI_ptr),y

                        ldy #ULI_STATE_BLK_END
                        lda ULI_str_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+5
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+10
                        sta (ULI_ptr),y

                        bra @write_mb_fields

@write_reverse:         ; --- Reverse state ---
                        ; cur = start = last char position (in str_scratch+6/+7/+8)
                        ldy #ULI_STATE_CUR
                        lda ULI_str_scratch+6   ; rev start_lo
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+7   ; rev start_hi
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+8   ; rev start_bank
                        sta (ULI_ptr),y

                        ldy #ULI_STATE_START
                        lda ULI_str_scratch+6
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+7
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+8
                        sta (ULI_ptr),y

                        ; end = data_start - 1 (sentinel, one past last in reverse)
                        ldy #ULI_STATE_END
                        lda ULI_str_scratch+2
                        sec
                        sbc #1
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+3
                        sbc #0
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+9
                        sbc #0
                        sta (ULI_ptr),y

                        ; blk_start = data_start, blk_end = data_end (physical bounds)
                        ldy #ULI_STATE_BLK_START
                        lda ULI_str_scratch+2
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+3
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+9
                        sta (ULI_ptr),y

                        ldy #ULI_STATE_BLK_END
                        lda ULI_str_scratch+4
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+5
                        sta (ULI_ptr),y
                        iny
                        lda ULI_str_scratch+10
                        sta (ULI_ptr),y

@write_mb_fields:       ; --- MB fields (same for fwd/rev) ---
                        ; term_mb = cur_mb = string handle (single fragment)
                        ldy #ULI_STATE_TERM_MB
                        lda ULI_scratch+1       ; string handle lo
                        sta (ULI_ptr),y
                        iny
                        lda ULI_scratch+2       ; string handle hi
                        sta (ULI_ptr),y

                        ldy #ULI_STATE_CUR_MB
                        lda ULI_scratch+1
                        sta (ULI_ptr),y
                        iny
                        lda ULI_scratch+2
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
; ULI_string_boundary_check - Stub for cont chain boundary crossing
;   Currently a no-op (single-fragment strings only).
;   Will follow MB.cont when cont chains are implemented.
; =============================================================================
.proc ULI_string_boundary_check
                        rts
.endproc

UL_BSS
ULI_str_scratch:        .res 11         ; scratch for STRING create
