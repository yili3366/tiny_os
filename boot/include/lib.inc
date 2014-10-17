/* chapter3/7/lib.h

   Author: Wenbo Yang <solrex@gmail.com> <http://solrex.cn>

   This file is part of the source code of book "Write Your Own OS with Free
   and Open Source Software". Homepage @ <http://share.solrex.cn/WriteOS/>.

   This file is licensed under the GNU General Public License; either
   version 3 of the License, or (at your option) any later version. */

DispAL:
	push   %ecx
	push   %edx
	push   %edi
	mov    (dwDispPos), %edi
	mov    $0xf, %ah
	mov    %al, %dl
	shrb   $4, %al
	mov    $2, %ecx
DispAL_begin:
	and    $0xf, %al
	cmp    $9, %al
	ja     DispAL_1
	add    $'0', %al
	jmp    DispAL_2
DispAL_1:
	sub    $0xA, %al
	add    $'A', %al
DispAL_2:
	mov    %ax, %gs:(%edi)
	add    $2, %edi
	mov    %dl, %al
	loop   DispAL_begin
	mov    %edi, (dwDispPos)
	pop    %edi
	pop    %edx
	pop    %ecx
	ret

DispInt:
	movl    4(%esp), %eax
	shr     $24, %eax
	call    DispAL
	movl    4(%esp), %eax
	shr     $16, %eax
	call    DispAL
	movl    4(%esp), %eax
	shr     $8, %eax
	call    DispAL
	movl    4(%esp), %eax
	call    DispAL
	movb    $0x7, %ah
	movb    $'h', %al
	pushl   %edi
	movl    (dwDispPos), %edi
	movw    %ax, %gs:(%edi)
	addl    $4, %edi
	movl    %edi, (dwDispPos)
	popl    %edi
	ret

DispStr:
	pushl   %ebp
	movl    %esp, %ebp
	pushl   %ebx
	pushl   %esi
	pushl   %edi
	movl    8(%ebp), %esi
	movl    (dwDispPos), %edi
	movb    $0xF, %ah
DispStr_1:
	lodsb
	testb   %al, %al
	jz      DispStr_2
	cmpb    $0xA, %al
	jnz     DispStr_3
	pushl   %eax
	movl    %edi, %eax
	movb    $160, %bl
	divb    %bl
	andl    $0xFF, %eax
	incl    %eax
	movb    $160, %bl
	mulb    %bl
	movl    %eax, %edi
	popl    %eax
	jmp     DispStr_1
DispStr_3:
	movw    %ax, %gs:(%edi)
	addl    $2, %edi
	jmp     DispStr_1
DispStr_2:
	movl    %edi, (dwDispPos)
	popl    %edi
	popl    %esi
	popl    %ebx
	popl    %ebp
	ret

DispLF:
	pushl  $(szReturn)
	call    DispStr
	addl    $4, %esp
	ret

MemCpy:
	pushl   %ebp
	mov     %esp, %ebp

	pushl   %esi
	pushl   %edi
	pushl   %ecx

	mov     8(%ebp), %edi    /* Destination */
	mov     12(%ebp), %esi   /* Source */
	mov     16(%ebp), %ecx   /* Counter */
MemCpy_1:
	cmp     $0, %ecx  /* Loop counter */
	jz      MemCpy_2
#    movb    %ds:(%esi), %al
#    inc     %esi
#    movb    %al, %es:(%edi)
#    inc     %edi
	movsb	%ds:(%esi),%es:(%edi)
	dec     %ecx
	jmp     MemCpy_1
MemCpy_2:
	mov     8(%ebp), %eax
	pop     %ecx
	pop     %edi
	pop     %esi
	mov     %ebp, %esp
	pop     %ebp
	ret

