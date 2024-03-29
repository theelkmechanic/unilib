;
; Olli Savia <ops@iki.fi>
; Greg King
; Mike Ketchen - CX-16 r39 changes
;
; Commodore-compatibles Kernal functions
;

.if .def(__CX16__)
  ; CX16 extended jump table

  ; Floating-point math routines
  FP_AYINT                      := $FE00   ; convert floating point to integer
  FP_GIVAYF                     := $FE03   ; convert integer to floating point
  FP_FOUT                       := $FE06   ; convert floating point to ASCII string
  FP_VAL_1                      := $FE09   ; convert ASCII string to floating point (not implemented yet)
  FP_GETADR                     := $FE0C   ; convert floating point to an address
  FP_FLOATC                     := $FE0F   ; convert address to floating point
  FP_FSUB                       := $FE12   ; MEM - FACC
  FP_FSUBT                      := $FE15   ; ARG - FACC
  FP_FADD                       := $FE18   ; MEM + FACC
  FP_FADDT                      := $FE1B   ; ARG + FACC
  FP_FMULT                      := $FE1E   ; MEM * FACC
  FP_FMULTT                     := $FE21   ; ARG * FACC
  FP_FDIV                       := $FE24   ; MEM / FACC
  FP_FDIVT                      := $FE27   ; ARG / FACC
  FP_LOG                        := $FE2A   ; compute natural log of FACC
  FP_INT                        := $FE2D   ; perform BASIC INT() on FACC
  FP_SQR                        := $FE30   ; compute square root of FACC
  FP_NEGOP                      := $FE33   ; negate FACC
  FP_FPWR                       := $FE36   ; raise ARG to the MEM power
  FP_FPWRT                      := $FE39   ; raise ARG to the FACC power
  FP_EXP                        := $FE3C   ; compute EXP of FACC
  FP_COS                        := $FE3F   ; compute COS of FACC
  FP_SIN                        := $FE42   ; compute SIN of FACC
  FP_TAN                        := $FE45   ; compute TAN of FACC
  FP_ATN                        := $FE48   ; compute ATN of FACC
  FP_ROUND                      := $FE4B   ; round FACC
  FP_ABS                        := $FE4E   ; absolute value of FACC
  FP_SIGN                       := $FE51   ; test sign of FACC
  FP_FCOMP                      := $FE54   ; compare FACC with MEM
  FP_RND_0                      := $FE57   ; generate random floating point number
  FP_CONUPK                     := $FE5A   ; move RAM MEM to ARG
  FP_ROMUPK                     := $FE5D   ; move ROM MEM to ARG
  FP_MOVFRM                     := $FE60   ; move RAM MEM to FACC
  FP_MOVFM                      := $FE63   ; move ROM MEM to FACC
  FP_MOVMF                      := $FE66   ; move FACC to MEM
  FP_MOVFA                      := $FE69   ; move ARG to FACC
  FP_MOVAF                      := $FE6C   ; move FACC to ARG
  FP_FADDH                      := $FE81   ; FAC += .5
  FP_ZEROFC                     := $FE84   ; FAC = 0
  FP_NORMAL                     := $FE87   ; Normalize FAC
  FP_NEGFAC                     := $FE8A   ; FAC = -FAC
  FP_MUL10                      := $FE8D   ; FAC *= 10
  FP_DIV10                      := $FE90   ; FAC /= 10
  FP_MOVEF                      := $FE93   ; ARG = FAC
  FP_SGN                        := $FE96   ; FAC = sgn(FAC)
  FP_FLOAT                      := $FE99   ; FAC = (u8).A
  FP_FLOATS                     := $FE9C   ; FAC = (s16)facho+1:facho
  FP_QINT                       := $FE9F   ; facho:facho+1:facho+2:facho+2 = u32(FAC)
  FP_FINLOG                     := $FEA2   ; FAC += (s8).A
  FP_FOUTC                      := $FEA5   ; Convert FAC to ASCIIZ string at fbuffr - 1 + .Y

  ; Kernal routines
  KBDBUF_PEEK                   := $FEBD
  KBDBUF_GET_MODIFIERS          := $FEC0
  KBDBUF_PUT                    := $FEC3
  I2C_READ_BYTE                 := $FEC6
  I2C_WRITE_BYTE                := $FEC9
  ENTROPY_GET                   := $FECF
  CONSOLE_SET_PAGING_MESSAGE    := $FED5
  CONSOLE_PUT_IMAGE             := $FED8
  CONSOLE_INIT                  := $FEDB
  CONSOLE_PUT_CHAR              := $FEDE
  CONSOLE_GET_CHAR              := $FEE1
  MEMORY_FILL                   := $FEE4
  MEMORY_COPY                   := $FEE7
  MEMORY_CRC                    := $FEEA
  MEMORY_DECOMPRESS             := $FEED
  SPRITE_SET_IMAGE              := $FEF0
  SPRITE_SET_POSITION           := $FEF3
  FB_INIT                       := $FEF6
  FB_GET_INFO                   := $FEF9
  FB_SET_PALETTE                := $FEFC
  FB_CURSOR_POSITION            := $FEFF
  FB_CURSOR_NEXT_LINE           := $FF02
  FB_GET_PIXEL                  := $FF05
  FB_GET_PIXELS                 := $FF08
  FB_SET_PIXEL                  := $FF0B
  FB_SET_PIXELS                 := $FF0E
  FB_SET_8_PIXELS               := $FF11
  FB_SET_8_PIXELS_OPAQUE        := $FF14
  FB_FILL_PIXELS                := $FF17
  FB_FILTER_PIXELS              := $FF1A
  FB_MOVE_PIXELS                := $FF1D
  GRAPH_INIT                    := $FF20
  GRAPH_CLEAR                   := $FF23
  GRAPH_SET_WINDOW              := $FF26
  GRAPH_SET_COLORS              := $FF29
  GRAPH_DRAW_LINE               := $FF2C
  GRAPH_DRAW_RECT               := $FF2F
  GRAPH_MOVE_RECT               := $FF32
  GRAPH_DRAW_OVAL               := $FF35
  GRAPH_DRAW_IMAGE              := $FF38
  GRAPH_SET_FONT                := $FF3B
  GRAPH_GET_CHAR_SIZE           := $FF3E
  GRAPH_PUT_CHAR                := $FF41
  MACPTR                        := $FF44
  ENTER_BASIC                   := $FF47
  CLOCK_SET_DATE_TIME           := $FF4D
  CLOCK_GET_DATE_TIME           := $FF50
  JOYSTICK_SCAN                 := $FF53
  JOYSTICK_GET                  := $FF56
  SCREEN_MODE                   := $FF5F
  SCREEN_SET_CHARSET            := $FF62
  MOUSE_CONFIG                  := $FF68
  MOUSE_GET                     := $FF6B
  MOUSE_SCAN                    := $FF71
