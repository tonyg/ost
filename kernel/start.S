	/* -*- fundamental -*- */

	.text

#define ASSEMBLY
#include <multiboot.h>

#define LOADADDR		0x00100000
#define UPPER_2GB		0xFFFFFFFF80000000
#define R(x)			((x) - UPPER_2GB)

	.global multiboot_header		/* exports */
	.global	realstart			/* export, to keep ld happy */

	.global pml4_base, pdp_base, pd_base, pt_base

realstart:
start:
	.code32

	cli					/* paranoia? */

	lgdt	R(gdtaddr)
	jmp	$0x08, $(R(1f))
1:

	/* Load the data segments. Ignore stack for now. */
	movl	$0x10, %eax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs

	/* TODO: save multiboot info from registers to memory here */

	/* Long mode needs page tables. *rolls up sleeves* */

	/* Zero out page table memory first. */
	movl	$((page_tables_end - pml4_base) / 4), %ecx
	xorl	%eax, %eax
	movl	$(R(pml4_base)), %edi
	cld
	rep
	stosl

	/* Fill in PML4. */
	movl	$(R(pdp_base + 0x7)), %eax
	movl	%eax, R(pml4_base)
	movl	%eax, R(pml4_base) + (511 * 8)	/* Notice this! This reuses the PDP table at
						   index 511, mapping us into the high 512GB. */

	/* Fill in PDP. */
	movl	$(R(pd_base + 0x7)), %eax
	movl	%eax, R(pdp_base)
	movl	%eax, R(pdp_base) + (510 * 8)	/* ... and this maps us into -2GB.
						   We jump up there later. */

	/* Fill in PD. */
	movl	$(R(pt_base + 0x7)), %eax
	movl	%eax, R(pd_base)

	/* Fill in PT. */
	movl	$0x87, %eax
	movl	$(R(pt_base)), %edi
	movl	$512, %ecx

	/* At this point, the tables map virtual space as follows.
	   It's a bit weird. We'll clean it up when we unmap low
	   addresses later.

	   virtual		physical
	   0000000000000000	0000000000000000	Wanted, idmap for booting
	   00000000001fffff	00000000001fffff

	   0000ffff80000000	0000000000000000	Unwanted, consequence of
	   0000ffff801fffff	00000000001fffff	bootstrap mapping technique

	   ffff800000000000	0000000000000000	Unwanted, consequence of   
	   ffff8000001fffff	00000000001fffff	bootstrap mapping technique

	   ffffffff80000000	0000000000000000	Wanted, upper 2GB. Our
	   ffffffff801fffff	00000000001fffff	"native" addressing.
	*/

1:	movl	%eax, (%edi)
	addl	$8, %edi
	addl	$0x1000, %eax
	decl	%ecx
	jnz	1b

	/* First, we need PAE mode. */
	mov	%cr4, %eax
	orl	$(1<<5), %eax
	mov	%eax, %cr4

	/* Set the PML4 pointer. */
	mov	$(R(pml4_base)), %eax
	mov	%eax, %cr3

	/* Enable long mode. */
	mov	$0xc0000080, %ecx
	rdmsr
	orl	$0x100, %eax
	wrmsr

	/* Enable paging. */
	mov	%cr0, %eax
	orl	$0x80000000, %eax
	mov	%eax, %cr0

	/* Far jump to get into a 64-bit code segment. */
	jmp	$0x18, $(R(start_long_mode))
	.align	16, 0
start_long_mode:
	/* ============================================================ */
	/* At this point, we're truly in long mode. Adjust assembler syntax to match. */
	.code64

	/* Set the other segments. */
	movw	$0x20, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs

	/* Reload GDT using upper-2GB virtual address. */
	movq	$UPPER_2GB, %rbx
	addq	%rbx, gdtaddr_baseptr
	lgdt	gdtaddr

	movw	%ax, %ss			/* SS is ignored in long mode, so
						   it doesn't matter that SS and RSP
						   are set at different times. */
	movq	$stack_top, %rsp

	/* Jump to the same code, but in the top 2GB of virtual address space. */
	pushq	$0x18
	pushq	$1f
	lretq
1:

	/* Update the GDT's TSS entry to point to the correct piece of memory. */
	movq	$tss_base, %rax
	movw	%ax, tss_baseptr_low16
	shrq	$16, %rax
	movb	%al, tss_baseptr_mid16_low8
	movb	%ah, tss_baseptr_mid16_high8
	shrq	$16, %rax
	movl	%eax, tss_baseptr_high32

	/* Actually load the TSS into the TR. */
	movq	$0x28, %rax
	ltr	%ax

	/* Fill IDT slots */
