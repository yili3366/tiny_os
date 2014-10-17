.include "sconst.inc"

.data
DATA:
clock_int_msg:	.asciz	"^"

.bss
#.lcomm StackSpace,(2 * 1024)
StackSpace:
        .rept   (2048)
        .byte   0
        .endr
StackTop:

.text
.global	_start

.global	restart
.global	sys_call

.global	divide_error
.global  single_step_exception
.global  nmi
.global  breakpoint_exception
.global  overflow
.global  bounds_check
.global  inval_opcode
.global  copr_not_available
.global  double_fault
.global  copr_seg_overrun
.global  inval_tss
.global  segment_not_present
.global  stack_exception
.global  general_protection
.global  page_fault
.global  copr_error

.global  hwint00
.global  hwint01
.global  hwint02
.global  hwint03
.global  hwint04
.global  hwint05
.global  hwint06
.global  hwint07
.global  hwint08
.global  hwint09
.global  hwint10
.global  hwint11
.global  hwint12
.global  hwint13
.global  hwint14
.global  hwint15

_start:
	mov	$(StackTop),%esp

	movl	$0, (disp_pos)
	sgdt	(gdt_ptr)
	call	cstart		#change gdt
	lgdt	(gdt_ptr)	#new gdt

	lidt	(idt_ptr)

	ljmp	$(SELECTOR_KERNEL_CS), $(csinit)
csinit:
	xor	%eax,%eax
	mov	$(SELECTOR_TSS),%ax
	ltr	%ax

	jmp	kernel_main

# Interrupt and exception -hardware interrupt
.macro	hwint_master	_1
	call	save

	inb	$(INT_M_CTLMASK),%al
	orb	$(1 << (\_1)),%al
	outb	%al,$(INT_M_CTLMASK)

        movb    $(EOI), %al
        outb    %al, $(INT_M_CTL)

	sti
	push	(\_1)
#	push	$(\_1)
	call	*(irq_table + 4 * (\_1))
#	leal	irq_table,%eax
#	call	*(4 * (\_1))(%eax)
	pop	%ecx
	cli

	inb	$(INT_M_CTLMASK),%al
	andb	$~(1 << (\_1)),%al
	outb	%al,$(INT_M_CTLMASK)
	ret
.endm

.align	16
hwint00:
	hwint_master	0	#clock
.align	16
hwint01:
	hwint_master	1	#keyboard
.align	16
hwint02:
	hwint_master	2	#cascade
.align	16
hwint03:
	hwint_master	3	#second serial
.align	16
hwint04:
	hwint_master	4	#first serial
.align	16
hwint05:
	hwint_master	5	#XT winchester
.align	16
hwint06:
	hwint_master	6	#floppy
.align	16
hwint07:
	hwint_master	7	#printer

.macro	hwint_slave	_1
	call	save
	in	$(INT_S_CTLMASK),%al		#mask
	or	$(1 << (\_1 - 8)),%al		#current
	out	%al,$(INT_S_CTLMASK)		#intterupt
	mov	$(EOI),%al			#set eoi of
	out	%al,$(INT_M_CTL)		#master
	nop					#set eoi of
	out	%al,$(INT_S_CTL)		#slave

	sti

	push	(\_1)
	call	*(irq_table + 4 * (\_1))
	pop	%ecx
	cli
	in	$(INT_S_CTLMASK),%al
	and	$~(1 << ((\_1) - 8)),%al
	out	%al,$(INT_S_CTLMASK)
	ret
.endm

.align	16
hwint08:
	hwint_slave	8	#realtiem clock
.align	16
hwint09:
	hwint_slave	9
.align	16
hwint10:
	hwint_slave	10
.align	16
hwint11:
	hwint_slave	11
.align	16
hwint12:
	hwint_slave	12
.align	16
hwint13:
	hwint_slave	13	#FPU exception
.align	16
hwint14:
	hwint_slave	14	#AT winchester 
.align	16
hwint15:
	hwint_slave	15

# Interrupt and exception -exception
divide_error:
	push	$0xFFFFFFFF	# no err code
	push	$0		# vector_no	= 0
	jmp	exception
