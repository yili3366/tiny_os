###############################################################################
## boot/include/load.inc
###############################################################################

## kernel entry point, corresponding with Makefile
.set	KRNL_ENT_PT_PHY_ADDR	,	0x1000

## paging
.set	PAGE_DIR_BASE		,	0x100000
.set	PAGE_TBL_BASE		,	0x101000

## where loader is loaded
.set	LOADER_SEG		,	0x9000
.set	LOADER_OFF		,	0x100
.set	LOADER_PHY_ADDR		,	(LOADER_SEG * 0x10)

## where kernel file is loaded
.set	KERNEL_FILE_SEG		,	0x7000
.set	KERNEL_FILE_OFF		,	0
.set	KERNEL_FILE_PHY_ADDR	,	(KERNEL_FILE_SEG * 0x10)

# bytes reserved for kernel.bin
.set	KERNEL_VALID_SPACE	,	(LOADER_PHY_ADDR - KERNEL_FILE_PHY_ADDR)

## super block will be stored at: [0x700,0x900]
.set	SUPER_BLK_SEG		,	0x70

## ATTENTION:
##     Macros below should corresponding with C source.
.set	BOOT_PARAM_ADDR		,	0x900
.set	BOOT_PARAM_MAGIC	,	0xB007

## we don't calculate the base sector nr of the root device while loading
## but define it as a macro for two reasons:
## 1. it is a constant for any certain system
## 2. it simplifies boot sector and loader
.set	ROOT_BASE		,	0x4EFF

## corresponding with include/sys/fs.h
.set	SB_MAGIC_V1		,	0x111
.set	SB_MAGIC		,	(4 *  0)
.set	SB_NR_INODES		,	(4 *  1)
.set	SB_NR_SECTS		,	(4 *  2)
.set	SB_NR_IMAP_SECTS	,	(4 *  3)
.set	SB_NR_SMAP_SECTS	,	(4 *  4)
.set	SB_N_1ST_SECT		,	(4 *  5)
.set	SB_NR_INODE_SECTS	,	(4 *  6)
.set	SB_ROOT_INODE		,	(4 *  7)
.set	SB_INODE_SIZE		,	(4 *  8)
.set	SB_INODE_ISIZE_OFF	,	(4 *  9)
.set	SB_INODE_START_OFF	,	(4 * 10)
.set	SB_DIR_ENT_SIZE		,	(4 * 11)
.set	SB_DIR_ENT_INODE_OFF	,	(4 * 12)
.set	SB_DIR_ENT_FNAME_OFF	,	(4 * 13)