#define FILL_IDT_SLOT(nn) \
	movq	$trap##nn, %rbx; \
	movq	$0x##nn, %rdi; \
	call	setup_idt_slot

	FILL_IDT_SLOT(00)
	FILL_IDT_SLOT(01)
	FILL_IDT_SLOT(02)
	FILL_IDT_SLOT(03)
	FILL_IDT_SLOT(04)
	FILL_IDT_SLOT(05)
	FILL_IDT_SLOT(06)
	FILL_IDT_SLOT(07)
	FILL_IDT_SLOT(08)
	FILL_IDT_SLOT(09)
	FILL_IDT_SLOT(0a)
	FILL_IDT_SLOT(0b)
	FILL_IDT_SLOT(0c)
	FILL_IDT_SLOT(0d)
	FILL_IDT_SLOT(0e)
	FILL_IDT_SLOT(0f)
	FILL_IDT_SLOT(10)
	FILL_IDT_SLOT(11)
	FILL_IDT_SLOT(12)
	FILL_IDT_SLOT(13)
	FILL_IDT_SLOT(14)
	FILL_IDT_SLOT(15)
	FILL_IDT_SLOT(16)
	FILL_IDT_SLOT(17)
	FILL_IDT_SLOT(18)
	FILL_IDT_SLOT(19)
	FILL_IDT_SLOT(1a)
	FILL_IDT_SLOT(1b)
	FILL_IDT_SLOT(1c)
	FILL_IDT_SLOT(1d)
	FILL_IDT_SLOT(1e)
	FILL_IDT_SLOT(1f)
	FILL_IDT_SLOT(20)
	FILL_IDT_SLOT(21)
	FILL_IDT_SLOT(22)
	FILL_IDT_SLOT(23)
	FILL_IDT_SLOT(24)
	FILL_IDT_SLOT(25)
	FILL_IDT_SLOT(26)
	FILL_IDT_SLOT(27)
	FILL_IDT_SLOT(28)
	FILL_IDT_SLOT(29)
	FILL_IDT_SLOT(2a)
	FILL_IDT_SLOT(2b)
	FILL_IDT_SLOT(2c)
	FILL_IDT_SLOT(2d)
	FILL_IDT_SLOT(2e)
	FILL_IDT_SLOT(2f)

	lidt	idtaddr

	/* Now that we have installed handlers for the various interrupts,
	   program the Programmable Interrupt Controller to deliver them
	   to the correct interrupt vector slots. */
	movw	$0x20, %dx			/* "PIC0, accept config!" */
	movb	$0x11, %al
	outb	%al, %dx

	movw	$0xa0, %dx			/* "PIC1, accept config!" */
	movb	$0x11, %al
	outb	%al, %dx

	movw	$0x21, %dx			/* "PIC0, use vector offset 0x20!" */
	movb	$0x20, %al
	outb	%al, %dx

	movw	$0xa1, %dx			/* "PIC1, use vector offset 0x28!" */
	movb	$0x28, %al
	outb	%al, %dx

	movw	$0x21, %dx			/* "PIC0, be master!" */
	movb	$0x04, %al
	outb	%al, %dx

	movw	$0xa1, %dx			/* "PIC1, be slave!" */
	movb	$0x02, %al
	outb	%al, %dx

	movw	$0x21, %dx			/* "PIC0, use 8086 mode!" */
	movb	$0x01, %al
	outb	%al, %dx

	movw	$0xa1, %dx			/* "PIC1, use 8086 mode!" */
	movb	$0x01, %al
	outb	%al, %dx

	movw	$0x21, %dx			/* "PIC0, unmask all!" */
	movb	$0x00, %al
	outb	%al, %dx

	movw	$0xa1, %dx			/* "PIC1, unmask all!" */
	movb	$0x00, %al
	outb	%al, %dx

	movw	$0x70, %dx			/* Reenable NMI. */
	movb	$0x00, %al
	outb	%al, %dx

	/* Tell the clock to interrupt us at 100Hz. The clock divisor
	   is 1193182, so at 100Hz, that makes the period 11932 = 0x2e9c. */
	movw	$0x43, %dx			/* Send CLOCK_MODE to TIMER0_SETUP. */
	movb	$0x34, %al
	outb	%al, %dx
	movw	$0x40, %dx			/* Send low byte of period. */
	movb	$0x9c, %al
	outb	%al, %dx
	movw	$0x40, %dx			/* Send high byte of period. */
	movb	$0x2e, %al
	outb	%al, %dx

	sti

	movq	$(UPPER_2GB + 0xb8002), %rax
