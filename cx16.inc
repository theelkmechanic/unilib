;
; CX16 r40 definitions
;

; ---------------------------------------------------------------------------
; Constants

.enum COLOR
  BLACK         = $00
  WHITE
  RED
  CYAN
  VIOLET
  PURPLE        = VIOLET
  GREEN
  BLUE
  YELLOW
  ORANGE
  BROWN
  PINK
  LIGHTRED      = PINK
  GRAY1
  GRAY2
  LIGHTGREEN
  LIGHTBLUE
  GRAY3
.endenum

; Special characters
.enum CH
COLOR_SWAP      = $01
STOP            = $03
UNDERLINE
WHITE
BOLD
BELL
BACKSPACE
TAB
LINEFEED
ITALIC
OUTLINE
ENTER
FONT_LOWER
FONT_ISO
F9
CURS_DOWN
REVERSE
HOME
DEL
F10
F11
F12
SHIFT_TAB
RED             = $1C
CURS_RIGHT
GREEN
BLUE
LIRA            = $5C
ORANGE          = $81
RUN             = $83
HELP
F1
F3
F5
F7
F2
F4
F6
F8
SHIFT_ENTER
FONT_UPPER
FONT_PET
BLACK
CURS_UP
ATTR_CLEAR
SCRN_CLEAR
INS
BROWN
PINK
LIGHTRED        = PINK
GRAY1
GRAY2
LIGHTGREEN
LIGHTBLUE
GRAY3
PURPLE
VIOLET          = PURPLE
CURS_LEFT
YELLOW
CYAN
SHIFT_SPACE
LTEE            = $AB
LLCORNER        = $AD
URCORNER
ULCORNER        = $B0
BTEE
TTEE
RTEE
LRCORNER        = $BD
HLINE           = $C0
CROSS           = $DB
VLINE           = $DD
PI
.endenum

; ---------------------------------------------------------------------------
; Zero page

; GEOS and graphics pseudo-registers
.struct gREG
                .org    $02
  .union
  r0            .word
  .struct
  r0L           .byte
  r0H           .byte
  .endstruct
  .endunion
  .union
  r1            .word
  .struct
  r1L           .byte
  r1H           .byte
  .endstruct
  .endunion
  .union
  r2            .word
  .struct
  r2L           .byte
  r2H           .byte
  .endstruct
  .endunion
  .union
  r3            .word
  .struct
  r3L           .byte
  r3H           .byte
  .endstruct
  .endunion
  .union
  r4            .word
  .struct
  r4L           .byte
  r4H           .byte
  .endstruct
  .endunion
  .union
  r5            .word
  .struct
  r5L           .byte
  r5H           .byte
  .endstruct
  .endunion
  .union
  r6            .word
  .struct
  r6L           .byte
  r6H           .byte
  .endstruct
  .endunion
  .union
  r7            .word
  .struct
  r7L           .byte
  r7H           .byte
  .endstruct
  .endunion
  .union
  r8            .word
  .struct
  r8L           .byte
  r8H           .byte
  .endstruct
  .endunion
  .union
  r9            .word
  .struct
  r9L           .byte
  r9H           .byte
  .endstruct
  .endunion
  .union
  r10           .word
  .struct
  r10L          .byte
  r10H          .byte
  .endstruct
  .endunion
  .union
  r11           .word
  .struct
  r11L          .byte
  r11H          .byte
  .endstruct
  .endunion
  .union
  r12           .word
  .struct
  r12L          .byte
  r12H          .byte
  .endstruct
  .endunion
  .union
  r13           .word
  .struct
  r13L          .byte
  r13H          .byte
  .endstruct
  .endunion
  .union
  r14           .word
  .struct
  r14L          .byte
  r14H          .byte
  .endstruct
  .endunion
  .union
  r15           .word
  .struct
  r15L          .byte
  r15H          .byte
  .endstruct
  .endunion
.endstruct

