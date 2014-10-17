#  This file is licensed under the GNU General Public License; either
#  version 3 of the License, or (at your option) any later version. 

.code16
.text
	jmp     LABEL_START # Start to boot. 
#.include "fat12hdr.inc"
.include "load.inc"
.include "pm.inc"


.set	TRANS_SECT_NR	,	0x2
.set	SECT_BUF_SIZE	,	(TRANS_SECT_NR * 512)

disk_address_packet:	.byte	0x10	#[0] Packet size in bytes.
			.byte	0x0	#[1] Reserved must be 0.
sect_cnt:		.byte	TRANS_SECT_NR	#[2] Nr of blocks to transfer.
			.byte	0x0	#[3] Reserved, must be 0.
			.word	KERNEL_FILE_OFF	#[4] Addr of transfer - Offset
			.word	KERNEL_FILE_SEG	#[6] buffer. -  Seg
lba_addr:		.long	0x0	#[8] LBA. Low 32-bits.
			.long	0x0	#[12] LBA. High 32-bits.


#GDT
#--------------------------------------------------------------------
LABEL_GDT:          Descriptor        	0x0,         	0x0, 		0x0
LABEL_DESC_FLAT_C:  Descriptor        	0x0,            0xfffff, 	(DA_CR|DA_32|DA_LIMIT_4K)
LABEL_DESC_FLAT_RW: Descriptor        	0x0,            0xfffff, 	(DA_DRW|DA_32|DA_LIMIT_4K)
LABEL_DESC_VIDEO:   Descriptor  	0xb8000,      	0xffff, 	(DA_DRW|DA_DPL3)

.set GdtLen, (.-LABEL_GDT)  		# GDT Length 

GdtPtr: .word  (GdtLen-1)  		# GDT Limit 
	.long  (LOADER_PHY_ADDR+LABEL_GDT)	# GDT Base 

# GDT Selector(TI flag clear) 
.set    SelectorFlatC  	,(LABEL_DESC_FLAT_C-LABEL_GDT)
.set    SelectorFlatRW 	,(LABEL_DESC_FLAT_RW-LABEL_GDT)
.set    SelectorVideo	,(LABEL_DESC_VIDEO-LABEL_GDT+SA_RPL3)

.set	BaseOfStack, 0x100


err:
	mov	$5, %dh			# "Error 0"
	call	real_mode_disp_str	# display the string
	jmp	.

# Initial registers. 
LABEL_START:
	mov     %cs,%ax
	mov     %ax,%ds
	mov     %ax,%es
	mov     %ax,%ss
	mov     $(BaseOfStack), %sp

# Display "Loading  " 
	mov     $0,%dh
	call    real_mode_disp_str	# Display string(index 0)

# Get System Address Map 
	xor     %ebx, %ebx             	# EBX: Continuation, 0 
	mov     $(_MemChkBuf), %di    	# ES:DI: Buffer Pointer, _MemChkBuf 
BEGIN_loop:
	mov     $0xe820, %eax          	# EAX: Function code, E820h 
	mov     $20, %ecx              	# ECX: Buffer size, 20 
	mov     $0x534d4150, %edx      	# EDX: Signature 'SMAP' 
	int     $0x15                  	# INT 15h 
	jc      BEGIN_getAMfail
	add     $20, %di               	# Increase buffer pointer by 20(bytes) 
	incl    (_dwMCRNumber)   	# Inc Address Map Entry Counter by 1 
	cmp     $0, %ebx               	# End of Address Map? 
	jne     BEGIN_loop
	jmp     BEGIN_getAMok
BEGIN_getAMfail:                   # Failed to get system address map 
	movl    $0, (_dwMCRNumber)
BEGIN_getAMok:                     # Got system address map 


#get the sector nr of `/' (ROOT_INODE), it'll be stored in eax

	mov	%fs:(SB_ROOT_INODE),%eax	#fs -> super_block
	call	get_inode

# read '/' into ex:bx
	movl	%eax, (disk_address_packet + 8)
	call	read_sector

# let's search '/' for the kernel
	mov	$(KernelFileName), %si
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
	cmp	$0,%al		# both arrive at a '\0', match
	jz	found
	inc	%bx		# next char at disk
	jmp	1b		# on and on