2:	incw	0xb8000
	incw	(%rax)
	jmp	2b

/* Here's a handy spot for the Multboot header. */
#define MULTIBOOT_FLAGS		(MULTIBOOT_HEADER_FLAG_PAGEALIGN_MODULES | \
				 MULTIBOOT_HEADER_FLAG_MEMORY_INFO | \
				 MULTIBOOT_HEADER_FLAG_VIDEO_INFO | \
				 MULTIBOOT_HEADER_FLAG_EXPLICIT_LOAD_ADDRESS)
	.align	4, 0
multiboot_header:
	.long	MULTIBOOT_MAGIC
	.long	MULTIBOOT_FLAGS
	.long	COMPUTE_MULTIBOOT_CHECKSUM(MULTIBOOT_FLAGS)
	.long	R(multiboot_header)
	.long	LOADADDR
	.long	R(_edata)
	.long	R(_end)
	.long	R(realstart)
	.long	MULTIBOOT_MODE_TYPE_TEXT
	.long	80
	.long	25
	.long	0

setup_idt_slot:
	shlq	$0x04, %rdi
	addq	$idt, %rdi
	movq	%rbx, %rax
	movw	$0x8e00, %ax			/* Note for now we use INTR instead of TRAP */
			 			/* (put 0x8f00 for TRAP) */
	movq	%rax, 4(%rdi)
	movl	$0x00180000, %eax
	movw	%bx, %ax
	movl	%eax, (%rdi)
	ret

#define DEFTRAP(nn) \
	trap##nn: \
		movq	$0x##nn, %rax; \
		jmp	generic_trap

#define DEFINTH(nn) \
	trap##nn: \
		pushq	%rax; \
		movq	$0x##nn, %rax; \
		jmp	generic_interrupt

	DEFTRAP(00)
	DEFTRAP(01)
	DEFTRAP(02)
	DEFTRAP(03)
	DEFTRAP(04)
	DEFTRAP(05)
	DEFTRAP(06)
	DEFTRAP(07)
	DEFTRAP(08)
	DEFTRAP(09)
	DEFTRAP(0a)
	DEFTRAP(0b)
	DEFTRAP(0c)
	DEFTRAP(0d)
	DEFTRAP(0e)
	DEFTRAP(0f)
	DEFTRAP(10)
	DEFTRAP(11)
	DEFTRAP(12)
	DEFTRAP(13)
	DEFTRAP(14)
	DEFTRAP(15)
	DEFTRAP(16)
	DEFTRAP(17)
	DEFTRAP(18)
	DEFTRAP(19)
	DEFTRAP(1a)
	DEFTRAP(1b)
	DEFTRAP(1c)
	DEFTRAP(1d)
	DEFTRAP(1e)
	DEFTRAP(1f)

	DEFINTH(20)
	DEFINTH(21)
	DEFINTH(22)
	DEFINTH(23)
	DEFINTH(24)
	DEFINTH(25)
	DEFINTH(26)
	DEFINTH(27)
	DEFINTH(28)
	DEFINTH(29)
	DEFINTH(2a)
	DEFINTH(2b)
	DEFINTH(2c)
	DEFINTH(2d)
	DEFINTH(2e)
	DEFINTH(2f)

generic_trap:
	movq	%rax, %rbx
	shlq	$1, %rax
	addq	$(UPPER_2GB + 0xb8000 + (80 * 24 * 2)), %rax
	addb	$0x30, %bl
	movb	$0x0a, %bh
	movw	%bx, 2(%rax)
1:	incw	(%rax)
	jmp	1b

generic_interrupt:
	pushq	%rbx
	pushq	%rcx
	pushq	%rdx

	movq	%rax, %rbx
	movq	%rax, %rcx

	shlq	$2, %rax
	addq	$(UPPER_2GB + 0xb8000 + (80 * 24 * 2)), %rax
	addb	$0x30, %bl
	movb	$0x0a, %bh
	movw	%bx, 2(%rax)
	incw	(%rax)

	movw	$0x20, %dx
	movb	$0x20, %al
	outb	%al, %dx
	cmpb	%cl, 8
	jl	1f
	movw	$0xa0, %dx
	movb	$0x20, %al
	outb	%al, %dx