; Kernal
KTMP2               := $80          ; 2 bytes for temporary storage
IMPARM              := $82          ; Pointer for PRIMM function
CKBTAB              := $84
SAL                 := $86
SAH                 := $87
EAL                 := $88
EAH                 := $89
FNADR               := $8A          ; Pointer to filename
MEMUSS              := $8C
CURINDEXTABLE       := $8E
KRN_PTR1            := $90
BANK_SAVE           := $92
FAT32_BUFPTR        := $93
FAT32_LFN_BUFPTR    := $95
FAT32_PTR           := $97
FAT32_PTR2          := $99

; FP math
INDEX1              := $A9
INDEX2              := $AB
RESHO               := $AD
RESMOH              := $AE
RESMO               := $AF
RESLO               := $B0
RESOV               := $B1
FDECPT              := $B2
TEMPF3              := $B4
TEMPF1              := $B9
TEMPF2              := $BE
DECCNT              := $BF
TENEXP              := $C0
ZP1                 := $C1
FAC                 := $C3
FACEXP              := $C3
ZP2                 := $C3
FACHO               := $C4
FACMOH              := $C5
FACMO               := $C6
FACLO               := $C7
FACSGN              := $C8
DEGREE              := $C9
ARGEXP              := $CA
ARGHO               := $CB
ARGMOH              := $CC
ARGMO               := $CD
ARGLO               := $CE
ARGSGN              := $CF
ARISGN              := $D0
FACOV               := $D1
FBUFPT              := $D2
POLYPT              := $D2

; BASIC
LINNUM              := $D4
TEMPST              := $D6
TXTTAB              := $DF
FRESPC              := $E1
INPPTR              := $E3
FORPNT              := $E5
CHRGET              := $E7
CHRGOT              := $ED
TXTPTR              := $EE          ; Pointer into BASIC source code
QNUM                := $F4
ZP3                 := $FF

; Page two

BASIC_BUF           := $0200        ; Location of command-line
BASIC_BUF_LEN       = 81            ; Maximum length of command-line

