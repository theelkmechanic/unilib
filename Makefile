#
# Makefile for UniLib library and test application
#

EMU ?= $(HOME)/dev/x16/x16-emulator/build/x16emu

SRCDIR = ./src
OBJDIR = ./obj
LIBRARY = libunilib.a
TESTAPP = ULTEST.PRG
CONFIGFILE = cx16-asm.cfg

FLAGS = -t cx16 --cpu 65c02 -g

CORE_OBJS = \
	$(OBJDIR)/ul_init.o \
	$(OBJDIR)/ul_geterror.o \
	$(OBJDIR)/ul_isprint.o \
	$(OBJDIR)/UL_core.o

FILE_OBJS = \
	$(OBJDIR)/ULF_readblock.o

FONT_OBJS = \
	$(OBJDIR)/ULFT_findcharinfo.o \

ITER_OBJS = \
	$(OBJDIR)/ULI_core.o \
	$(OBJDIR)/ULI_list.o \
	$(OBJDIR)/ULI_string.o \
	$(OBJDIR)/ULI_utf8.o \
	$(OBJDIR)/ulitr.o

MATH_OBJS = \
	$(OBJDIR)/ulmath_idiv.o \
	$(OBJDIR)/ulmath_imul.o \
	$(OBJDIR)/ulmath_signed.o

MEM_OBJS = \
	$(OBJDIR)/ulmem.o \
	$(OBJDIR)/ulpool.o \
	$(OBJDIR)/uldb.o \
	$(OBJDIR)/ullist.o

STR_OBJS = \
	$(OBJDIR)/ULS_access.o \
	$(OBJDIR)/ULS_utils.o \
	$(OBJDIR)/ulstr_fromUtf8.o \
	$(OBJDIR)/ulstr_getlen.o \
	$(OBJDIR)/ulstr_release.o \
	$(OBJDIR)/ulstr_compare.o \
	$(OBJDIR)/ulstr_find.o \
	$(OBJDIR)/ulstr_rfind.o \
	$(OBJDIR)/ulstr_append.o \
	$(OBJDIR)/ulstr_mid.o \
	$(OBJDIR)/ulstr_toUtf8.o \
	$(OBJDIR)/ulstr_fromPETSCII.o \
	$(OBJDIR)/ulstr_fromISO8859.o \
	$(OBJDIR)/ulstr_toPETSCII.o \
	$(OBJDIR)/ulstr_toISO8859.o \
	$(OBJDIR)/ulstr_format.o

STBL_OBJS = \
	$(OBJDIR)/ulstb.o

VERA_OBJS = \
	$(OBJDIR)/ULV_blt.o \
	$(OBJDIR)/ULV_copy.o \
	$(OBJDIR)/ULV_fill.o \
	$(OBJDIR)/ULV_glyphcolor.o \
	$(OBJDIR)/ULV_setpaletteentry.o \
	$(OBJDIR)/ULV_swap.o

WIN_OBJS = \
	$(OBJDIR)/ULW_map.o \
	$(OBJDIR)/ULW_utils.o \
	$(OBJDIR)/ulwin_box.o \
	$(OBJDIR)/ulwin_busy.o \
	$(OBJDIR)/ulwin_clear.o \
	$(OBJDIR)/ulwin_close.o \
	$(OBJDIR)/ulwin_csredit.o \
	$(OBJDIR)/ulwin_error.o \
	$(OBJDIR)/ulwin_flash.o \
	$(OBJDIR)/ulwin_flashwait.o \
	$(OBJDIR)/ulwin_getcolor.o \
	$(OBJDIR)/ulwin_gethit.o \
	$(OBJDIR)/ulwin_getkey.o \
	$(OBJDIR)/ulwin_getstr.o \
	$(OBJDIR)/ulwin_getwin.o \
	$(OBJDIR)/ulwin_getwinfields.o \
	$(OBJDIR)/ulwin_idlecfg.o \
	$(OBJDIR)/ulwin_move.o \
	$(OBJDIR)/ulwin_open.o \
	$(OBJDIR)/ulwin_putchar.o \
	$(OBJDIR)/ulwin_putcolor.o \
	$(OBJDIR)/ulwin_putcursor.o \
	$(OBJDIR)/ulwin_putloc.o \
	$(OBJDIR)/ulwin_puttitle.o \
	$(OBJDIR)/ulwin_refresh.o \
	$(OBJDIR)/ulwin_scroll.o \
	$(OBJDIR)/ulwin_select.o

