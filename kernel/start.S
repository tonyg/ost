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
	.global panic

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
	movl	$0x20, %eax
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
