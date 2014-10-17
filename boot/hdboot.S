#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#			hdboot.S
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#					Mephisto 10,9,2010
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
.code16
	jmp	boot_start
.include "load.inc"

.set	STACK_BASE	,	0x7c00	#base address of stack when booting
.set	TRANS_SECT_NR	,	0x2
.set	SECT_BUF_SIZE	,	(TRANS_SECT_NR * 512)

disk_address_packet:	.byte	0x10	#[0] Packet size in bytes.
			.byte	0x0	#[1] Reserved must be 0.
			.byte	TRANS_SECT_NR	#[2] Nr of blocks to transfer.
			.byte	0x0	#[3] Reserved, must be 0.
			.word	0x0	#[4] Addr of transfer - Offset
			.word	SUPER_BLK_SEG	#[6] buffer.
			.long	0x0	#[8] LBA. Low 32-bits.
			.long	0x0	#[12] LBA. High 32-bits.


err:
	mov	$3, %dh		# "Error 0"
	call	disp_str	# display the string
	jmp	.

boot_start:
	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %ss
	mov	$(STACK_BASE), %sp

	call	clear_screen

	mov	$0x0, %dh	# "Booting"
	call	disp_str	# display the string

# read the super block to SUPER_BLK_SEG :: 0
	movl	$(ROOT_BASE + 1), (disk_address_packet + 8)
	call	read_sector
	mov	$(SUPER_BLK_SEG), %ax
	mov	%ax,%fs

	movl	$(LOADER_OFF), (disk_address_packet + 4)
	movl	$(LOADER_SEG), (disk_address_packet + 6)

# get the sector nr of '/' (ROOT_INODE), it'll be stored in eax
	mov	%fs:(SB_ROOT_INODE),%eax
	call	get_inode

# read '/' into ex:bx
	movl	%eax, (disk_address_packet + 8)
	call	read_sector

# let's search '/' for the loader
	mov	$(LoaderFileName), %si
	push	%bx
str_cmp:
# before comparation:
# es:bx -> dir_entry @ disk
# ds:si -> filename we want
	add	%fs:(SB_DIR_ENT_FNAME_OFF), %bx
1:
	lodsb			# ds:si -> al
	cmpb	%es:(%bx), %al
	jz	2f
	jmp	different	#oops
2:
	cmp	$0,%al
	jz	found
	inc	%bx		# next char at disk
	jmp	1b		# on and on
different:
	pop	%bx		# -> restore
	add	%fs:(SB_DIR_ENT_SIZE), %bx
	sub	%fs:(SB_DIR_ENT_SIZE), %ecx
	jz	not_found

	mov	$(SECT_BUF_SIZE), %dx
	cmp	%dx, %bx
	jge	not_found

	push	%bx
	mov	$(LoaderFileName),%si
	jmp	str_cmp
not_found:
	mov	$2,%dh
	call	disp_str
	jmp	.
found:
	pop	%bx
	add	%fs:(SB_DIR_ENT_INODE_OFF), %bx
	mov	%es:(%bx), %eax		# eax <- inode nr of loader
	call	get_inode		# eax <- start sector nr of loader
	movl	%eax, (disk_address_packet + 8)
load_loader:
	call	read_sector
	cmp	$(SECT_BUF_SIZE),%ecx
	jl	done
	sub	$(SECT_BUF_SIZE), %ecx	# bytes_left -= SECT_BUF_SIZE
	addw	$(SECT_BUF_SIZE), (disk_address_packet + 4)	# transfer buffer
	jc	err
	addl	$(TRANS_SECT_NR), (disk_address_packet + 8)	# LBA
	jmp	load_loader
done:
	mov	$0x1,%dh
	call	disp_str
	ljmp	$(LOADER_SEG),$(LOADER_OFF)
	jmp	.


#==============================================================================
# String
#------------------------------------------------------------------------------
LoaderFileName:		.asciz	"hdldr.bin"			# file name of LOADER 

.set		MessageLength	,	9
BootMessage:		.ascii	"Booting  "			# 0
Message1:		.ascii	"HD Boot  "			# 1
Message2:		.ascii	"No LOADER"			# 2
Message3:		.ascii	"Error 0  "			# 3
#==============================================================================

clear_screen:
	mov	$0x600, %ax		# AH = 6, AL = 0
	mov	$0x700, %bx		# black ground, write words 
	mov	$0x0, %cx		# left top (0,0)
	mov	$0x184f, %dx		# right bottom (80,50)
	int	$0x10
	ret

#------------------------------------------------------------------------------
# name of function disp_str
#------------------------------------------------------------------------------
# display a string, dh ought to be number of string at the beginning of function
disp_str:
	mov	$(MessageLength), %ax
	mul	%dh
	add	$(BootMessage), %ax
	mov	%ax, %bp		# '.
	mov	%ds, %ax		#  |	ES:BP addr of string
	mov	%ax, %es		# /
	mov	$(MessageLength), %cx	# length of string
	mov	$0x1301, %ax		# AH = 0x13, AL = 0x01
	mov	$0x7, %bx		# page number 0 (BH = 0),black background, white word (BL = 0x7)
	mov	$0x0, %dl
	int	$0x10
	ret

#--------------------------------------------------------------------
# read_sector
#--------------------------------------------------------------------
# Entry:
#     - fields disk_address_packet should have been filled
#       before invoking the routine
# Exit:
#     - es:bx -> data read
# registers changed:
#     - eax, ebx, dl, si, es
read_sector:
	xor	%ebx, %ebx

	mov	$0x42, %ah
	mov	$0x80, %dl
	mov	$(disk_address_packet), %si
	int	$0x13

	mov	(disk_address_packet + 6), %ax
	mov	%ax, %es
	mov	(disk_address_packet + 4), %bx

	ret

#----------------------------------------------------------------------------
# get_inode
#----------------------------------------------------------------------------
# Entry:
#     - eax    : inode nr.
# Exit:
#     - eax    : sector nr.
#     - ecx    : the_inode.i_size
#     - es:ebx : inodes sector buffer
# registers changed:
#     - eax, ebx, ecx, edx
get_inode:
	dec	%eax			# eax <- inode_nr - 1
	mov	%fs:(SB_INODE_SIZE), %bl
	mul	%bl			# eax <- (inode_nr - 1) * INODE_SIZE
	mov	$(SECT_BUF_SIZE), %edx
	subl	%fs:(SB_INODE_SIZE), %edx
	cmp	%edx, %eax
	jg	err
	push	%eax

	mov	%fs:(SB_NR_IMAP_SECTS), %ebx
	mov	%fs:(SB_NR_SMAP_SECTS), %edx
	lea	(ROOT_BASE + 2)(%ebx,%edx,), %eax
	movl	%eax, (disk_address_packet + 8)
	call	read_sector

	pop	%eax			# (es: ebx+eax) -> the inode

	movl	%fs:(SB_INODE_ISIZE_OFF), %edx
	add	%ebx, %edx
	add	%eax, %edx		# (es: edx) -> the_inode.i_size
	mov	%es:(%edx), %ecx	# ecx <- the_inode.i_size

# es:(ebx + eax) -> the_inode.i_start_sect
	addw	%fs:(SB_INODE_START_OFF), %ax

	add	%ax, %bx
	mov	%es:(%bx), %eax
	add	$(ROOT_BASE), %eax	# eax <- the_inode.i_start_sect
	ret


.org	510
.word	0xaa55