.endif

.if .def(__C128__)
  ; C128 extended jump table
  C64MODE      := $FF4D
  SWAPPER      := $FF5F
  SETBNK       := $FF68
.endif

.if .def(__C128__) || .def(__CX16__)
  ; Extended jump table
  CLSALL       := $FF4A
  LKUPLA       := $FF59
  LKUPSA       := $FF5C
  PFKEY        := $FF65
  JSRFAR       := $FF6E
  INDFET       := $FF74
  INDSTA       := $FF77
  INDCMP       := $FF7A
  PRIMM        := $FF7D
.endif

.if .def(__C64__) || .def(__C128__) || .def(__C16__) || .def(__CX16__)
  CINT         := $FF81
  IOINIT       := $FF84
  RAMTAS       := $FF87
.elseif .def(__VIC20__)
  CINT         := $E518         ; No entries are in the Kernal jump table of the VIC-20 for these three (3) functions.
  IOINIT       := $FDF9         ; The entries for these functions have been set to point directly to the functions
  RAMTAS       := $FD8D         ; in the Kernal, to maintain compatibility with the other Commodore platforms.
.elseif .def(__CBM510__) || .def(__CBM610__)
  IOINIT       := $FF7B
  CINT         := $FF7E
.endif

.if .def(__VIC20__) || .def(__C64__) || .def(__C128__) || .def(__C16__) || .def(__CX16__)
  RESTOR       := $FF8A
  VECTOR       := $FF8D
