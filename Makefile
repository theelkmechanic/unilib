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
	$(OBJDIR)/ul_isprint.o

MATH_OBJS = \
	$(OBJDIR)/ulmath_idiv.o \
	$(OBJDIR)/ulmath_imul.o

MEM_OBJS = \
	$(OBJDIR)/ulmem.o

STR_OBJS = \
	$(OBJDIR)/ulstr_access.o \
	$(OBJDIR)/ulstr_fromUtf8.o \
	$(OBJDIR)/ulstr_getlen.o

WIN_OBJS = \
	$(OBJDIR)/ulwin_box.o \
	$(OBJDIR)/ulwin_busy.o \
	$(OBJDIR)/ulwin_changecolor.o \
	$(OBJDIR)/ulwin_clear.o \
	$(OBJDIR)/ulwin_close.o \
	$(OBJDIR)/ulwin_delchar.o \
	$(OBJDIR)/ulwin_delline.o \
	$(OBJDIR)/ulwin_eraseeol.o \
	$(OBJDIR)/ulwin_error.o \
	$(OBJDIR)/ulwin_errorcfg.o \
	$(OBJDIR)/ulwin_flash.o \
	$(OBJDIR)/ulwin_flashwait.o \
	$(OBJDIR)/ulwin_force.o \
	$(OBJDIR)/ulwin_getchar.o \
	$(OBJDIR)/ulwin_getcolor.o \
	$(OBJDIR)/ulwin_getcolumn.o \
	$(OBJDIR)/ulwin_getcursor.o \
	$(OBJDIR)/ulwin_gethit.o \
	$(OBJDIR)/ulwin_getkey.o \
	$(OBJDIR)/ulwin_getline.o \
	$(OBJDIR)/ulwin_getloc.o \
	$(OBJDIR)/ulwin_getsize.o \
	$(OBJDIR)/ulwin_getstr.o \
	$(OBJDIR)/ulwin_getwin.o \
	$(OBJDIR)/ulwin_idlecfg.o \
	$(OBJDIR)/ulwin_inschar.o \
	$(OBJDIR)/ulwin_insline.o \
	$(OBJDIR)/ulwin_move.o \
	$(OBJDIR)/ulwin_open.o \
	$(OBJDIR)/ulwin_putchar.o \
	$(OBJDIR)/ulwin_putcolor.o \
	$(OBJDIR)/ulwin_putcursor.o \
	$(OBJDIR)/ulwin_putloc.o \
	$(OBJDIR)/ulwin_putstr.o \
	$(OBJDIR)/ulwin_puttitle.o \
	$(OBJDIR)/ulwin_refresh.o \
	$(OBJDIR)/ulwin_scroll.o \
	$(OBJDIR)/ulwin_select.o

INTERNAL_OBJS = \
	$(OBJDIR)/ULF_readblock.o \
	$(OBJDIR)/ULFT_findcharinfo.o \
	$(OBJDIR)/ULS_utils.o \
	$(OBJDIR)/ULV_blt.o \
	$(OBJDIR)/ULV_copy.o \
	$(OBJDIR)/ULV_fill.o \
	$(OBJDIR)/ULV_glyphcolor.o \
	$(OBJDIR)/ULV_setpaletteentry.o \
	$(OBJDIR)/ULV_swap.o \
	$(OBJDIR)/ULW_map.o \
	$(OBJDIR)/ULW_utils.o

OBJECTS = $(CORE_OBJS) $(MATH_OBJS) $(MEM_OBJS) $(STR_OBJS) $(WIN_OBJS) $(INTERNAL_OBJS)

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