OBJECTS = $(CORE_OBJS) $(FILE_OBJS) $(FONT_OBJS) $(ITER_OBJS) $(MATH_OBJS) $(MEM_OBJS) $(STR_OBJS) $(STBL_OBJS) $(VERA_OBJS) $(WIN_OBJS)

TEST_SOURCES = \
	test/ultest.s

HEADERS = \
	$(SRCDIR)/unilib_impl.inc \
	cbm_kernal.inc \
	cx16.inc \
	unilib.inc

all: $(TESTAPP)

$(TESTAPP): $(TEST_SOURCES) $(LIBRARY)
	cl65 $(FLAGS) --asm-include-dir . -C $(CONFIGFILE) -m ultest.map -Ln ultest.sym -o $@ $^

$(LIBRARY): $(OBJECTS)
	ar65 r $@ $^

$(OBJDIR):
	mkdir -p $@

$(OBJDIR)/%.o: $(SRCDIR)/%.s $(HEADERS) | $(OBJDIR)
	ca65 $(FLAGS) -I. -I.. -o $@ $<

.PHONY: all clean test rom romtest
clean:
	-rm -r $(OBJDIR) $(ROM_OBJDIR)
	-rm $(LIBRARY)
	-rm $(TESTAPP) $(TEST_SOURCES:.s=.o) *.map *.sym
	-rm -f unilib_b0.bin unilib_b1.bin unilib_b2.bin .rom_stamp
	-rm -f $(ROMTESTAPP) run/$(ROMTESTAPP) run/rom_unilib.bin

test: $(TESTAPP)
	cp $(TESTAPP) run/
	X16EMU=$(EMU) python3 test/run_tests.py

# =============================================================================
# ROM build
# =============================================================================

ROM_CONFIGFILE = cx16-rom.cfg
ROM_OBJDIR = ./romobj
X16ROM_DIR = ../x16-rom
ROM_INC = -I. -I.. -I$(X16ROM_DIR)/inc -I$(X16ROM_DIR)/kernsup
ROM_FLAGS = $(FLAGS) -D ROM_BUILD

LZSA ?= ../lzsa/lzsa

# --- Bank A: Foundation + Data ---
# Jump table + jsrfar/KSUP + core, file, iter, math, mem, strings, strtbl
ROM_A_OBJS = \
	$(ROM_OBJDIR)/a/UL_jumptable_a.o \
	$(ROM_OBJDIR)/a/UL_ksup.o \
	$(ROM_OBJDIR)/a/ul_init.o \
	$(ROM_OBJDIR)/a/ul_geterror.o \
	$(ROM_OBJDIR)/a/ul_isprint.o \
	$(ROM_OBJDIR)/a/UL_core.o \
	$(ROM_OBJDIR)/a/ULF_readblock.o \
	$(ROM_OBJDIR)/a/ULI_core.o \
	$(ROM_OBJDIR)/a/ULI_list.o \
	$(ROM_OBJDIR)/a/ULI_string.o \
	$(ROM_OBJDIR)/a/ULI_utf8.o \
	$(ROM_OBJDIR)/a/ulitr.o \
	$(ROM_OBJDIR)/a/ulmath_idiv.o \
	$(ROM_OBJDIR)/a/ulmath_imul.o \
	$(ROM_OBJDIR)/a/ulmath_signed.o \
	$(ROM_OBJDIR)/a/ulmem.o \
	$(ROM_OBJDIR)/a/ulpool.o \
	$(ROM_OBJDIR)/a/uldb.o \
	$(ROM_OBJDIR)/a/ullist.o \
	$(ROM_OBJDIR)/a/ULS_access.o \
	$(ROM_OBJDIR)/a/ulstr_fromUtf8.o \
	$(ROM_OBJDIR)/a/ulstr_getlen.o \
	$(ROM_OBJDIR)/a/ulstr_release.o \
	$(ROM_OBJDIR)/a/ulstr_compare.o \
	$(ROM_OBJDIR)/a/ulstr_find.o \
	$(ROM_OBJDIR)/a/ulstr_rfind.o \
	$(ROM_OBJDIR)/a/ulstr_append.o \
	$(ROM_OBJDIR)/a/ulstr_mid.o \
	$(ROM_OBJDIR)/a/ulstr_toUtf8.o \
	$(ROM_OBJDIR)/a/ulstr_fromPETSCII.o \
	$(ROM_OBJDIR)/a/ulstr_fromISO8859.o \
	$(ROM_OBJDIR)/a/ulstr_toPETSCII.o \
	$(ROM_OBJDIR)/a/ulstr_toISO8859.o \
	$(ROM_OBJDIR)/a/ulstr_format.o \
	$(ROM_OBJDIR)/a/ulstb.o