.elseif .def(__CBM510__) || .def(__CBM610__)
  VECTOR       := $FF84
  RESTOR       := $FF87
.endif

.if .def(__CBM510__) || .def(__CBM610__) || .def(__VIC20__) || .def(__C64__) || .def(__C128__) || .def(__C16__) || .def(__CX16__)
  SETMSG       := $FF90
  SECOND       := $FF93
  TKSA         := $FF96
  MEMTOP       := $FF99
  MEMBOT       := $FF9C
  SCNKEY       := $FF9F
  SETTMO       := $FFA2
  ACPTR        := $FFA5
  CIOUT        := $FFA8
  UNTLK        := $FFAB
  UNLSN        := $FFAE
  LISTEN       := $FFB1
  TALK         := $FFB4
  READST       := $FFB7
  SETLFS       := $FFBA
  SETNAM       := $FFBD
  OPEN         := $FFC0
  CLOSE        := $FFC3
.endif

; Available on all platforms including PET
CHKIN          := $FFC6
CKOUT          := $FFC9
CHKOUT         := $FFC9
CLRCH          := $FFCC
CLRCHN         := $FFCC
BASIN          := $FFCF
CHRIN          := $FFCF
BSOUT          := $FFD2
CHROUT         := $FFD2

.if .def(__CBM510__) || .def(__CBM610__) || .def(__VIC20__) || .def(__C64__) || .def(__C128__) || .def(__C16__) || .def(__CX16__)
  LOAD         := $FFD5
  SAVE         := $FFD8
  SETTIM       := $FFDB
  RDTIM        := $FFDE
.endif

; Available on all platforms including PET
STOP           := $FFE1
GETIN          := $FFE4
CLALL          := $FFE7
UDTIM          := $FFEA

.if .def(__CBM510__) || .def(__CBM610__) || .def(__VIC20__) || .def(__C64__) || .def(__C128__) || .def(__C16__) || .def(__CX16__)
  SCREEN       := $FFED
  PLOT         := $FFF0
  IOBASE       := $FFF3
.endif

; ---------------------------------------------------------------------------
; Kernal routines, direct entries
;
; Unlike the above, these are not standard functions with entries in the jump
; table. They do not exist in all Kernals, and where they do the entry point is
; specific to that particular machine and possibly even Kernal version.
;
; This list is not comprehensive: missing items for particular machines
; should be added as needed.
;
; UPDCRAMPTR: Updates the color RAM pointer to match the screen RAM pointer.
;

.if .def(__VIC20__)
  CLRSCR       := $E55F
  KBDREAD      := $E5CF
  UPDCRAMPTR   := $EAB2
.elseif .def(__C64__)
  CLRSCR       := $E544
  KBDREAD      := $E5B4
  NMIEXIT      := $FEBC
  UPDCRAMPTR   := $EA24
.elseif .def(__C128__)
  CLRSCR       := $C142
  KBDREAD      := $C006
  NMIEXIT      := $FF33
  NEWLINE      := $C363
  PRINT        := $C322
  CURS_SET     := $CD57
  CURS_ON      := $CD6F
  CURS_OFF     := $CD9F
.elseif .def(__C16__)
  CLRSCR       := $D88B
  KBDREAD      := $D8C1
.endif