different:
	pop	%bx		# -> restore
	add	%fs:(SB_DIR_ENT_SIZE), %bx
	sub	%fs:(SB_DIR_ENT_SIZE), %ecx
	jz	not_found
	push	%bx
	mov	$(KernelFileName), %si
	jmp	str_cmp
not_found:
	mov	$3,%dh
	call	real_mode_disp_str
	jmp	.
found:
	pop	%bx
	add	%fs:(SB_DIR_ENT_INODE_OFF), %bx
	mov	%es:(%bx), %eax		# eax <- inode nr of kernel
	call	get_inode		# eax <- start sector nr of kernel
	movl	%eax, (disk_address_packet + 8)
load_kernel:
	call	read_sector
	cmp	$(SECT_BUF_SIZE),%ecx
	jl	done
	sub	$(SECT_BUF_SIZE), %ecx	# bytes_left -= SECT_BUF_SIZE
	addw	$(SECT_BUF_SIZE), (disk_address_packet + 4)	# transfer buffer
	jc	_1
	jmp	_2
_1:
	addw	$0x1000, (disk_address_packet + 6)
_2:
	addl	$(TRANS_SECT_NR), (disk_address_packet + 8)
	jmp	load_kernel
done:
	mov	$0x2,%dh
	call	real_mode_disp_str


# Load GDTR(Global Descriptor Table Register) 
	lgdtw   GdtPtr

# Clear Interrupt Flags 
	cli

# Open A20 line. 
	inb     $0x92, %al
	orb     $0b00000010, %al
	outb    %al, $0x92

# Enable protect mode, PE bit of CR0. 
	movl    %cr0, %eax
	orl     $1, %eax
	movl    %eax, %cr0
#Mixed-Size jump
	.byte	0x66,0xea
	.long	(LOADER_PHY_ADDR+LABEL_PM_START)
	.word	SelectorFlatC

	jmp	.		#never arrive here

# ==================================================================
#   Variable table
# ==================================================================
wSectorNo:              .word  	0       # Sector number to read
bOdd:                   .byte   0       # odd or even? 
dwKernelSize:		.long	0	#Size of KERNEL.BIN

# ==================================================================
#   String table

KernelFileName:     	.asciz	"kernel.bin"	# File name 
.set    MessageLength	,	9
LoadMessage:        	.ascii	"Loading  "	# index 0 
Message1:	    	.ascii	"         "	# index 1
Message2:           	.ascii	"in HD LDR"	# index 2 
Message3:           	.ascii	"No KERNEL"	# index 3 
Message4:	    	.ascii	"Too Large"	# index 4
Message5:		.ascii	"Error 0  "		
#====================================================================

#====================================================================

clear_screen:
	mov	$0x600, %ax		# AH = 6, AL = 0
	mov	$0x700, %bx		# black background, write word
	mov	$0x0, %cx		# (0, 0)
	mov	$0x184f, %dx		# (80, 50)
	int	$0x10
	ret

# ==================================================================
#   Routine: DispStrRealMode
#   Action: Display a string, string index stored in %dh

real_mode_disp_str: 
	mov     $(MessageLength), %ax
	mul     %dh
	add     $(LoadMessage),%ax
	mov     %ax,%bp               	# String address 
	mov     %ds,%ax
	mov     %ax,%es
	mov     $(MessageLength),%cx    # String length 
	mov     $0x1301,%ax           	# ah = 0x13, al = 0x01(W) 
	mov     $0x07,%bx             	# PageNum 0(bh = 0), bw(bl= 0x07)
	mov     $0,%dl                	# Start row and column 
	int     $0x10                 	# BIOS INT 10h, display string 
	ret
#----------------------------------------------------------------------------
# read_sector
#----------------------------------------------------------------------------
# before:
#     - fields disk_address_packet should have been filled
#       before invoking the routine
# after:
#     - es:bx -> data read
# registers changed:
#     - eax, ebx, dl, si, es

read_sector:
	xor	%ebx, %ebx

#	movl	%eax, (disk_address_packet + 8)
	movl	$0, (disk_address_packet + 12)

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


#------------------------------------------------------------------------------
#protected mode
.code32

.align 32