# --- Bank B: Display ---
# Jump table + jsrfar/KSUP + font, VERA, window, ULS_utils
ROM_B_OBJS = \
	$(ROM_OBJDIR)/b/UL_jumptable_b.o \
	$(ROM_OBJDIR)/b/UL_ksup.o \
	$(ROM_OBJDIR)/b/ULFT_findcharinfo.o \
	$(ROM_OBJDIR)/b/ULS_utils.o \
	$(ROM_OBJDIR)/b/ULV_blt.o \
	$(ROM_OBJDIR)/b/ULV_copy.o \
	$(ROM_OBJDIR)/b/ULV_fill.o \
	$(ROM_OBJDIR)/b/ULV_glyphcolor.o \
	$(ROM_OBJDIR)/b/ULV_setpaletteentry.o \
	$(ROM_OBJDIR)/b/ULV_swap.o \
	$(ROM_OBJDIR)/b/ULW_map.o \
	$(ROM_OBJDIR)/b/ULW_utils.o \
	$(ROM_OBJDIR)/b/ulwin_box.o \
	$(ROM_OBJDIR)/b/ulwin_busy.o \
	$(ROM_OBJDIR)/b/ulwin_clear.o \
	$(ROM_OBJDIR)/b/ulwin_close.o \
	$(ROM_OBJDIR)/b/ulwin_csredit.o \
	$(ROM_OBJDIR)/b/ulwin_error.o \
	$(ROM_OBJDIR)/b/ulwin_flash.o \
	$(ROM_OBJDIR)/b/ulwin_flashwait.o \
	$(ROM_OBJDIR)/b/ulwin_getcolor.o \
	$(ROM_OBJDIR)/b/ulwin_gethit.o \
	$(ROM_OBJDIR)/b/ulwin_getkey.o \
	$(ROM_OBJDIR)/b/ulwin_getstr.o \
	$(ROM_OBJDIR)/b/ulwin_getwin.o \
	$(ROM_OBJDIR)/b/ulwin_getwinfields.o \
	$(ROM_OBJDIR)/b/ulwin_idlecfg.o \
	$(ROM_OBJDIR)/b/ulwin_move.o \
	$(ROM_OBJDIR)/b/ulwin_open.o \
	$(ROM_OBJDIR)/b/ulwin_putchar.o \
	$(ROM_OBJDIR)/b/ulwin_putcolor.o \
	$(ROM_OBJDIR)/b/ulwin_putcursor.o \
	$(ROM_OBJDIR)/b/ulwin_putloc.o \
	$(ROM_OBJDIR)/b/ulwin_puttitle.o \
	$(ROM_OBJDIR)/b/ulwin_refresh.o \
	$(ROM_OBJDIR)/b/ulwin_scroll.o \
	$(ROM_OBJDIR)/b/ulwin_select.o

# --- Bank C: Font data (LZSA2 compressed) ---
ROM_C_OBJS = \
	$(ROM_OBJDIR)/c/UL_fontdata.o

