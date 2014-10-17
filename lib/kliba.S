# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#                              klib.S	2010,7,7
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

.include "sconst.inc"
.text

.global	disp_str
.global disp_color_str
.global out_byte
.global in_byte
.global	enable_irq
.global	disable_irq
.global enable_int
.global disable_int
.global port_read
.global port_write
.global glitter


#-------------------------------------------------------------------------
#			void disp_str(char * pInfo);
#-------------------------------------------------------------------------
disp_str:
	pushl   %ebp
	movl    %esp, %ebp

	pushl	%ebx
	pushl	%esi
	pushl	%edi

	movl    8(%ebp), %esi
	movl    (disp_pos), %edi
	movb    $0xF, %ah
disp_str_1:
	lodsb
	testb   %al, %al
	jz      disp_str_2
	cmpb    $0xA, %al		#carriage return
	jnz     disp_str_3
	pushl   %eax
	movl    %edi, %eax
	movb    $160, %bl
	divb    %bl
	andl    $0xFF, %eax
	incl    %eax
	movb    $160, %bl
	mulb	%bl
	movl    %eax, %edi
	popl    %eax
	jmp     disp_str_1

disp_str_3:
	movw    %ax, %gs:(%edi)
	addl    $2, %edi
	jmp     disp_str_1

disp_str_2:
	movl    %edi, (disp_pos)

	popl	%edi
	popl	%esi
	popl	%ebx

#	movl	%ebp,%esp
	popl    %ebp

	ret
#-------------------------------------------------------------------------
#		void disp_color_str(char * info, int color);
#-------------------------------------------------------------------------
disp_color_str:
	pushl   %ebp
	movl    %esp, %ebp

	pushl	%ebx
	pushl	%esi
	pushl	%edi

	movl    8(%ebp), %esi		#info
	movl    (disp_pos), %edi
	movb    12(%ebp), %ah		#color
_1:
	lodsb
	testb   %al, %al
	jz      _2
	cmpb    $0xA, %al		#carriage return
	jnz     _3
	pushl   %eax
	movl    %edi, %eax
	movb    $160, %bl
	divb    %bl
	andl    $0xFF, %eax
	incl    %eax
	movb    $160, %bl
	mul	%bl
	movl    %eax, %edi
	popl    %eax
	jmp     _1

_3:
	movw    %ax, %gs:(%edi)
	addl    $2, %edi
	jmp     _1

_2:
	movl    %edi, (disp_pos)

	popl	%edi
	popl	%esi
	popl	%ebx

#	movl	%ebp,%esp
	popl    %ebp

	ret

#-------------------------------------------------------------------------
#		void out_byte(u16 port, u8 value);
#-------------------------------------------------------------------------
out_byte:
	mov	4(%esp),%edx		#port
	mov	8(%esp),%al		#value
	out	%al,%dx
	nop
	nop
	ret
#-------------------------------------------------------------------------
#		u8 in_byte(u16 port);
#-------------------------------------------------------------------------
in_byte:
	mov	4(%esp),%edx		#port
	xor	%eax,%eax
	in	%dx,%al
	nop
	nop
	ret	
#-------------------------------------------------------------------------
#		void disable_irq(int irq);
#-------------------------------------------------------------------------
# Disable an interrupt request line by setting an 8259 bit.
# Equivalent code:
#       if(irq < 8)
#               out_byte(INT_M_CTLMASK, in_byte(INT_M_CTLMASK) | (1 << irq));
#       else
#               out_byte(INT_S_CTLMASK, in_byte(INT_S_CTLMASK) | (1 << irq));
disable_irq:
	mov	4(%esp),%ecx		#irq
	pushf
	cli
	mov	$1,%ah
	rol	%cl,%ah			#ah = (1 << (irq % 8))
	cmp	$8,%cl
	jae	disable_8		#disable irq >= 8 at the slave 8259