LABEL_PM_START:
	mov	$(SelectorVideo),%ax
	mov	%ax,%gs
	
	mov	$(SelectorFlatRW),%ax
	mov	%ax,%ds
	mov	%ax,%es
	mov	%ax,%fs
	mov	%ax,%ss
	mov	$(TopOfStack),%esp

	
	call	DispMemInfo

	call	SetupPaging

	
	call 	InitKernel

#fill in BootParam[]
	movw	$(BOOT_PARAM_MAGIC),(BOOT_PARAM_ADDR)	#BootParam[0] = BootParamMagic
	mov	(dwMemSize),%eax
	mov	%eax,(BOOT_PARAM_ADDR + 4)	#BootParam[1] = MemSize
	mov	$(KERNEL_FILE_SEG),%eax
	shl	$4,%eax
	add	$(KERNEL_FILE_OFF),%eax
	mov	%eax,(BOOT_PARAM_ADDR + 8)	#phy-addr of kernel.bin

	ljmp	$(SelectorFlatC),$(KRNL_ENT_PT_PHY_ADDR)

.include "lib.inc"

#------------------------------------------------------------------------------
#Display memory infomation
DispMemInfo:
	push    %esi
	push    %edi
	push    %ecx

	push	$(szMemChkTitle)
	call	DispStr
	add	$4,%esp

	mov     $(MemChkBuf), %esi  # int *p = MemChkBuf;                     
	mov     (dwMCRNumber), %ecx     # for (int i=0; i<dwMCRNumber; i++) {         
DMS_loop:
	mov     $5, %edx             #   int j = 5;                             
	mov     $(ARDStruct), %edi   #   int *q = (int *)ARDStruct;             
DMS_1:
	push    (%esi)               #   do {                                   
	call    DispInt              #     printf("%xh", *p);                   
	pop     %eax
	stosl                        #     *q++ = *p;                           
	add     $4, %esi             #     p++;                                 
	dec     %edx                 #     j--;                                 
	cmp     $0, %edx
	jnz     DMS_1                #   } while(j != 0);                       
	call    DispLF               #   printf("\n");                          
	cmpl    $1, (dwType)           #   if (Type == AddressRangMemory){        
	jne     DMS_2
	mov     (dwBaseAddrLow), %eax  #     if(ARDStruct.dwBaseAddrLow             
	add     (dwLengthLow), %eax    #+ARDStruct.dwLengthLow             
	cmp     (dwMemSize), %eax      #        > dwMemSize){                       
	jb      DMS_2                #       dwMemSize = dwBaseAddrLow+dwLengthLow; 
	mov     %eax, (dwMemSize)      #     }                                    
DMS_2:                           #   }                                      
	loop    DMS_loop             # }                                        

	call    DispLF               # printf("\n");                            
	push    $(szRAMSize)
	call    DispStr              # printf("%s", szRAMSize);                
	add     $4, %esp

	pushl   (dwMemSize)
	call    DispInt              # printf("%x", dwMemSize);                   
	add     $4, %esp

	pop     %ecx
	pop     %edi
	pop     %esi
	ret
#------------------------------------------------------------------------------
SetupPaging:
# Directly map linear addresses to physical addresses for simplification 
# Get usable PDE number from memory size. 
	xor     %edx, %edx
	mov     (dwMemSize), %eax         # Memory Size 
	mov     $0x400000, %ebx         # Page table size(bytes), 1024*1024*4 
	div     %ebx                    # temp = dwMemSize/4M 
	mov     %eax, %ecx
	test    %edx, %edx
	jz      SP_no_remainder
	inc     %ecx
SP_no_remainder:
	push    %ecx                    # number of PDE = ceil(temp) 

	# Init page table directories, %ecx entries. 
	mov     $(SelectorFlatRW), %ax
	mov     %ax, %es
	mov	$(PAGE_DIR_BASE), %edi
	xor     %eax, %eax
	# Set PDE attributes(flags): P: 1, U/S: 1, R/W: 1. 
	mov     $(PAGE_TBL_BASE|PG_P|PG_USU|PG_RWW), %eax
SP_1:
	stosl                   # Store %eax to %es:%edi consecutively. 
	add     $4096, %eax     # Page tables are in sequential format. 
	loop    SP_1            # %ecx loops. 

	# Init page tables, %ecx*1024 pages. 
	pop     %eax             # Pop pushed ecx(number of PDE) 
