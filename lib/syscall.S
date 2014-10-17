# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 			syscall.asm	2010,7,9
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

.include "sconst.inc"

.set	INT_VECTOR_SYS_CALL	,	0x90
.set	_NR_printx,	0x00	#Live up to sys_call_table in global.c
.set	_NR_sendrec,	0x1


.global	printx
.global	sendrec

.section .text

# ====================================================================================
#                  sendrec(int function, int src_dest, MESSAGE* msg);
# ====================================================================================
# Never call sendrec() directly, call send_recv() instead.
sendrec:
	push	%ebx
	push	%ecx
	push	%edx

	mov	$(_NR_sendrec),%eax
	mov	16(%esp),%ebx		#function
	mov	20(%esp),%ecx		#src_dest
	mov	24(%esp),%edx		#p_msg
	int	$(INT_VECTOR_SYS_CALL)

	pop	%edx
	pop	%ecx
	pop	%ebx

	ret

# ====================================================================================
#                          void printx(char* s);
# ====================================================================================
printx:
	push	%edx

	mov	$(_NR_printx),%eax
	mov	8(%esp),%edx
	int	$(INT_VECTOR_SYS_CALL)

	pop	%edx

	ret