KVSWITCH_TMP1       := $0251
KVSWITCH_TMP2       := $0252
NIBCOUNT            := $0253
NIBBLES             := $0254
OFFSLO              := $0255
OFFSHI              := $0256
MEMSTR              := $0257
MEMSIZK             := $0259
RAMBKS              := $025B
C3P0                := $025C
BSOUR               := $025D
R2D2                := $025E
BSOUR1              := $025F
SCOUNT              := $0260
CSCRMD              := $0261        ; Current screen mode (set by SCREEN_SET_MODE)
PNT                 := $0262        ; Pointer to current row on text screen (16 bits)
PTR_FG              := $0264
ACTIVITY_LED_STATE  := $0267
COL1                := $0267
COL2                := $0268
COL_BG              := $0269
_CBDOS_FLAGS        := $026A
LAT                 := $026B
FAT                 := $0275
SAT                 := $027F
IEEE_STATUS         := $0289        ; Status from previous I/O operation
VERCKK              := $028A
XSAV                := $028B
LDTND               := $028C
DFLTN               := $028D        ; Current input device number
DFLTO               := $028E        ; Current output device number
MSGFLG              := $028F
T1                  := $0290
FNLEN               := $0291        ; Length of filename
LA                  := $0292
SA                  := $0293        ; Secondary address
FA                  := $0294        ; Device number
STAL                := $0295
STAH                := $0296
BASELINEOFFSET      := $0297
CURSETWIDTH         := $0298
CURHEIGHT           := $029A
CARDDATAPNTR        := $029B
CURRENTMODE         := $029D
WINDOWTOP           := $029E
WINDOWBOTTOM        := $02A0
LEFTMARGIN          := $02A2
RIGHTMARGIN         := $02A4
FONTTEMP1           := $02A6
FONTTEMP2           := $02AE
PRVCHARWIDTH        := $02B7
FONTTVAR1           := $02B8
FONTTVAR2           := $02B9
FONTTVAR3           := $02BB
FONTTVAR4           := $02BC
__KERNRAM_RUN__     := $02C4
JMPFR               := $02DF
I_FB_INIT           := $02E4
I_FB_GET_INFO       := $02E6
I_FB_SET_PALLETTE   := $02E8
I_FB_CURSOR_POSITION := $02EA
I_FB_CURSOR_NEXT_LINE := $02EC
I_FB_GET_PIXEL      := $02EE
I_FB_GET_PIXELS     := $02F0
I_FB_SET_PIXEL      := $02F2
I_FB_SET_PIXELS     := $02F4
I_FB_SET_8_PIXELS   := $02F6
I_FB_SET_8_PIXELS_OPAQUE := $02F8
I_FB_FILL_PIXELS    := $02FA
I_FB_FILTER_PIXELS  := $02FC
I_FB_MOVE_PIXELS    := $02FE
IERROR              := $0300
IMAIN               := $0302
ICRNCH              := $0304
IQPLOP              := $0306
IGONE               := $0308
IEVAL               := $030A
SAREG               := $030C
SXREG               := $030D
SYREG               := $030E
SPREG               := $030F
USRPOK              := $0310
CINV                := $0314
CBINV               := $0316
NMINV               := $0318
IOPEN               := $031A
ICLOSE              := $031C
ICHKIN              := $031E
ICKOUT              := $0320
ICLRCH              := $0322
IBASIN              := $0324
IBSOUT              := $0326
ISTOP               := $0328
IGETIN              := $032A
ICLALL              := $032C
KEYHDL              := $032E
ILOAD               := $0330
ISAVE               := $0332
LDTB1               := $0334
MODE                := $0372
GDCOL               := $0373        ; Color under the cursor
AUTODN              := $0374
LINTMP              := $0375
COLOR               := $0376        ; Cursor's color nybbles (high: background, low: foreground)
RVS                 := $0377        ; Reverse flag
INDX                := $0378
LSXP                := $0379
LSTP                := $037A
BLNSW               := $037B        ; 1 = cursor off
BLNCT               := $037C        ; Blink counter
GDBLN               := $037D        ; Character under the cursor
BLNON               := $037E        ; Cursor blink state
CRSW                := $037F
PNTR                := $0380
QTSW                := $0381
LNMX                := $0382
TBLX                := $0383
DATA                := $0384
INSRT               := $0385
LLEN                := $0386        ; Line length
NLINES              := $0387        ; Number of screen lines
NLINESP1            := $0388
NLINESM1            := $0389
VERBATIM            := $038A
__BANKED_IRQ        := $038B
ATL1                := $03A2
FETCH2              := $03A8
FETVEC              := $03AB
STASH0              := $03AF
STAVEC              := $03B2
CMPARE0             := $03B7

; BASIC
INTEGR              := $03CB
TANSGN              := $03CC
OLDOV               := $03CD
BITS                := $03CE
RNDX                := $03CF
ENDCHR              := $03D4
TRMPOS              := $03D5
VERCK               := $03D6
COUNT               := $03D7
DIMFLG              := $03D8
VALTYP              := $03D9
INTFLG              := $03DA
DORES               := $03DB
SUBFLG              := $03DC
INPFLG              := $03DD
CHANNL              := $03DE
TEMPPT              := $03DF
LASTPT              := $03E0
VARTAB              := $03E2        ; Pointer to start of BASIC variables
ARYTAB              := $03E4
STREND              := $03E6
FRETOP              := $03E8
MEMSIZ              := $03EA        ; Pointer to highest BASIC RAM location (+1)
CURLIN              := $03EC
OLDLIN              := $03EE
OLDTXT              := $03F0
DATLIN              := $03F2
DATPTR              := $03F4
VARNAM              := $03F6
OPPTR               := $03F8
OPMASK              := $03FA
FOUR6               := $03FB
JMPER               := $03FC
BASIC_FA            := $03FF