#	shl     $10, %eax        # Loop counter, num of pages: 1024*%ecx. 
	mov	$1024,%ebx
	mul	%ebx
	mov     %eax, %ecx
	mov	$(PAGE_TBL_BASE), %edi
	xor	%eax,%eax
	# Set PTE attributes(flags): P:1, U/S: 1， R/W: 1. 
	mov     $(PG_P|PG_USU|PG_RWW), %eax
SP_2:
	stosl                   # Store %eax to %es:%edi consecutively. 
	add     $4096, %eax     # Pages are in sequential format. 
	loop    SP_2            # %ecx loops. 

	mov     $(PAGE_DIR_BASE), %eax
	mov     %eax, %cr3 # Store base address of page table dir to %cr3. 
	mov     %cr0, %eax
	or      $0x80000000, %eax
	mov     %eax, %cr0 # Enable paging bit in %cr0. 
	jmp	SP_3
SP_3:
	nop

	ret
#------------------------------------------------------------------------------
InitKernel:
	xor	%esi,%esi
	movw	(KERNEL_FILE_PHY_ADDR+0x2c),%cx		#phnum
	movzwl	%cx,%ecx

	mov	(KERNEL_FILE_PHY_ADDR+0x1c),%esi		#phoff

	add	$(KERNEL_FILE_PHY_ADDR),%esi
_Begin:
	mov	0(%esi),%eax
	cmpl	$0x0,%eax
	jz	_NoAction
	pushl	0x10(%esi)			#size
	movl	0x4(%esi),%eax
	add	$(KERNEL_FILE_PHY_ADDR),%eax
	push	%eax				#src
	pushl	0x8(%esi)			#dst
	call	MemCpy
	add	$12,%esp
_NoAction:
	add	$0x20,%esi
	dec	%ecx
	jnz	_Begin

	ret

#------------------------------------------------------------------------------
LABEL_DATA:
.align 32
#data segment
_szMemChkTitle:	.asciz "BaseAddrL BaseAddrH LengthLow LengthHigh  Type\n"
_szRAMSize:    	.asciz "RAM Size:"
_szReturn:	.asciz "\n"   # Line Feed Message(New line) 

_dwMCRNumber:	.long 0        # Memory Check Result 
_dwDispPos:     .long (80*7+0)*2  # Screen Cursor position for printing 
_dwMemSize:	.long 0        # Usable Memory Size 
_ARDStruct:                     # Address Range Descriptor Structure 
	_dwBaseAddrLow:     .long 0    # Low 32 bits of base address 
	_dwBaseAddrHigh:    .long 0    # High 32 bits of base address 
	_dwLengthLow:       .long 0    # Low 32 bits of length in bytes 
	_dwLengthHigh:      .long 0    # High 32 bits of length in bytes 
	_dwType:            .long 0    # Address type of this range: 0, 1, other 
_MemChkBuf:  .space 256, 0      # Address map buffer 

.set    szMemChkTitle,        (_szMemChkTitle+LOADER_PHY_ADDR)
.set    szRAMSize,       (_szRAMSize+LOADER_PHY_ADDR)
.set    szReturn,            (_szReturn+LOADER_PHY_ADDR)
.set    dwMCRNumber,         (_dwMCRNumber+LOADER_PHY_ADDR)
.set    dwDispPos,        (_dwDispPos+LOADER_PHY_ADDR)
.set    dwMemSize,          (_dwMemSize+LOADER_PHY_ADDR)
.set    ARDStruct,        (_ARDStruct+LOADER_PHY_ADDR)
	.set  dwBaseAddrLow,      (_dwBaseAddrLow+LOADER_PHY_ADDR)
	.set  dwBaseAddrHigh,     (_dwBaseAddrHigh+LOADER_PHY_ADDR)
	.set  dwLengthLow,        (_dwLengthLow+LOADER_PHY_ADDR)
	.set  dwLengthHigh,       (_dwLengthHigh+LOADER_PHY_ADDR)
	.set  dwType,             (_dwType+LOADER_PHY_ADDR)
.set    MemChkBuf,       (_MemChkBuf+LOADER_PHY_ADDR)

# 32-bit global stack segment. 
StackSpace:.space  1024, 0
.set    TopOfStack, (LOADER_PHY_ADDR+.)