disable_0:
	in	$(INT_M_CTLMASK),%al
	test	%ah,%al
	jnz	dis_already		#already disabled?
	or	%ah,%al
	out	%al,$(INT_M_CTLMASK)	#set bit at master 8259
	popf
	mov	$1,%eax			#disabled by this function
	ret
disable_8:
	in	$(INT_S_CTLMASK),%al
	test	%ah,%al
	jnz	dis_already		#already disabled?
	or	%ah,%al
	out	%al,$(INT_S_CTLMASK)	#set bit at slave 8259
	popf
	mov	$1,%eax
	ret
dis_already:
	popf
	xor	%eax,%eax
	ret
#-------------------------------------------------------------------------
#		void 	enable_irq(int irq);
#-------------------------------------------------------------------------
# Disable an interrupt request line by setting an 8259 bit.
# Equivalent code:
#       if(irq < 8)
#               out_byte(INT_M_CTLMASK, in_byte(INT_M_CTLMASK) | ~(1 << irq));
#       else
#               out_byte(INT_S_CTLMASK, in_byte(INT_S_CTLMASK) | ~(1 << irq));
enable_irq:
	mov	4(%esp),%ecx		#irq
	pushf
	cli
	mov	$~1,%ah
	rol	%cl,%ah			#ah = ~(1 << (irq % 8))
	cmp	$8,%cl
	jae	enable_8		#enable irq >= 8 at the slave 8259
enable_0:
	in	$(INT_M_CTLMASK),%al
	and	%ah,%al
	out	%al,$(INT_M_CTLMASK)	#clear bit at master 8259
	popf
	ret
enable_8:
	in	$(INT_S_CTLMASK),%al
	and	%ah,%al
	out	%al,$(INT_S_CTLMASK)	#clear bit at slave 8259
	popf
	ret

#-------------------------------------------------------------------------------
#		void	disable_int();
#-------------------------------------------------------------------------------
disable_int:
	cli
	ret

#-------------------------------------------------------------------------------
#		void	enable_int();
#-------------------------------------------------------------------------------
enable_int:
	sti
	ret
#--------------------------------------------------------------------------------
#               void    port_read(u16 port, void* buf, int n);
#--------------------------------------------------------------------------------
port_read:
        mov     4(%esp),%edx
        mov     8(%esp),%edi
        mov     12(%esp),%ecx
	shr     $1,%ecx
        cld
        rep     
	insw	
        ret
#--------------------------------------------------------------------------------
#               void    port_write(u16 port, void* buf, int n);
#--------------------------------------------------------------------------------
port_write:
        mov     4(%esp),%edx
        mov     8(%esp),%esi
        mov     12(%esp),%ecx
	shr     $1,%ecx
        cld
        rep     
	outsw	
        ret

#--------------------------------------------------------------------------------
#               void    glitter(int row, int col);
#--------------------------------------------------------------------------------
glitter:
        push    %eax
        push    %ebx
        push    %edx

        mov     current_char,%eax
        inc     %eax
        cmp     _strlen,%eax
        je      1f
        jmp     2f
1:
        xor     %eax,%eax
2:
        mov     %eax,current_char
        movb    glitter_str(%eax),%dl
        
        xor     %eax,%eax
        mov     16(%esp),%al            #row
        mov     line_width,%bl
        mul     %bl                     #ax <- row * 80
        mov     20(%esp),%bx            #col
        add     %bx,%ax
        shl     $1,%ax
        movzwl  %ax,%eax

        mov     %dl,%gs:(%eax)

        inc     %eax
        movb    $4,%gs:(%eax)

        jmp     end

current_char:   .long   0
glitter_str:    .ascii  "-\|/"
                .ascii	"1234567890"
		.ascii	"abcdefghijklmnopqrstuvwxyz"
		.ascii	"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
.set    _strlen,        (. - glitter_str)
.set    line_width,     80

end:
        pop     %edx
        pop     %ebx
        pop     %eax
        ret