; ---------------------------------------------------------------------------
; I/O locations

; 65C22 #1
.struct VIA1                    ; Versatile Interface Adapter
        .org    $9F00
  PRB   .byte                   ; PS/2 mouse, I2C, Serial Bus (Port Register B)
  PRA   .byte                   ; PS/2 keyboard, NES controllers (Port Register A)
  DDRB  .byte                   ; (Data Direction Register B)
  DDRA  .byte                   ; (Data Direction Register A)
  T1    .word                   ; 60Hz timer interrupt (Timer 1)
  T1L   .word                   ; (Timer 1 Latch)
  T2    .word                   ; Serial Bus timing (Timer 2)
  SR    .byte                   ; (Shift Register)
  ACR   .byte                   ; (Auxiliary Control Register)
  PCR   .byte                   ; (Peripheral Control Register)
  IFR   .byte                   ; (Interrupt Flags Register)
  IER   .byte                   ; (Interrupt Enable Register)
  PRA2  .byte                   ; (Port Register A without handshaking)
.endstruct

; 65C22 #2 (unused)
.struct VIA2
        .org    $9F10
  PRB   .byte
  PRA   .byte
  DDRB  .byte
  DDRA  .byte
  T1    .word
  T1L   .word
  T2    .word
  SR    .byte
  ACR   .byte
  PCR   .byte
  IFR   .byte
  IER   .byte
  PRA2  .byte
.endstruct