1:

	popq	%rdx
	popq	%rcx
	popq	%rbx
	popq	%rax
	iretq

	.data

	.align	8, 0

idtaddr:
	.word	0x07ff				/* limit: 256 entries * 8 bytes - 1 */
	.quad	idt

gdtaddr:
	.word	0x07ff				/* limit: 256 entries * 8 bytes - 1 */
gdtaddr_baseptr:
	.quad	R(gdt)				/* Start off with 0-based offset. Later
						   we patch this address and reload GDT
						   with pointer into upper-2GB space. */

	.align	4, 0				/* Align to doubleword boundary */

idt:
	.fill	256, 8, 0

gdt:	.word	0, 0, 0, 0			/* Dummy. */

	/* The next two descriptors are the same as the ones set up by GRUB during the boot
	   process. They should presumably stick around until we transition to the 64-bit
	   descriptors so that we have a coherent CS and DS to work from! */

	.word	0xffff				/* limit 15-0	- This is 32-bit CS. */
	.word	0x0000				/* base 15-0 */
	.word	0x9a00				/* present, DPL 0, readable code, base 23-16 */
	.word	0x00cf				/* base 31-24, gran. 4096, 386, limit 19-16 */

	.word	0xffff				/* limit 15-0	- This is 32-bit DS. */
	.word	0x0000				/* base 15-0 */
	.word	0x9200				/* present, DPL 0, writeable data, base 23-16 */
	.word	0x00cf				/* base 31-24, gran. 4096, 386, limit 19-16 */

	/* These two are for long mode. */

	.word	0xffff				/* limit 15-0	- This is 64-bit CS. */
	.word	0x0000				/* base 15-0 */
	.word	0x9a00				/* present, DPL 0, readable code, base 23-16 */
	.word	0x002f				/* base 31-24, long mode, limit 19-16 */

	.word	0xffff				/* limit 15-0	- This is 64-bit DS. */
	.word	0x0000				/* base 15-0 */
	.word	0x9200				/* present, DPL 0, writeable data, base 23-16 */
	.word	0x002f				/* base 31-24, long mode, limit 19-16 */

	/* TSS descriptor takes two slots. */

	.word	(tss_top - tss_base - 1)	/* limit 15-0   - This is 64-bit TSS. */
tss_baseptr_low16:
	.word	0x0000				/* base 15-0 */
tss_baseptr_mid16_low8:
	.byte	0x00				/* base 23-16 */
	.byte	0x89				/* present, DPL 0, available TSS */
	.byte	0x00				/* granularity 0, limit 19-16 */
tss_baseptr_mid16_high8:
	.byte	0x00				/* base 31-24 */
tss_baseptr_high32:
	.long	0x00000000			/* base 63-32 */
	.long	0x00000000			/* reserved space (we are a double-width entry) */

	/* In total, 7 descriptors defined so far. */
	/* Fill up the rest of the 256 slots. */

	.fill	(256 - 7), 8, 0

tss_base:
	.long	0x00000000			/* reserved */
	.quad	0x0000000000000000		/* rsp0 */
	.quad	0x0000000000000000		/* rsp1 */
	.quad	0x0000000000000000		/* rsp2 */
	.quad	0x0000000000000000		/* reserved */
	.quad	0x0000000000000000		/* ist1 */
	.quad	0x0000000000000000		/* ist2 */
	.quad	0x0000000000000000		/* ist3 */
	.quad	0x0000000000000000		/* ist4 */
	.quad	0x0000000000000000		/* ist5 */
	.quad	0x0000000000000000		/* ist6 */
	.quad	0x0000000000000000		/* ist7 */
	.quad	0x0000000000000000		/* reserved */
	.word	0x0000				/* reserved */
	.word	(iomap_base - tss_base)		/* io map base offset */
iomap_base:
tss_top:

	.bss
bss_base:

	.align	4096, 0				/* Align to page boundary. */

stack_base:
	.fill	4096, 1, 0
stack_top:

pml4_base:
	.fill	512, 8, 0

pdp_base:
	.fill	512, 8, 0

pd_base:
	.fill	512, 8, 0

pt_base:
	.fill	512, 8, 0

page_tables_end:
