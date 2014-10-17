#  This file is licensed under the GNU General Public License; either
#  version 3 of the License, or (at your option) any later version. 

.code16
.text
# Floppy header of FAT12 
	jmp     LABEL_START # Start to boot. 
.include "fat12hdr.inc"
.include "load.inc"
.include "pm.inc"

#GDT
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

# Initial registers. 
LABEL_START:
	mov     %cs,%ax
	mov     %ax,%ds
	mov     %ax,%es
	mov     %ax,%ss
	mov     $(BaseOfStack), %sp

# Display "Loading  " 
	mov     $0,%dh
	call    DispStrRealMode       # Display string(index 0)

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

# Reset floppy 
	xor     %ah,%ah
	xor     %dl,%dl       # %dl=0: floppy driver 0 
	int     $0x13         # BIOS int 13h, ah=0: Reset driver 0 

# Find KERNEL.BIN in root directory of driver 0 
	movw    $SecNoOfRootDir, (wSectorNo)

# Read root dir sector to memory 
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmpw    $0,(wRootDirSizeForLoop)    # If searching in root dir 
	jz      LABEL_NO_KERNELBIN          # can find  KERNEL.BIN ?   
	decw    (wRootDirSizeForLoop)
	mov     $(KERNEL_FILE_SEG),%ax
	mov     %ax,%es                     # %es <- KERNEL_FILE_SEG
	mov     $(KERNEL_FILE_OFF),%bx         # %bx <- KERNEL_FILE_OFF 
	mov     (wSectorNo),%ax             # %ax <- sector number in root 
	mov     $1,%cl
	call    ReadSector

	mov     $(KernelFileName),%si         # %ds:%si -> "KERNEL  BIN" 
	mov     $(KERNEL_FILE_OFF),%di         # KERNEL_FILE_SEG<<4+100
	cld
	mov     $0x10,%dx

# Search for "KERNEL  BIN", FAT12 save file name in 12 bytes, 8 bytes for 
# file name, 3 bytes for suffix, last 1 bytes for '\20'. If file name is
# less than 8 bytes, filled with '\20'. So "KERNEL.BIN" is saved as:
# "KERNEL  BIN"(4f4c 4441 5245 2020 4942 204e). 

LABEL_SEARCH_FOR_KERNELBIN:
	cmp     $0,%dx                      # Read control 
	jz      LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR
	dec     %dx
	mov     $11,%cx

LABEL_CMP_FILENAME:
	cmp     $0,%cx
	jz      LABEL_FILENAME_FOUND    # If 11 chars are all identical? 
	dec     %cx
	lodsb                           # %ds:(%si) -> %al
	cmpb	%es:(%di),%al
	jz      LABEL_GO_ON
	jmp     LABEL_DIFFERENT         # Different 

LABEL_GO_ON:
	inc     %di
	jmp     LABEL_CMP_FILENAME      # Go on loop 

LABEL_DIFFERENT:
	and     $0xffe0,%di             # Go to head of this entry 
	add     $0x20,%di
	mov     $KernelFileName,%si     # Next entry 
	jmp     LABEL_SEARCH_FOR_KERNELBIN

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	addw    $1,(wSectorNo)
	jmp     LABEL_SEARCH_IN_ROOT_DIR_BEGIN

# Not found KERNEL.BIN in root dir. 
LABEL_NO_KERNELBIN:
	mov     $0x3,%dh
	call    DispStrRealMode         # Display string(index 3) 
	jmp        .            # Infinite loop 

# Found. 
LABEL_FILENAME_FOUND:
	mov     $(RootDirSectors),%ax
	and     $0xfff0,%di             # Start of current entry, 32 bytes per entry 
	push	%eax
	mov	%es:0x1c(%edi),%eax
	movl	%eax,(dwKernelSize)	#save kernel.bin

	cmp	$(KERNEL_VALID_SPACE),%eax
	ja	1f
	pop	%eax
	jmp	2f
