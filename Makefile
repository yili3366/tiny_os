
# This file is licensed under the GNU General Public License; either
# version 3 of the License, or (at your option) any later version. 
# Entry point of Oranges'S
# It must have the same value with 'KernelEntryPointPhyAddr'in load.inc!
ENTRYPOINT		= 0x1000
# Offset of entry point in kernel file
# It depends on ENTRYPOINT (linker and loader)
ENTRYOFFSET		= 0x400

AS			= as
LD			= ld
CC			= gcc
OBJCOPY			= objcopy
DASM			= objdump
ASBFLAGS		= -I boot/include/
ASKFLAGS		= -I include/ -I include/sys/
CFLAGS			= -I include/ -I include/sys/ -c -fno-builtin
TRIM_FLAGS		=-R .pdr -R .comment -R .note -S -O binary
DASMFLAGS		= -D

ORANGESBOOT		= boot/boot.bin boot/loader.bin
ORANGESKERNEL		= kernel.bin
OBJS			= kernel/kernel.o  kernel/start.o \
			  kernel/main.o kernel/clock.o kernel/keyboard.o \
			  kernel/tty.o kernel/console.o kernel/i8259.o \
			  kernel/global.o kernel/protect.o kernel/proc.o\
			  kernel/systask.o kernel/hd.o lib/printf.o lib/syscall.o\
			  lib/vsprintf.o lib/kliba.o lib/klib.o lib/string.o \
			  lib/misc.o lib/open.o lib/read.o lib/write.o lib/close.o \
			  lib/unlink.o lib/getpid.o lib/syslog.o lib/fork.o \
			  lib/exit.o lib/wait.o lib/stat.o lib/exec.o lib/lseek.o \
			  fs/main.o \
			  mm/main.o mm/forkexit.o mm/exec.o\
			  fs/open.o fs/misc.o fs/read_write.o fs/link.o fs/disklog.o

DASMOUNTPUT		= kernel.bin.asm

LDFILE_BOOT		= i386_boot.lds
LDFILE_DOS		= i386_dos.lds
LDFILE_KERNEL		= i386_kernel.lds
LDFLAGS_BOOT		= -T $(LDFILE_BOOT)
LDFLAGS_DOS		= -T $(LDFILE_DOS)
LDFLAGS_KERNEL		= -T $(LDFILE_KERNEL)

.PHONY: everything final image clean disasm all buildimg

everything: $(ORANGESBOOT) $(ORANGESKERNEL)

all: clean everything

final: all clean

image: final buildimg

#clean:
	rm -f $(OBJS)

