.include "unilib_impl.inc"

UL_CODE

; ulstb_create - Create a new stringtable
;   In: A               - Number of string slots (1-255)
;  Out: YX              - Stringtable BRP
;       carry           - Set on error
.proc ulstb_create
                        ; Save A (slot count) before register saves clobber it
                        sta ULSTB_saved_a

                        ; Save caller's r0 (KERNAL convention)
                        lda gREG::r0L
                        pha
                        lda gREG::r0H
                        pha

                        ; Restore A and save slot count
                        lda ULSTB_saved_a
                        pha

                        ; Compute allocation size: A*2 + 1 (max 511)
                        ldy #0
                        asl
                        bcc :+
                        iny
:                       tax
                        inx
                        bne :+
                        iny

                        ; Allocate and clear memory
:                       sec
                        jsr ulmem_alloc
                        bcs @fail

                        ; Save BRP to r0
                        stx gREG::r0L
                        sty gREG::r0H

                        ; Access the allocated memory
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Write slot count at byte 0
                        pla
                        sta (UL_varptr)

                        ; Return BRP in YX
                        ldx gREG::r0L
                        ldy gREG::r0H
                        ; Restore caller's r0 (carry/YX preserved)
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        clc
                        rts

@fail:                  pla                     ; discard saved slot count
                        ; Restore caller's r0
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        sec
                        rts
.endproc

; ulstb_delete - Delete a stringtable, releasing all contained strings
;   In: YX              - Stringtable BRP
.proc ulstb_delete
                        ; Save table BRP
                        stx ULSTB_tbl
                        sty ULSTB_tbl+1

                        ; Access the table
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Get slot count
                        lda (UL_varptr)
                        beq @free_table
                        sta ULSTB_count

                        ; Point past count byte to first slot
                        inc UL_varptr
                        bne :+
                        inc UL_varptr+1
:
                        stz ULSTB_idx

@loop:                  ; Save table bank and slot pointer (release clobbers both)
                        lda BANKSEL::RAM
                        pha
                        lda UL_varptr
                        sta ULSTB_slot
                        lda UL_varptr+1
                        sta ULSTB_slot+1

                        ; Read slot handle (check both bytes for zero)
                        ldy #0
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        stx UL_temp_l
                        ora UL_temp_l
                        beq @next

                        ; Release the string (YX = string handle)
                        lda (UL_varptr),y       ; reload hi byte
                        tay
                        jsr ulstr_release

@next:                  ; Restore table bank and slot pointer
                        pla
                        sta BANKSEL::RAM
                        lda ULSTB_slot
                        sta UL_varptr
                        lda ULSTB_slot+1
                        sta UL_varptr+1

                        ; Advance pointer by 2
                        lda UL_varptr
                        clc
                        adc #2
                        sta UL_varptr
                        bcc :+
                        inc UL_varptr+1
:
                        ; Next slot
                        inc ULSTB_idx
                        lda ULSTB_idx
                        cmp ULSTB_count
                        bcc @loop

@free_table:            ldx ULSTB_tbl
                        ldy ULSTB_tbl+1
                        jsr ulmem_free
                        rts
.endproc

; ulstb_get - Get a string from a stringtable
;   In: A               - String index (1-based)
;       r0              - Stringtable BRP
;  Out: YX              - String BRP
;       carry           - Set on error
.proc ulstb_get
                        ; Validate index != 0
                        cmp #0
                        beq @error
                        pha

                        ; Access the table
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Validate index <= slot count
                        pla
                        cmp (UL_varptr)
                        beq :+
                        bcs @error

                        ; Compute slot address: base + 1 + (index-1)*2
:                       dec
                        stz UL_temp_h
                        asl
                        bcc :+
                        inc UL_temp_h
:                       inc
                        bne :+
                        inc UL_temp_h
:                       clc
                        adc UL_varptr
                        sta UL_varptr
                        lda UL_temp_h
                        adc UL_varptr+1
                        sta UL_varptr+1

                        ; Read string BRP
                        ldy #0
                        lda (UL_varptr),y
                        tax
                        iny
                        lda (UL_varptr),y
                        tay
                        clc
                        rts

@error:                 lda #ULERR::INVALID_PARAMS
                        sta UL_lasterr
                        sec
                        rts
.endproc

; ulstb_put - Put a string into a stringtable
;   In: A               - String index (1-based)
;       YX              - String BRP
;       r0              - Stringtable BRP
;  Out: carry           - Set on error
.proc ulstb_put
                        ; Validate index != 0
                        cmp #0
                        bne :+
                        jmp @error
