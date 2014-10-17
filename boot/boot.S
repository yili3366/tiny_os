#  This file is licensed under the GNU General Public License; either
#  version 3 of the License, or (at your option) any later version. 

.code16
.set	BaseOfStack,0x7c00
.include "load.inc"
.text
# Floppy header of FAT12 
	jmp     LABEL_START # Start to boot. 
	nop                 # nop required 
.include "fat12hdr.inc"
# Initial registers. 
LABEL_START:
	mov     %cs,%ax
	mov     %ax,%ds
	mov     %ax,%es
	mov     %ax,%ss
	mov     $BaseOfStack, %sp

# Clear screen 
	mov     $0x0600,%ax   # %ah=6, %al=0 
	mov     $0x0700,%bx   # Black white 
	mov     $0,%cx        # Top left: (0,0) 
	mov     $0x184f,%dx   # Bottom right: (80,50) 
	int     $0x10         # BIOS int 10h, ah=6: Initialize screen 
	
# Display "Booting**" 
	mov     $0,%dh
	call    DispStr       # Display string(index 0)

# Reset floppy 
	xor     %ah,%ah
	xor     %dl,%dl       # %dl=0: floppy driver 0 
	int     $0x13         # BIOS int 13h, ah=0: Reset driver 0 

# Find LOADER.BIN in root directory of driver 0 
	movw    $SecNoOfRootDir, (wSectorNo)

# Read root dir sector to memory 
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmpw    $0,(wRootDirSizeForLoop)    # If searching in root dir 
	jz      LABEL_NO_LOADERBIN          # can find  LOADER.BIN ?   
	decw    (wRootDirSizeForLoop)
	mov     $(LOADER_SEG),%ax
	mov     %ax,%es                     # %es <- LOADER_SEG
	mov     $(LOADER_OFF),%bx         # %bx <- LOADER_OFF 
	mov     (wSectorNo),%ax             # %ax <- sector number in root 
	mov     $1,%cl
	call    ReadSector
	mov     $(LoaderFileName),%si         # %ds:%si -> LOADER  BIN 
	mov     $(LOADER_OFF),%di         # LOADER_SEG<<4+100
	cld
	mov     $0x10,%dx

# Search for "LOADER  BIN", FAT12 save file name in 12 bytes, 8 bytes for 
# file name, 3 bytes for suffix, last 1 bytes for '\20'. If file name is
# less than 8 bytes, filled with '\20'. So "LOADER.BIN" is saved as:
# "LOADER  BIN"(4f4c 4441 5245 2020 4942 204e). 

LABEL_SEARCH_FOR_LOADERBIN:
	cmp     $0,%dx                      # Read control 
	jz      LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR
	dec     %dx
	mov     $11,%cx

LABEL_CMP_FILENAME:
	cmp     $0,%cx
	jz      LABEL_FILENAME_FOUND    # If 11 chars are all identical? 
	dec     %cx
	lodsb                           # %ds:(%si) -> %al
	cmp     %es:(%di),%al
	jz      LABEL_GO_ON
	jmp     LABEL_DIFFERENT         # Different 

LABEL_GO_ON:
	inc     %di
	jmp     LABEL_CMP_FILENAME      # Go on loop 

LABEL_DIFFERENT:
	and     $0xffe0,%di             # Go to head of this entry 
	add     $0x20,%di
	mov     $LoaderFileName,%si     # Next entry 
	jmp     LABEL_SEARCH_FOR_LOADERBIN

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	addw    $1,(wSectorNo)
	jmp     LABEL_SEARCH_IN_ROOT_DIR_BEGIN

# Not found LOADER.BIN in root dir. 
LABEL_NO_LOADERBIN:
	mov     $2,%dh
	call    DispStr         # Display string(index 2) 
	jmp        .            # Infinite loop 

# Found. 
LABEL_FILENAME_FOUND:
	mov     $RootDirSectors,%ax
	and     $0xffe0,%di             # Start of current entry, 32 bytes per entry 
	add     $0x1a,%di               # First sector of this file 
	mov     %es:(%di),%cx
	push    %cx                     # Save index of this sector in FAT 
	add     %ax,%cx
	add     $(DeltaSecNo),%cx         # LOADER.BIN's start sector saved in %cl 
	mov     $(LOADER_SEG),%ax
	mov     %ax,%es                 # %es <- LOADER_SEG 
	mov     $(LOADER_OFF),%bx     # %bx <- LOADER_OFF 
	mov     %cx,%ax                 # %ax <- Sector number 