1:
	mov	$4,%dh			# "Too Large"
	call	DispStrRealMode		# display the string
	jmp	.
2:
	add     $0x1a,%di               # First sector of this file 
	mov     %es:(%di),%cx
	push    %cx                     # Save index of this sector in FAT 
	add     %ax,%cx
	add     $(DeltaSecNo),%cx	# KERNEL.BIN's start sector saved in %cl 
	mov     $(KERNEL_FILE_SEG),%ax
	mov     %ax,%es                 # %es <- KERNEL_FILE_SEG 
	mov     $(KERNEL_FILE_OFF),%bx     # %bx <- KERNEL_FILE_OFF 
	mov     %cx,%ax                 # %ax <- Sector number 

# Load KERNEL.BIN's sector's to memory. 
LABEL_GOON_LOADING_FILE:
	push    %ax
	push    %bx
	mov     $0xe,%ah
	mov     $'.',%al    # Char to print 
	mov     $0xf,%bl   # Front color: white 
	int     $0x10       # BIOS int 10h, ah=0xe: Print char 
	pop     %bx
	pop     %ax

	mov     $1,%cl
	call    ReadSector
	pop     %ax             # Got index of this sector in FAT 
	call    GetFATEntry
	cmp     $0xfff,%ax
	jz      LABEL_FILE_LOADED
	push    %ax             # Save index of this sector in FAT 
	mov     $(RootDirSectors),%dx
	add     %dx,%ax
	add     $(DeltaSecNo),%ax
	add     (BPB_BytsPerSec),%bx
	jc	1f		#kerenl >64KB if bx reset to 0
	jmp	2f
1:
	push	%ax		#es+=0x1000 es point to next seg
	mov	%es,%ax
	add	$0x1000,%ax
	mov	%ax,%es
	pop	%ax
2:
	jmp     LABEL_GOON_LOADING_FILE
LABEL_FILE_LOADED:

	call	KillMotor	#shutdown floppy
	xor	%ax,%ax
	mov	%ax,%es
	mov	$0x201,%ax	#AH = 02
				#AL = num of secs to read
	mov	$1,%cx		#CH = low eight bits of cylinder
				#CL = secs num 1-63 (bits 0-5)
				#high two bits of cylinder
				#(bits 6-7,hard disk only)
	mov	$0x80,%dx	#DH = head number
				#DL = drive number (bit 7 set for
				#hard disk )
	mov	$0x500,%bx	#ES:BX -> data buffer
	int	$0x13
	
	mov	$2,%dh
	call    DispStrRealMode        # Display string(index 1) 
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

# ==================================================================
#   Variable table

wRootDirSizeForLoop:    .word	RootDirSectors
wSectorNo:              .word  	0       # Sector number to read
bOdd:                   .byte   0       # odd or even? 
dwKernelSize:		.long	0	#Size of KERNEL.BIN

# ==================================================================
#   String table

KernelFileName:     .asciz  "KERNEL  BIN"        # File name 
.set    MessageLength,9
LoadMessage:        .ascii    "Loading  "        # index 0 
Message1:	    .ascii    "         "	 # index 1
Message2:           .ascii    "Ready.   "        # index 2 
Message3:           .ascii    "No KERNEL"        # index 3 
Message4:	    .ascii    "Too Large"	 # index 4

# ==================================================================
#   Routine: DispStrRealMode
#   Action: Display a string, string index stored in %dh

DispStrRealMode: 
	mov     $MessageLength, %ax
	mul     %dh
	add     $(LoadMessage),%ax
	mov     %ax,%bp               	# String address 
	mov     %ds,%ax
	mov     %ax,%es
	mov     $(MessageLength),%cx    # String length 
	mov     $0x1301,%ax           	# ah = 0x13, al = 0x01(W) 
	mov     $0x07,%bx             	# PageNum 0(bh = 0), bw(bl= 0x07)
	mov     $0,%dl                	# Start row and column 
	add	$3,%dh			#from line 3
	int     $0x10                 	# BIOS INT 10h, display string 
	ret

