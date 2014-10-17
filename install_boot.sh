#!/bin/sh
#Program:
#	This program install boot sector to boot sector of Orange'S
#History: 10,16,2010
dd if=boot/hdboot.bin of=80m.img seek=`echo "obase=10;ibase=16;\`egrep -e '\<ROOT_BASE' boot/include/load.inc | sed -e 's/.*0x//g'\`*200" | bc` bs=1 count=446 conv=notrunc
dd if=boot/hdboot.bin of=80m.img seek=`echo "obase=10;ibase=16;\`egrep -e '\<ROOT_BASE' boot/include/load.inc | sed -e 's/.*0x//g'\`*200+1FE" | bc` skip=510 bs=1 count=2 conv=notrunc