:
                        ; Save string BRP and index
                        stx ULSTB_str
                        sty ULSTB_str+1
                        pha

                        ; Access the table
                        ldx gREG::r0L
                        ldy gREG::r0H
                        jsr ulmem_access
                        stx UL_varptr
                        sty UL_varptr+1

                        ; Validate index <= slot count
                        pla
                        cmp (UL_varptr)
                        beq :+
                        bcs @error

                        ; Compute slot address: base + 1 + (index-1)*2
:                       dec
                        stz UL_temp_h
                        asl
                        bcc :+
                        inc UL_temp_h
:                       inc
                        bne :+
                        inc UL_temp_h
:                       clc
                        adc UL_varptr
                        sta UL_varptr
                        lda UL_temp_h
                        adc UL_varptr+1
                        sta UL_varptr+1

                        ; Read old handle from slot
                        ldy #0
                        lda (UL_varptr),y
                        sta ULSTB_old
                        iny
                        lda (UL_varptr),y
                        sta ULSTB_old+1

                        ; Save table bank and slot pointer (addref/release clobber both)
                        lda BANKSEL::RAM
                        pha
                        lda UL_varptr
                        sta ULSTB_slot
                        lda UL_varptr+1
                        sta ULSTB_slot+1

                        ; Addref new string first (if non-zero)
                        lda ULSTB_str
                        ora ULSTB_str+1
                        beq @write_slot
                        ldx ULSTB_str
                        ldy ULSTB_str+1
                        jsr ulstr_addref

@write_slot:            ; Restore table bank and slot pointer
                        pla
                        sta BANKSEL::RAM
                        lda ULSTB_slot
                        sta UL_varptr
                        lda ULSTB_slot+1
                        sta UL_varptr+1

                        ; Write new handle to slot
                        lda ULSTB_str
                        sta (UL_varptr)
                        ldy #1
                        lda ULSTB_str+1
                        sta (UL_varptr),y

                        ; Save table bank and slot pointer again for release
                        lda BANKSEL::RAM
                        pha

                        ; Release old string (if non-zero)
                        lda ULSTB_old
                        ora ULSTB_old+1
                        beq @put_done
                        ldx ULSTB_old
                        ldy ULSTB_old+1
                        jsr ulstr_release

@put_done:              pla
                        sta BANKSEL::RAM
                        clc
                        rts

@error:                 lda #ULERR::INVALID_PARAMS
                        sta UL_lasterr
                        sec
                        rts
.endproc

; ulstb_build - Build a stringtable from a list of NUL-terminated UTF-8 strings
;   In: YX              - Address of concatenated NUL-terminated strings (empty string = end)
;  Out: YX              - Stringtable BRP
;       carry           - Set on error
.proc ulstb_build
                        ; Save caller's r0 (KERNAL convention)
                        lda gREG::r0L
                        pha
                        lda gREG::r0H
                        pha

                        ; Save source address
                        stx ULSTB_src
                        sty ULSTB_src+1

                        ; --- First pass: count strings ---
                        stx UL_varptr
                        sty UL_varptr+1
                        stz ULSTB_count
                        ldy #0

@count_loop:            lda (UL_varptr),y
                        beq @count_done
                        inc ULSTB_count

                        ; Scan to NUL terminator
@cscan:                 iny
                        bne :+
                        inc UL_varptr+1
:                       lda (UL_varptr),y
                        bne @cscan

                        ; Advance past NUL
                        iny
                        bne @count_loop
                        inc UL_varptr+1
                        bra @count_loop

@count_done:            lda ULSTB_count
                        bne :+
                        jmp @error

                        ; --- Create stringtable ---
:                       jsr ulstb_create
                        bcc :+
                        jmp @error
:
                        stx ULSTB_tbl
                        sty ULSTB_tbl+1

                        ; --- Second pass: create strings and populate table ---
                        lda ULSTB_src
                        sta ULSTB_cur
                        lda ULSTB_src+1
                        sta ULSTB_cur+1
                        stz ULSTB_idx