; Video Enhanced Retro Adapter
; Has audio and SPI.
.scope  VERA

  ; External registers

  .struct
                .org    $9F20
  ADDR          .faraddr        ; Address for data port access
  DATA0         .byte           ; First data port
  DATA1         .byte           ; Second data port
  CTRL          .byte           ; Control register
  IRQ_EN        .byte           ; Interrupt enable bits
  IRQ_FLAGS     .byte           ; Interrupt flags
  IRQ_RASTER    .byte           ; Line where IRQ will occur
  .endstruct
  .enum                         ; Address automatic increment amounts
  DEC0          =       (($00 << 1) | $01) << 3
  DEC1          =       (($01 << 1) | $01) << 3
  DEC2          =       (($02 << 1) | $01) << 3
  DEC4          =       (($03 << 1) | $01) << 3
  DEC8          =       (($04 << 1) | $01) << 3
  DEC16         =       (($05 << 1) | $01) << 3
  DEC32         =       (($06 << 1) | $01) << 3
  DEC64         =       (($07 << 1) | $01) << 3
  DEC128        =       (($08 << 1) | $01) << 3
  DEC256        =       (($09 << 1) | $01) << 3
  DEC512        =       (($0A << 1) | $01) << 3
  DEC40         =       (($0B << 1) | $01) << 3
  DEC80         =       (($0C << 1) | $01) << 3
  DEC160        =       (($0D << 1) | $01) << 3
  DEC320        =       (($0E << 1) | $01) << 3
  DEC640        =       (($0F << 1) | $01) << 3
  INC0          =       (($00 << 1) | $00) << 3
  INC1          =       (($01 << 1) | $00) << 3
  INC2          =       (($02 << 1) | $00) << 3
  INC4          =       (($03 << 1) | $00) << 3
  INC8          =       (($04 << 1) | $00) << 3
  INC16         =       (($05 << 1) | $00) << 3
  INC32         =       (($06 << 1) | $00) << 3
  INC64         =       (($07 << 1) | $00) << 3
  INC128        =       (($08 << 1) | $00) << 3
  INC256        =       (($09 << 1) | $00) << 3
  INC512        =       (($0A << 1) | $00) << 3
  INC40         =       (($0B << 1) | $00) << 3
  INC80         =       (($0C << 1) | $00) << 3
  INC160        =       (($0D << 1) | $00) << 3
  INC320        =       (($0E << 1) | $00) << 3
  INC640        =       (($0F << 1) | $00) << 3
  .endenum
  .enum                         ; Interrupt request flags
  VERT_SYNC     =       %00000001
  RASTER_IRQ    =       %00000010
  SPR_COLLIDED  =       %00000100
  AUDIO_LOW     =       %00001000
  .endenum
  .scope        DISP            ; Display controller
    SELECT1     =       %00000010
    .union
                .org    $9F29
    .struct
    ; These four registers are visible when the DCSEL flag = %0
    VIDEO       .byte
    HSCALE      .byte
    VSCALE      .byte
    FRAME       .byte
    .endstruct
    .struct
    ; These four registers are visible when the DCSEL flag = %1
    HSTART      .byte
    HSTOP       .byte
    VSTART      .byte
    VSTOP       .byte
    .endstruct
    .endunion
    .enum       MODE            ; Output mode
      DISABLE   =       $00
      VGA
      NTSC
      RGB                       ; Interlaced, composite sync
    .endenum
    .enum       DISABLE
    COLOR       =       %00000100       ; NTSC monochrome
    .endenum
    .enum       ENABLE
      LAYER0    =       %00010000
      LAYER1    =       %00100000
      SPRITES   =       %01000000
    .endenum
  .endscope
  .struct       L0              ; Display layer 0
                .org    $9F2D
    CONFIG      .byte
    MAP_BASE    .byte
    TILE_BASE   .byte
    HSCROLL     .word
    VSCROLL     .word
  .endstruct
  .struct       L1              ; Display layer 1
                .org    $9F34
    CONFIG      .byte
    MAP_BASE    .byte
    TILE_BASE   .byte
    HSCROLL     .word
    VSCROLL     .word
  .endstruct
  .enum                         ; Layer display modes
  TILE1BPP      =       %00000000 | $00
  TILE2BPP
  TILE4BPP
  TILE8BPP
  T256C         =       %00001000
  BITMAP1BPP    =       %00000100 | $00
  BITMAP2BPP
  BITMAP4BPP
  BITMAP8BPP
  .endenum
  .enum         MAP             ; Map geometry
    WIDTH32     =       $00 << 4
    WIDTH64     =       $01 << 4
    WIDTH128    =       $02 << 4
    WIDTH256    =       $03 << 4
    HEIGHT32    =       $00 << 6
    HEIGHT64    =       $01 << 6
    HEIGHT128   =       $02 << 6
    HEIGHT256   =       $03 << 6
  .endenum
  .enum         TILE            ; Tile geometry
    WIDTH8      =       $00
    WIDTH16     =       $01
    WIDTH320    =       WIDTH8
    WIDTH640    =       WIDTH16
    HEIGHT8     =       $00 << 1
    HEIGHT16    =       $01 << 1
  .endenum
  .scope        PCM             ; Pulse-Code Modulator
    .struct
                .org    $9F3B
    CTRL        .byte
    RATE        .byte
    DATA        .byte
    .endstruct
    .enum
    STEREO      =       %00010000
    BITS16      =       %00100000
    RESET       =       %10000000
    .endenum
  .endscope
  .scope        SPI
    .struct
                .org    $9F3E
    DATA        .byte
    CTRL        .byte
    .endstruct
    .enum
    SELECT      =       %00000001
    SLOW        =       %00000010
    .endenum
  .endscope

  ; Internal RAM and registers

  .struct
                .org    $000000
  VRAM          .res    $020000 ; 128 Kibibytes
  .endstruct
  .scope        PSG             ; Programmable Sound Generator
    .struct
    PITCH       .word
    VOL         .byte           ; Left, right channels; volume
    WAVEFORM    .byte           ; Wave shape, pulse width
    .endstruct
    LEFT        =       %01 << 6
    RIGHT       =       %10 << 6
    .enum
    PULSE       =       $00 << 6
    SAWTOOTH    =       $01 << 6
    TRIANGLE    =       $02 << 6
    NOISE       =       $03 << 6
    .endenum
    .struct
                .org    $01F9C0
    VOICES      .res    $10 * 4
    .endstruct
  .endscope
  .struct
                .org    $01FA00
  PALETTE       .word   $0100
  .endstruct
  .scope        SPRITE
    .struct                     ; Sprite attributes
    ADDR        .addr           ; Address and color mode
    XX          .word           ; Co-ordinates
    YY          .word
    Z_FLIP      .byte           ; Collision mask, Z-depth, flip bits
    SIZE_PAL    .byte
    .endstruct
    .enum       FLIP
      NONE      =       %00000000
      HORIZ
      VERT
      BOTH
    .endenum
    .enum       DEPTH
      DISABLE   =       $00 << 2
      CANVAS    =       $01 << 2
      LAYER0    =       $02 << 2
      LAYER1    =       $03 << 2
    .endenum
    .enum                       ; Sprite geometry
    WIDTH8      =       $00 << 4
    WIDTH16     =       $01 << 4
    WIDTH32     =       $02 << 4
    WIDTH64     =       $03 << 4
    HEIGHT8     =       $00 << 6
    HEIGHT16    =       $01 << 6
    HEIGHT32    =       $02 << 6
    HEIGHT64    =       $03 << 6
    COLORS16    =       $00 << 7
    COLORS256   =       $01 << 7
    .endenum
  .endscope
  .struct
                .org    $01FC00
  SPRITES       .res    128 * 8
  .endstruct