single_step_exception:
	push	$0xFFFFFFFF	# no err code
	push	$1		# vector_no	= 1
	jmp	exception
nmi:
	push	$0xFFFFFFFF	# no err code
	push	$2		# vector_no	= 2
	jmp	exception
breakpoint_exception:
	push	$0xFFFFFFFF	# no err code
	push	$3		# vector_no	= 3
	jmp	exception
overflow:
	push	$0xFFFFFFFF	# no err code
	push	$4		# vector_no	= 4
	jmp	exception
bounds_check:
	push	$0xFFFFFFFF	# no err code
	push	$5		# vector_no	= 5
	jmp	exception
inval_opcode:
	push	$0xFFFFFFFF	# no err code
	push	$6		# vector_no	= 6
	jmp	exception
copr_not_available:
	push	$0xFFFFFFFF	# no err code
	push	$7		# vector_no	= 7
	jmp	exception
double_fault:
	push	$8		# vector_no	= 8
	jmp	exception
copr_seg_overrun:
	push	$0xFFFFFFFF	# no err code
	push	$9		# vector_no	= 9
	jmp	exception
inval_tss:
	push	$10		# vector_no	= A
	jmp	exception
segment_not_present:
	push	$11		# vector_no	= B
	jmp	exception
stack_exception:
	push	$12		# vector_no	= C
	jmp	exception
general_protection:
	push	$13		# vector_no	= D
	jmp	exception
page_fault:
	push	$14		# vector_no	= E
	jmp	exception
copr_error:
	push	$0xFFFFFFFF	# no err code
	push	$16		# vector_no	= 10h
	jmp	exception

exception:
	call	exception_handler
	add	$8,%esp		# Stack top point to EIP，from top to buttom：
				#EIP、CS、EFLAGS
	hlt
#-------------------------------------------------------------------------------
#				save	
#-------------------------------------------------------------------------------
save:
	pushal
	push	%ds
	push	%es
	push	%fs
	push	%gs

	## !!!Note，from here to `mov esp, StackTop'，it now allowed to use directive - push/pop, 
	## Because the current esp point to certain position of proc_table ，'push' will destroy the PCB！

	mov	%edx,%esi	# Save edx，because edx saved the parameter of sys_call
				#（Not use stack，but esi）

	mov	%ss,%dx
	mov	%dx,%ds
	mov	%dx,%es
	mov	%dx,%fs

	mov	%esi,%edx	#Restore edx

	mov	%esp,%esi			# esi= start addr of PCB

	incl	(k_reenter)			#k_reenter++;
	cmpl	$0,(k_reenter)			#if( k_reenter ==0 )
	jne	save_1				#{
	mov	$(StackTop),%esp		#move	StackTop,esp <k_stack
	push	$(restart)			#push 	$restart
	jmp	*(RETADR - P_STACKBASE)(%esi)	#return;
save_1:						#}else{
	push	$(restart_reenter)		#push $(restart_reenter)
	jmp	*(RETADR - P_STACKBASE)(%esi)	#return;
#-------------------------------------------------------------------------------
#				sys_call
#-------------------------------------------------------------------------------
sys_call:
	call	save
	
	sti
	push	%esi

	pushl	(p_proc_ready)
	push	%edx
	push	%ecx
	push	%ebx
	call	*(sys_call_table)(,%eax,4)
	add	$(4*4),%esp
	
	pop	%esi
	mov	%eax,(EAXREG - P_STACKBASE)(%esi)
	cli

	ret

#-------------------------------------------------------------------------------
#				restart
#-------------------------------------------------------------------------------
restart:
	mov	(p_proc_ready),%esp
	lldt	P_LDT_SEL(%esp)
	leal	P_STACKTOP(%esp),%eax
	movl	%eax,(TSS3_S_SP0+tss)
restart_reenter:
	decl	(k_reenter)	
	pop	%gs
	pop	%fs
	pop	%es
	pop	%ds
	popal

	add	$4,%esp
	
	iret