@build_loop:            ; Create string from current position
                        ldx ULSTB_cur
                        ldy ULSTB_cur+1
                        jsr ulstr_fromUtf8
                        bcs @build_fail

                        ; Put string in table
                        stx ULSTB_str
                        sty ULSTB_str+1
                        lda ULSTB_tbl
                        sta gREG::r0L
                        lda ULSTB_tbl+1
                        sta gREG::r0H
                        inc ULSTB_idx
                        lda ULSTB_idx
                        ldx ULSTB_str
                        ldy ULSTB_str+1
                        jsr ulstb_put

                        ; Release the string to balance addref from put
                        ; (fromUtf8 created with refcount=1, put addref'd to 2, now back to 1)
                        ldx ULSTB_str
                        ldy ULSTB_str+1
                        jsr ulstr_release

                        ; Scan past current string to find next
                        lda ULSTB_cur
                        sta UL_varptr
                        lda ULSTB_cur+1
                        sta UL_varptr+1
                        ldy #0
@skip:                  lda (UL_varptr),y
                        beq @skip_done
                        iny
                        bne @skip
                        inc UL_varptr+1
                        bra @skip

@skip_done:             ; Advance past NUL, compute new absolute address
                        iny
                        bne :+
                        inc UL_varptr+1
:                       tya
                        clc
                        adc UL_varptr
                        sta ULSTB_cur
                        lda UL_varptr+1
                        adc #0
                        sta ULSTB_cur+1

                        ; Check if we've done all strings
                        lda ULSTB_idx
                        cmp ULSTB_count
                        bcc @build_loop

                        ; Success
                        ldx ULSTB_tbl
                        ldy ULSTB_tbl+1
                        ; Restore caller's r0
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        clc
                        rts

@build_fail:            ldx ULSTB_tbl
                        ldy ULSTB_tbl+1
                        jsr ulstb_delete
@error:                 ; Restore caller's r0
                        pla
                        sta gREG::r0H
                        pla
                        sta gREG::r0L
                        sec
                        rts
.endproc

; ulstb_load - Load strings from a file and build a stringtable
;   In: A               - Device number
;       YX              - Address of NUL-terminated filename
;  Out: YX              - Stringtable BRP
;       carry           - Set on error
.proc ulstb_load
                        ; Save device
                        pha

                        ; Get filename length (scan for NUL)
                        stx UL_varptr
                        sty UL_varptr+1
                        ldy #0
@fnlen:                 lda (UL_varptr),y
                        beq @fnlen_done
                        iny
                        bne @fnlen
@fnlen_done:            tya
                        ldx UL_varptr
                        ldy UL_varptr+1
                        jsr SETNAM

                        ; SETLFS: logical file 1, device, secondary 0
                        pla
                        tax
                        lda #1
                        ldy #0
                        jsr SETLFS

                        ; OPEN
                        jsr OPEN
                        bcs @error

                        ; CHKIN - set logical file 1 as input
                        ldx #1
                        jsr CHKIN
                        bcs @close_error

                        ; Read bytes into scratch buffer at UL_SCRATCH_BASE ($0600)
                        lda #<UL_SCRATCH_BASE
                        sta UL_varptr
                        lda #>UL_SCRATCH_BASE
                        sta UL_varptr+1
                        ldy #0

@read:                  jsr CHRIN
                        sta (UL_varptr),y
                        iny
                        bne :+
                        inc UL_varptr+1

                        ; Stop if we've reached $0800 (512 bytes max)
:                       lda UL_varptr+1
                        cmp #$08
                        bcs @read_done

                        ; Check KERNAL status for EOF/error
                        jsr READST
                        beq @read

@read_done:             ; Ensure double-NUL termination (NUL-terminate last string + empty string end marker)
                        lda #0
                        sta (UL_varptr),y
                        iny
                        bne :+
                        inc UL_varptr+1
:                       sta (UL_varptr),y

                        ; Close file
                        jsr CLRCHN
                        lda #1
                        jsr CLOSE

                        ; Build stringtable from scratch buffer
                        ldx #<UL_SCRATCH_BASE
                        ldy #>UL_SCRATCH_BASE
                        jmp ulstb_build

@close_error:           jsr CLRCHN
                        lda #1
                        jsr CLOSE
@error:                 lda #ULERR::LOAD_FAILED
                        sta UL_lasterr
                        sec
                        rts
.endproc

UL_BSS

ULSTB_tbl:              .res    2       ; table BRP (used by delete/build)
ULSTB_count:            .res    1       ; slot count (used by delete/build)
ULSTB_idx:              .res    1       ; loop index (used by delete/build)
ULSTB_str:              .res    2       ; temp string handle (used by put/build)
ULSTB_old:              .res    2       ; old string handle (used by put)
ULSTB_slot:             .res    2       ; slot pointer (used by put)
ULSTB_src:              .res    2       ; source address (used by build)
ULSTB_cur:              .res    2       ; current position (used by build)
ULSTB_saved_a:          .res    1       ; temp for preserving A across register saves (used by create)
