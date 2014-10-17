BS_OEMName:         .ascii  "ForrestY"    # OEM String, 8 bytes required 
BPB_BytsPerSec:     .word  512           # Bytes per sector 
BPB_SecPerCluster:  .byte   1             # Sector per cluster 
BPB_ResvdSecCnt:    .word  1             # Reserved sector count 
BPB_NumFATs:        .byte   2             # Number of FATs 
BPB_RootEntCnt:     .word  224           # Root entries count 
BPB_TotSec16:       .word  2880          # Total sector number 
BPB_Media:          .byte   0xf0          # Media descriptor 
BPB_FATSz16:        .word  9             # FAT size(sectors) 
BPB_SecPerTrk:      .word  18            # Sector per track 
BPB_NumHeads:       .word  2             # Number of magnetic heads 
BPB_HiddSec:        .long  0             # Number of hidden sectors 
BPB_TotSec32:       .long  0             # If TotSec16 equal 0, this works 
BS_DrvNum:          .byte   0             # Driver number of interrupt 13 
BS_Reserved1:       .byte   0             # Reserved 
BS_BootSig:         .byte   0x29          # Boot signal 
BS_VolID:           .long  0             # Volume ID 
BS_VolLab:          .ascii  "OrangeS0.02" # Volume label, 11 bytes required 
BS_FileSysType:     .ascii  "FAT12   "    # File system type, 8 bytes required 

#------------------------------------------------------------------------------
#Some const
#------------------------------------------------------------------------------
.set	FATSz,9				#BPB_FATSz16
.set	RootDirSectors,14		#the space of rootdir use
.set	SecNoOfRootDir,19		#the first sector of root directory
.set	SecNoOfFAT1,1			#the first sector of fat1
.set	DeltaSecNo,17			#the first sector of file

