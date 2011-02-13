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
	movq	$trap00, %rbx
	movq	$0x00, %rdi
	call	setup_idt_slot
	movq	$trap01, %rbx
	movq	$0x01, %rdi
	call	setup_idt_slot
	movq	$trap02, %rbx
	movq	$0x02, %rdi
	call	setup_idt_slot
	movq	$trap03, %rbx
	movq	$0x03, %rdi
	call	setup_idt_slot
	movq	$trap04, %rbx
	movq	$0x04, %rdi
	call	setup_idt_slot
	movq	$trap05, %rbx
	movq	$0x05, %rdi
	call	setup_idt_slot
	movq	$trap06, %rbx
	movq	$0x06, %rdi
	call	setup_idt_slot
	movq	$trap07, %rbx
	movq	$0x07, %rdi
	call	setup_idt_slot
	movq	$trap08, %rbx
	movq	$0x08, %rdi
	call	setup_idt_slot
	movq	$trap09, %rbx
	movq	$0x09, %rdi
	call	setup_idt_slot
	movq	$trap0a, %rbx
	movq	$0x0a, %rdi
	call	setup_idt_slot
	movq	$trap0b, %rbx
	movq	$0x0b, %rdi
	call	setup_idt_slot
	movq	$trap0c, %rbx
	movq	$0x0c, %rdi
	call	setup_idt_slot
	movq	$trap0d, %rbx
	movq	$0x0d, %rdi
	call	setup_idt_slot
	movq	$trap0e, %rbx
	movq	$0x0e, %rdi
	call	setup_idt_slot
	movq	$trap0f, %rbx
	movq	$0x0f, %rdi
	call	setup_idt_slot

	movq	$trap10, %rbx
	movq	$0x10, %rdi
	call	setup_idt_slot
	movq	$trap11, %rbx
	movq	$0x11, %rdi
	call	setup_idt_slot
	movq	$trap12, %rbx
	movq	$0x12, %rdi
	call	setup_idt_slot
	movq	$trap13, %rbx
	movq	$0x13, %rdi
	call	setup_idt_slot
	movq	$trap14, %rbx
	movq	$0x14, %rdi
	call	setup_idt_slot
	movq	$trap15, %rbx
	movq	$0x15, %rdi
	call	setup_idt_slot
	movq	$trap16, %rbx
	movq	$0x16, %rdi
	call	setup_idt_slot
	movq	$trap17, %rbx
	movq	$0x17, %rdi
	call	setup_idt_slot
	movq	$trap18, %rbx
	movq	$0x18, %rdi
	call	setup_idt_slot
	movq	$trap19, %rbx
	movq	$0x19, %rdi
	call	setup_idt_slot
	movq	$trap1a, %rbx
	movq	$0x1a, %rdi
	call	setup_idt_slot
	movq	$trap1b, %rbx
	movq	$0x1b, %rdi
	call	setup_idt_slot
	movq	$trap1c, %rbx
	movq	$0x1c, %rdi
	call	setup_idt_slot
	movq	$trap1d, %rbx
	movq	$0x1d, %rdi
	call	setup_idt_slot
	movq	$trap1e, %rbx
	movq	$0x1e, %rdi
	call	setup_idt_slot
	movq	$trap1f, %rbx
	movq	$0x1f, %rdi
	call	setup_idt_slot

	lidt	idtaddr

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
	movw	$0x8e00, %ax
	movq	%rax, 4(%rdi)
	movl	$0x00180000, %eax
	movw	%bx, %ax
	movl	%eax, (%rdi)
	ret

trap00:	movq	$0x00, %rax
	jmp	generic_trap
trap01:	movq	$0x01, %rax
	jmp	generic_trap
trap02:	movq	$0x02, %rax
	jmp	generic_trap
trap03:	movq	$0x03, %rax
	jmp	generic_trap
trap04:	movq	$0x04, %rax
	jmp	generic_trap
trap05:	movq	$0x05, %rax
	jmp	generic_trap
trap06:	movq	$0x06, %rax
	jmp	generic_trap
trap07:	movq	$0x07, %rax
	jmp	generic_trap
trap08:	movq	$0x08, %rax
	jmp	generic_trap
trap09:	movq	$0x09, %rax
	jmp	generic_trap
trap0a:	movq	$0x0a, %rax
	jmp	generic_trap
trap0b:	movq	$0x0b, %rax
	jmp	generic_trap
trap0c:	movq	$0x0c, %rax
	jmp	generic_trap
trap0d:	movq	$0x0d, %rax
	jmp	generic_trap
trap0e:	movq	$0x0e, %rax
	jmp	generic_trap
trap0f:	movq	$0x0f, %rax
	jmp	generic_trap
trap10:	movq	$0x10, %rax
	jmp	generic_trap
trap11:	movq	$0x11, %rax
	jmp	generic_trap
trap12:	movq	$0x12, %rax
	jmp	generic_trap
trap13:	movq	$0x13, %rax
	jmp	generic_trap
trap14:	movq	$0x14, %rax
	jmp	generic_trap
trap15:	movq	$0x15, %rax
	jmp	generic_trap
trap16:	movq	$0x16, %rax
	jmp	generic_trap
trap17:	movq	$0x17, %rax
	jmp	generic_trap
trap18:	movq	$0x18, %rax
	jmp	generic_trap
trap19:	movq	$0x19, %rax
	jmp	generic_trap
trap1a:	movq	$0x1a, %rax
	jmp	generic_trap
trap1b:	movq	$0x1b, %rax
	jmp	generic_trap
trap1c:	movq	$0x1c, %rax
	jmp	generic_trap
trap1d:	movq	$0x1d, %rax
	jmp	generic_trap
trap1e:	movq	$0x1e, %rax
	jmp	generic_trap
trap1f:	movq	$0x1f, %rax
	jmp	generic_trap

generic_trap:
	movq	%rax, %rbx
	shlq	$1, %rax
	addq	$(UPPER_2GB + 0xb8000 + (80 * 24 * 2)), %rax
	addb	$0x30, %bl
	movb	$0x0a, %bh
	movw	%bx, 2(%rax)
1:	incw	(%rax)
	jmp	1b

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