# ==================================================================
# Routine: ReadSector
# Action: Read %cl Sectors from %ax sector(floppy) to %es:%bx(memory) 
# Assume sector number is 'x', then:
# x/(BPB_SecPerTrk) = y,
# x%(BPB_SecPerTrk) = z.
# The remainder 'z' PLUS 1 is the start sector number;
# The quotient 'y' divide by BPB_NumHeads(RIGHT SHIFT 1 bit)is cylinder
# number;
# AND 'y' by 1 can got magnetic header.

ReadSector:
	push    %bp
	mov     %sp,%bp
	sub     $2,%esp        # Reserve space for saving %cl 
	movb	%cl,-2(%bp)
	push    %bx            # Save bx 
	mov     (BPB_SecPerTrk), %bl    # %bl: the divider 
	div     %bl            # 'y' in %al, 'z' in %ah 
	inc     %ah            # z++, got start sector 
	mov     %ah,%cl        # %cl <- start sector number 
	mov     %al,%dh        # %dh <- 'y' 
	shr     $1,%al         # 'y'/BPB_NumHeads 
	mov     %al,%ch        # %ch <- Cylinder number(y>>1) 
	and     $1,%dh         # %dh <- Magnetic header(y&1) 
	pop     %bx            # Restore %bx 
# Now, we got cylinder number in %ch, start sector number in %cl, magnetic
#	   header in %dh. 
	mov     (BS_DrvNum), %dl
GoOnReading:
	mov     $2,%ah
	mov     -2(%bp),%al    # Read %al sectors 
	int     $0x13
	jc      GoOnReading     # If CF set 1, mean read error, reread. 
	add     $2,%esp
	pop     %bp
	ret

# ==================================================================
#   Routine: GetFATEntry
#   Action: Find %ax sector's index in FAT, save result in %ax 

GetFATEntry:
	push    %es
	push    %bx
	push    %ax
	mov     $KERNEL_FILE_SEG,%ax
	sub     $0x0100,%ax
	mov     %ax,%es           # Left 4K bytes for FAT 
	pop     %ax
	mov     $3,%bx
	mul     %bx               # %dx:%ax = %ax*3 
	mov     $2,%bx
	div     %bx               # %dx:%ax/2 
	movb    %dl, (bOdd)       # store remainder %dx in label bOdd. 

LABEL_EVEN:
	xor     %dx,%dx           # Now %ax is the offset of FATEntry in FAT 
	mov     (BPB_BytsPerSec),%bx
	div     %bx               # %dx:%ax/BPB_BytsPerSec 
	push    %dx
	mov     $0,%bx
	add     $SecNoOfFAT1,%ax  # %ax <- FATEntry's sector 
	mov     $2,%cl            # Read 2 sectors in 1 time, because FATEntry 
	call    ReadSector        # may be in 2 sectors. 
	pop     %dx
	add     %dx,%bx
	mov     %es:(%bx),%ax     # read FAT entry by word(2 bytes) 
	cmpb    $0,(bOdd)         # remainder %dx(see above) == 0 ?
	jz      LABEL_EVEN_2      # NOTE: %ah: high address byte, %al: low byte 
	shr     $4,%ax

LABEL_EVEN_2:
	and     $0x0fff,%ax

LABEL_GET_FAT_ENTRY_OK:
	pop     %bx
	pop     %es
	ret
#------------------------------------------------------------------------------
#kill motor of floppy
#------------------------------------------------------------------------------
KillMotor:
	push	%dx
	mov	$0x03f2,%dx
	mov	$0x0,%al
	out	%al,%dx
	pop	%dx
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

#	mov	$0xf,%ah
#	mov	$'P',%al
#	mov	%ax,%gs:((80 * 0+39)*2)
	
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