clean:
	rm -fr *.bin *.elf */*.o */*.elf */*.bin 

disasm:
	$(DASM) $(DASMFLAGS) $(ORANGESKERNEL) > $(DASMOUNTPUT)

boot.img: 
	dd if=boot/boot.bin of=boot.img bs=512 count=1
	dd if=/dev/zero of=boot.img skip=1 seek=1 bs=512 count=2879

buildimg: boot.img
	@sudo mkdir -p /tmp/floppy; \
	sudo mount -o loop boot.img /tmp/floppy/; \
	sudo cp boot/loader.bin /tmp/floppy/; \
	sudo cp kernel.bin /tmp/floppy; \
	sudo umount /tmp/floppy/

boot/boot.bin: boot/boot.S boot/include/load.inc boot/include/fat12hdr.inc \
		boot/include/lib.inc boot/i386_boot.lds
	$(AS) $(ASBFLAGS) -o boot/boot.o $<
	$(LD) -Lboot boot/boot.o -s -o boot/boot.elf $(LDFLAGS_BOOT)
	$(OBJCOPY) $(TRIM_FLAGS) boot/boot.elf $@

boot/loader.bin: boot/loader.S boot/include/load.inc \
		  boot/include/fat12hdr.inc boot/include/pm.inc \
		  boot/include/lib.inc boot/i386_dos.lds
	$(AS) $(ASBFLAGS) -o boot/loader.o $<
	$(LD) -Lboot boot/loader.o -s -o boot/loader.elf $(LDFLAGS_DOS)
	$(OBJCOPY) $(TRIM_FLAGS) boot/loader.elf $@

kernel.bin: $(OBJS)
#	$(LD) $(OBJS)  -Ttext 0x1000 -s -o kernel.bin
#	$(OBJCOPY)  -R .pdr -R .comment -R.note kernel.elf $@

	$(LD) $(OBJS) -Map krnl.map -Lkernel -s -o $@ $(LDFLAGS_KERNEL)

#kernel/kernel.o: kernel/kernel.S include/sys/sconst.inc
#	$(AS) $(ASKFLAGS) -o $@ $<

#kernel/syscall.o: kernel/syscall.S include/sys/sconst.inc
#	$(AS) $(ASKFLAGS) -o $@ $<

kernel/kernel.o: kernel/kernel.S 
	$(AS) $(ASKFLAGS) -o $@ $<

kernel/start.o: kernel/start.c  
	$(CC) $(CFLAGS) -o $@ $<

kernel/main.o: kernel/main.c 
	$(CC) $(CFLAGS) -o $@ $<

kernel/clock.o: kernel/clock.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/keyboard.o: kernel/keyboard.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/tty.o: kernel/tty.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/console.o: kernel/console.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/i8259.o: kernel/i8259.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/global.o: kernel/global.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/protect.o: kernel/protect.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/proc.o: kernel/proc.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/systask.o: kernel/systask.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/hd.o: kernel/hd.c
	$(CC) $(CFLAGS) -o $@ $<

lib/printf.o: lib/printf.c
	$(CC) $(CFLAGS) -o $@ $<

lib/vsprintf.o: lib/vsprintf.c
	$(CC) $(CFLAGS) -o $@ $<

lib/klib.o: lib/klib.c
	$(CC) $(CFLAGS) -o $@ $<

lib/misc.o: lib/misc.c
	$(CC) $(CFLAGS) -o $@ $<

lib/kliba.o: lib/kliba.S
#	$(AS) $(ASKFLAGS) -o $@ $<
	$(AS) $(ASKFLAGS) -o lib/kliba.elf $<
	$(OBJCOPY)  -R .pdr -R .comment -R.note  lib/kliba.elf $@

lib/string.o: lib/string.S
#	$(AS) $(ASKFLAGS) -o $@ $<
	$(AS) $(ASKFLAGS) -o lib/string.elf $<
	$(OBJCOPY)  -R .pdr -R .comment -R.note  lib/string.elf $@

lib/syscall.o: lib/syscall.S
#	$(AS) $(ASKFLAGS) -o $@ $<
	$(AS) $(ASKFLAGS) -o lib/syscall.elf $<
	$(OBJCOPY)  -R .pdr -R .comment -R.note  lib/syscall.elf $@

lib/open.o: lib/open.c
	$(CC) $(CFLAGS) -o $@ $<

lib/read.o: lib/read.c
	$(CC) $(CFLAGS) -o $@ $<

lib/write.o: lib/write.c
	$(CC) $(CFLAGS) -o $@ $<

lib/close.o: lib/close.c
	$(CC) $(CFLAGS) -o $@ $<

lib/unlink.o: lib/unlink.c
	$(CC) $(CFLAGS) -o $@ $<

lib/getpid.o: lib/getpid.c
	$(CC) $(CFLAGS) -o $@ $<

lib/syslog.o: lib/syslog.c
	$(CC) $(CFLAGS) -o $@ $<

lib/fork.o: lib/fork.c
	$(CC) $(CFLAGS) -o $@ $<

lib/exit.o: lib/exit.c
	$(CC) $(CFLAGS) -o $@ $<

lib/wait.o: lib/wait.c
	$(CC) $(CFLAGS) -o $@ $<

lib/exec.o: lib/exec.c
	$(CC) $(CFLAGS) -o $@ $<

lib/stat.o: lib/stat.c
	$(CC) $(CFLAGS) -o $@ $<

lib/lseek.o: lib/lseek.c
	$(CC) $(CFLAGS) -o $@ $<

mm/main.o: mm/main.c
	$(CC) $(CFLAGS) -o $@ $<

mm/forkexit.o: mm/forkexit.c
	$(CC) $(CFLAGS) -o $@ $<

mm/exec.o: mm/exec.c
	$(CC) $(CFLAGS) -o $@ $<

fs/main.o: fs/main.c
	$(CC) $(CFLAGS) -o $@ $<

fs/open.o: fs/open.c
	$(CC) $(CFLAGS) -o $@ $<

fs/read_write.o: fs/read_write.c
	$(CC) $(CFLAGS) -o $@ $<

fs/link.o: fs/link.c
	$(CC) $(CFLAGS) -o $@ $<

fs/misc.o: fs/misc.c
	$(CC) $(CFLAGS) -o $@ $<

fs/disklog.o: fs/disklog.c
	$(CC) $(CFLAGS) -o $@ $<
