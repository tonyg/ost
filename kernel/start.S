	/* -*- fundamental -*- */

	.text

#define ASSEMBLY
#include <multiboot.h>

#define LOADADDR	0x00100000

	.global multiboot_header		/* exports */
	.global	realstart			/* export, to keep ld happy */

	.global pml4_base, pdp_base, pd_base, pt_base

realstart:
start:
	.code32

	cli					/* paranoia? */

	lgdt	gdtaddr
	jmp	$0x08, $1f
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
	movl	$pml4_base, %edi
	cld
	rep
	stosl

	/* Fill in PML4. */
	movl	$(pdp_base + 0x7), %eax
	movl	%eax, pml4_base
	movl	%eax, pml4_base + 2048

	/* Fill in PDP. */
	movl	$(pd_base + 0x7), %eax
	movl	%eax, pdp_base

	/* Fill in PD. */
	movl	$(pt_base + 0x7), %eax
	movl	%eax, pd_base

	/* Fill in PT. */
	movl	$0x87, %eax
	movl	$pt_base, %edi
	movl	$512, %ecx

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
	mov	$pml4_base, %eax
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
	jmp    	$0x18, $start_long_mode
	/* At this point, we're truly in long mode. Adjust assembler syntax to match. */
	.code64
	.align	16, 0
start_long_mode:

	/* Set the other segments. */
	movl	$0x20, %eax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs

	movw	%ax, %ss			/* SS is ignored in long mode, so
		      				   it doesn't matter that SS and RSP
						   are set at different times. */
	movq	$stack_top, %rsp

	lidt	idtaddr

2:	incw	0xb8000
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
	.long	multiboot_header
	.long	LOADADDR
	.long	_edata
	.long	_end
	.long	realstart
	.long	MULTIBOOT_MODE_TYPE_TEXT
	.long	80
	.long	25
	.long	0

	/* .org	0x1000 */
	.align	8, 0

idtaddr:
	.word	0x07ff				/* limit: 256 entries * 8 bytes - 1 */
	.long	idt
	.long	0				/* we load IDT in long mode, so need 8-byte ptr */

gdtaddr:
	.word	0x07ff				/* limit: 256 entries * 8 bytes - 1 */
	.long	gdt

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

	/* TODO */

	/* In total, 5 descriptors defined so far. */
	/* Fill up the rest of the 256 slots. */

	.fill	251, 8, 0

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