# Load LOADER.BIN's sector's to memory. 
LABEL_GOON_LOADING_FILE:
	push    %ax
	push    %bx
	mov     $0x0e,%ah
	mov     $'.',%al    # Char to print 
	mov     $0x0f,%bl   # Front color: white 
	int     $0x10       # BIOS int 10h, ah=0xe: Print char 
	pop     %bx
	pop     %ax

	mov     $1,%cl
	call    ReadSector
	pop     %ax             # Got index of this sector in FAT 
	call    GetFATEntry
	cmp     $0x0fff,%ax
	jz      LABEL_FILE_LOADED
	push    %ax             # Save index of this sector in FAT 
	mov     $(RootDirSectors),%dx
	add     %dx,%ax
	add     $(DeltaSecNo),%ax
	add     (BPB_BytsPerSec),%bx
	jmp     LABEL_GOON_LOADING_FILE

LABEL_FILE_LOADED:
	mov     $1,%dh        
	call    DispStr        # Display string(index 1) 

#******************************************************************
#   Jump to LOADER.BIN's start address in memory.

	ljmp     $(LOADER_SEG),$(LOADER_OFF)
#*****************************************************************

# ==================================================================
#   Variable table

wRootDirSizeForLoop:    .word  RootDirSectors
wSectorNo:              .word  0       # Sector number to read 
bOdd:                   .byte   0       # odd or even? 

# ==================================================================
#   String table

LoaderFileName:     .asciz  "LOADER  BIN"        # File name 
.set    MessageLength,9
BootMessage:        .ascii    "Booting  "        # index 0 
Message1:           .ascii    "Ready.   "        # index 1 
Message2:           .ascii    "No LOADER"        # index 2 

# ==================================================================
#   Routine: DispStr
#   Action: Display a string, string index stored in %dh

DispStr: 
	mov     $MessageLength, %ax
	mul     %dh
	add     $BootMessage,%ax
	mov     %ax,%bp               # String address 
	mov     %ds,%ax
	mov     %ax,%es
	mov     $MessageLength,%cx    # String length 
	mov     $0x1301,%ax           # ah = 0x13, al = 0x01(W) 
	mov     $0x07,%bx             # PageNum 0(bh = 0), bw(bl= 0x07)
	mov     $0,%dl                # Start row and column 
	int     $0x10                 # BIOS INT 10h, display string 
	ret

# ==================================================================
#   Routine: ReadSector
#   Action: Read %cl Sectors from %ax sector(floppy) to %es:%bx(memory) 
#	 Assume sector number is 'x', then:
#	   x/(BPB_SecPerTrk) = y,
#	   x%(BPB_SecPerTrk) = z.
#	 The remainder 'z' PLUS 1 is the start sector number;
#	 The quotient 'y' divide by BPB_NumHeads(RIGHT SHIFT 1 bit)is cylinder
#	   number;
#	 AND 'y' by 1 can got magnetic header.

ReadSector:
	push    %ebp
	mov     %esp,%ebp
	sub     $2,%esp        # Reserve space for saving %cl 
	mov     %cl,-2(%ebp)
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
#header in %dh. 
	mov     (BS_DrvNum), %dl
GoOnReading:
	mov     $2,%ah
	mov     -2(%ebp),%al    # Read %al sectors 
	int     $0x13
	jc      GoOnReading     # If CF set 1, mean read error, reread. 
	add     $2,%esp
	pop     %ebp
	ret

# ==================================================================
#   Routine: GetFATEntry
#   Action: Find %ax sector's index in FAT, save result in %ax 

GetFATEntry:
	push    %es
	push    %bx
	push    %ax
	mov     $LOADER_SEG,%ax
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

.org 510        # Skip to address 0x510. 
.word 0xaa55   # Write boot flag to 1st sector(512 bytes) end 

