#
# Makefile for UniLib library and test application
#

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
	$(OBJDIR)/ulitr.o

MATH_OBJS = \
	$(OBJDIR)/ulmath_idiv.o \
	$(OBJDIR)/ulmath_imul.o \
	$(OBJDIR)/ulmath_signed.o

MEM_OBJS = \
	$(OBJDIR)/ulmem.o \
	$(OBJDIR)/uldb.o

STR_OBJS = \
	$(OBJDIR)/ULS_access.o \
	$(OBJDIR)/ULS_utils.o \
	$(OBJDIR)/ulstr_fromUtf8.o \
	$(OBJDIR)/ulstr_getlen.o

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

OBJECTS = $(CORE_OBJS) $(FILE_OBJS) $(FONT_OBJS) $(ITER_OBJS) $(MATH_OBJS) $(MEM_OBJS) $(STR_OBJS) $(VERA_OBJS) $(WIN_OBJS)

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

.PHONY: all clean
clean:
	-rm -r $(OBJDIR)
	-rm $(LIBRARY)
	-rm $(TESTAPP) $(TEST_SOURCES:.s=.o) *.map *.sym
