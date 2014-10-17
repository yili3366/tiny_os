.text
.global memcpy
.global memset
.global	strcpy
.global strlen

# ------------------------------------------------------------------------
# void* memcpy(void* es:p_dst, void* ds:p_src, int size);
# ------------------------------------------------------------------------


memcpy:
	pushl   %ebp
	mov     %esp, %ebp

	pushl   %esi
	pushl   %edi
	pushl   %ecx

	mov     8(%ebp), %edi    	# Destination 
	mov     12(%ebp), %esi   	# Source 
	mov     16(%ebp), %ecx   	# Counter 
memcpy_1:
	cmp     $0, %ecx  		# Loop counter 
	jz      memcpy_2

	movb    %ds:(%esi), %al
	inc     %esi

	movb    %al, %es:(%edi)
	inc     %edi
#	movsb	%ds:(%esi),%es:(%edi)

	dec     %ecx
	jmp     memcpy_1
memcpy_2:
	mov     8(%ebp), %eax

	pop     %ecx
	pop     %edi
	pop     %esi

	mov     %ebp, %esp
	pop     %ebp

	ret

# ------------------------------------------------------------------------
# void memset(void* p_dst, char ch, int size);
# ------------------------------------------------------------------------

memset:
	pushl   %ebp
	movl	%esp, %ebp

	pushl	%esi
	pushl	%edi
	pushl	%ecx

	mov	8(%ebp), %edi    	# Destination 
	mov	12(%ebp), %edx   	# Char to be put
	mov	16(%ebp), %ecx   	# Counter 

memset_1:
	cmp	$0, %ecx  		# Loop counter 
	jz	memset_2
	
	movb	%dl,(%edi)
	inc	%edi

	dec	%ecx
	jmp	memset_1

memset_2:

	pop	%ecx
	pop	%edi
	pop	%esi

	mov	%ebp, %esp
	pop	%ebp

	ret
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# char*	strcpy(char* p_dst, char* p_src);
#-------------------------------------------------------------------------------
strcpy:
	push	%ebp
	mov	%esp,%ebp

#	pushl	%esi
#	pushl	%edi
#	pushl	%ecx

	mov	12(%ebp),%esi
	mov	8(%ebp),%edi
_1:	
	movb	(%esi),%al
	inc	%esi
	
	movb	%al,(%edi)
	inc	%edi
		
	cmp	$0,%al
	jnz	_1

	mov	8(%ebp),%eax

#	pop	%ecx
#	pop	%edi
#	pop	%esi

	pop	%ebp
	ret	
# ------------------------------------------------------------------------
# int strlen(char* p_str);
# ------------------------------------------------------------------------
strlen:
	push	%ebp
	mov	%esp,%ebp

	mov	$0,%eax		#the original length of string is 0
	mov	8(%ebp),%esi	#esi point to the start address

1:
	cmpb	$0,(%esi)
	jz	2f
	inc	%esi

	inc	%eax
	jmp	1b

2:	
	pop	%ebp
	ret
