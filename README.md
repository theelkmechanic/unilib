# UniLib - A Unicode Windowing/Helper Library for the Commander X-16

So I wrote a Z-machine. And part of that Z-machine was a neat little character system that used an 80x30 layout with both layers and transparency to let me display actual Unicode characters and have way more than 256 different glyphs onscreen at once without resorting to bitmap graphics.

But there were limitations. No real way to deal well with different windows. No memory management at all; the Z-code file basically just got stored in the banked RAM and I couldn't really use it for anything else that I wanted to, like a real windowing system with buffers for each window that I can composite onto the screen, or file reading/writing (saving and loading games will require building and parsing Quetzal and Blorb files, for example). And the Z-code files can't be bigger than 512KB, so on a 2MB machine I was wasting a ton of useful memory.

This library hopes to fix that. It includes functions for things like:
* Windowing -- Lets you create up to 64 windows (the screen counts as one of those) that you can put text in, scroll, insert/delete lines/columns, do keyboard input, etc. Eventually things like window objects/menus, transcripts, macros, and keystroke recording/playback as well.
* Unicode and string manipulation -- The whole point was to be able to use lots of characters, so the windowing system all uses UTF-16 characters. I'll also want UTF-8 conversion, and possibly support for other character encodings.
* Memory management -- You can allocate chunks of memory from banked RAM and get a 16-bit "BRP" (banked RAM pointer) with a function that converts that into a 24-bit pointer when you need it. Blocks can be up to 7,936 bytes long. (The memory manager uses 256 bytes out of each page for management.)
* Containers -- Linked lists, B-trees, and the like.
* File handling -- Loading/saving files to/from the banked RAM memory system. Eventually parsing/generating different file formats like XML, JSON, etc. through file format filters, and the ability to implement custom filters (which I'll need for Quetzal and Blorb).
* Other I/O -- Maybe printing? Maybe serial? RS-232? RS-485? !0G Ethernet? Tin cans and a string? I don't know, we'll see what comes up.
* Math -- The KERNAL includes the C128 floating-point math routines, but I didn't see anything for integer math.

The library is bundled as a static library, so applications that use it only need to pull in the functionality they're using.

## Getting Started

### Prerequisites

You will need the following to build and play with UniLib:
* [cc65](https://cc65.github.io/) assembler
* GNU Make

### Building/Testing UniLib

Building should be as simple as running `make`. If you're developing on Windows 10, I can say that creating SD card images to test with is a pain unless you install Windows Subsystem for Linux 2 (which requires the Windows 10 2004 release). So it may be simpler to just develop/test on Linux or Mac instead.

To make a SD card image on Windows 10/11, I run the following little script with sudo in WSL 2 Debian:
```
#!/bin/sh
dd if=/dev/zero of=card.img bs=1M count=128
printf 'n\n\n\n\n\nt\nc\nw\n' | fdisk card.img
LOPNAM=`losetup -f`
losetup -o 1048576 $LOPNAM card.img
mkfs.fat -F 32 $LOPNAM
losetup -d $LOPNAM
mount -o rw,loop,offset=$((2048*512)) card.img card
cp ULTEST.PRG card
cp font/unilib.ulf card/UNILIB.ULF
cp tools/* card
umount card
```
That copies the test program I built with UniLib and the font file onto a 1GB SD card image that I can use in the emulator by running `../x16emu.exe -scale 2 -sdcard card.img -debug &`.

## License

The license for this code is non-existent. It's all hereby released into the public domain. Use it as you like. (Although why would you want to?)

## Acknowledgements

* Daniel Hotop, for suggesting using 2bpp text modes to increase the font size
* The people who wrote the math routines at https://codebase64.org/doku.php?id=base:6502_6510_maths for, well, the math routines. :)