.endscope

; YM2151
.struct YM2151                  ; Yamaha YM2151 audio controller
        .org    $9F40
  ADDR  .byte                   ; Address register (R = status, W = address)
  DATA  .byte                   ; Data register
.endstruct

; Real-Time Clock

; X16 Emulator device
; This device doesn't exist on the real machine.
.struct EMULATOR
                .org    $9FB0
  DEBUG         .byte           ; Boolean: debugging enabled
  VERALOG       .byte           ; Boolean: log VERA activity
  KEYBOARDLOG   .byte           ; Boolean: log keyboard data
  ECHO          .byte           ; Type of echo that's enabled
  SAVEXIT       .byte           ; Boolean: save on exit
  GIFREC        .byte           ; Method of recording GIF movie
                .org    $9FBD
  KEYMAP        .byte           ; Current keyboard layout number (Read-Only)
  DETECT        .byte   2       ; If is "16" string, then running on emulator (RO)
.endstruct

; ---------------------------------------------------------------------------
; Banked RAM and ROM

KEY_COUNT       := $A00A        ; (bank 0) Number of keys in input buffer
TIMER           := $A037        ; (bank 0) 60 Hz. timer (3 bytes, big-endian)

.struct BANK
        .org    $A000
  RAM   .res    $2000           ; 8 Kibibyte window into 512 Kibibytes or 2048 Kibibytes
  ROM   .res    $4000           ; 16 Kibibyte window into 512 Kibibytes
.endstruct

.struct BANKSEL
        .org    $00
  RAM   .res    1               ; Selects 8 Kibibyte window into 512 Kibibytes or 2048 Kibibytes
  ROM   .res    1               ; Selects 16 Kibibyte window into 512 Kibibytes
.endstruct

.enum ROM
  KERNAL        = 0             ; KERNAL operating system and drivers
  KEYBD                         ; Keyboard layout tables
  CBDOS                         ; The computer-based CBM-DOS for FAT32 SD cards
  GEOS                          ; GEOS KERNAL
  BASIC                         ; BASIC interpreter
  MONITOR                       ; Machine Language Monitor
  CHARSET                       ; PETSCII and ISO character sets (uploaded into VRAM)
  CODEX                         ; CodeX16 Interactive Assembly Environment / Monitor
.endenum
