# UniLib - A Unicode Windowing/Helper Library for the Commander X-16

## Getting Started

### Prerequisites

You will need the following to build and play with UniLib:
* [cc65](https://cc65.github.io/) assembler
* GNU Make

### Building/Testing UniLib

Building should be as simple as running `make`. If you're developing on Windows 10, I can say that creating SD card images to test with is a pain unless you install Windows Subsystem for Linux 2 (which requires the Windows 10 2004 release). So it may be simpler to just develop/test on Linux or Mac instead.

To make a SD card test image on Windows 10, I use the following little script in WSL 2 Debian:
```
#!/bin/sh
dd if=/dev/zero of=card.img bs=1M count=1024
printf 'n\n\n\n\n\nt\nc\nw\n' | fdisk card.img
LOPNAM=`losetup -f`
sudo losetup -o 1048576 $LOPNAM card.img
sudo mkfs -t vfat $LOPNAM
sudo losetup -d $LOPNAM
sudo mount -o rw,loop,offset=$((2048*512)) card.img card
sudo cp unilib.cx16 card/UNILIB.PRG
sudo cp font/unilib.ulf card/UNILIB.ULF
sudo umount card
```
That copies the UniLib library and font files onto a 1GB SD card image that I can use in the emulator by running `../x16emu.exe -scale 2 -sdcard card.img -debug &`.

## License

The license for this code is non-existent. It's all hereby released into the public domain. Use it as you like. (Although why would you want to?)

## Acknowledgements

* Daniel Hotop, for suggesting using 2bpp text modes to increase the font size