ROM_ALL_OBJS = $(ROM_A_OBJS) $(ROM_B_OBJS) $(ROM_C_OBJS)

# ROM object directories
$(ROM_OBJDIR)/a $(ROM_OBJDIR)/b $(ROM_OBJDIR)/c:
	mkdir -p $@

# Bank A compilation: -D ROM_BUILD -D BANK_A
$(ROM_OBJDIR)/a/%.o: $(SRCDIR)/%.s $(HEADERS) | $(ROM_OBJDIR)/a
	ca65 $(ROM_FLAGS) $(ROM_INC) -D BANK_A -o $@ $<

# Bank B compilation: -D ROM_BUILD -D BANK_B
$(ROM_OBJDIR)/b/%.o: $(SRCDIR)/%.s $(HEADERS) | $(ROM_OBJDIR)/b
	ca65 $(ROM_FLAGS) $(ROM_INC) -D BANK_B -o $@ $<

# Bank C compilation: -D ROM_BUILD (no bank define — uses explicit segment names)
$(ROM_OBJDIR)/c/%.o: $(SRCDIR)/%.s $(HEADERS) | $(ROM_OBJDIR)/c
	ca65 $(ROM_FLAGS) $(ROM_INC) -o $@ $<

# Font data depends on compressed font file
$(ROM_OBJDIR)/c/UL_fontdata.o: run/unilib.ulf.lzsa2

# Font compression (requires lzsa tool — build from https://github.com/emmanuel-marty/lzsa)
run/unilib.ulf.lzsa2: run/unilib.ulf
	$(LZSA) -r -f2 $< $@

# Link all three ROM banks in a single ld65 invocation
.rom_stamp: $(ROM_ALL_OBJS) $(ROM_CONFIGFILE)
	ld65 -C $(ROM_CONFIGFILE) -m unilib_rom.map -Ln unilib_rom.sym $(ROM_ALL_OBJS)
	touch $@

unilib_b0.bin unilib_b1.bin unilib_b2.bin: .rom_stamp

rom: unilib_b0.bin

# =============================================================================
# ROM test
# =============================================================================

ROMTESTAPP = ULTEST_ROM.PRG
ROM_IMAGE ?= $(dir $(EMU))rom.bin
CUSTOM_ROM = run/rom_unilib.bin

# Compile test with ROM_TEST flag (uses thunks instead of library)
$(ROM_OBJDIR)/ultest_rom.o: test/ultest.s $(HEADERS) | $(ROM_OBJDIR)/a
	ca65 $(FLAGS) -I. -D ROM_TEST -o $@ $<

# Compile thunks (provides jsrfar wrappers for all API functions)
$(ROM_OBJDIR)/unilib_thunks.o: unilib_thunks.s unilib_rom.inc | $(ROM_OBJDIR)/a
	ca65 $(FLAGS) -I. -o $@ $<

# Link ROM test app: test code + thunks + cx16 runtime (no library needed)
$(ROMTESTAPP): $(ROM_OBJDIR)/ultest_rom.o $(ROM_OBJDIR)/unilib_thunks.o
	cl65 $(FLAGS) -C $(CONFIGFILE) -m ultest_rom.map -Ln ultest_rom.sym -o $@ $^

# Build and run ROM tests: patch UniLib banks into ROM image, run test
romtest: rom $(ROMTESTAPP)
	cp $(ROMTESTAPP) run/
	cp $(ROM_IMAGE) $(CUSTOM_ROM)
	dd if=unilib_b0.bin of=$(CUSTOM_ROM) bs=16384 seek=16 conv=notrunc 2>/dev/null
	dd if=unilib_b1.bin of=$(CUSTOM_ROM) bs=16384 seek=17 conv=notrunc 2>/dev/null
	dd if=unilib_b2.bin of=$(CUSTOM_ROM) bs=16384 seek=18 conv=notrunc 2>/dev/null
	X16EMU=$(EMU) python3 test/run_tests.py --prg run/$(ROMTESTAPP) --sym ultest_rom.sym --rom $(CUSTOM_ROM)
