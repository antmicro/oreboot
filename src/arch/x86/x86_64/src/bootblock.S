/*
 * This file is part of the coreboot project.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * This is the modern bootblock. It prepares the system for C environment runtime
 * setup. The actual setup is done by hardware-specific code.
 *
 * It provides a bootflow similar to other architectures, and thus is considered
 * to be the modern approach.
 *
 */

//
// Include the old code for reset vector and protected mode entry. That code has
// withstood the test of time. Some of the comments may help Those Who Come Later
// avoid mistakes.

// N.B. c99-style comment blocks should cover differences between coreboot and oreboot.
// Unlike coreboot, we are going to arrange the sections in bootblock
// in roughly the order they appear in memory. This first part is
// x86 entry point. Then we have assembly prolog. The protected mode enable,
// then long mode enable. The code should be written to be position-independent.
// It should not count on linker magic -- relative branches please.

//
// This code has to be 4k aligned because secondary CPUs run it
// too and the Startup IPI requires it.

// RAM is used as follows:
// 16-bit code: the stack is set to 0x2000, and a word at 0xfffe is used to
// contain an address.
// 32-bit/64-bit code:
// 0x7f000 Page Table Page Level 3 (PML3)
// 0x7e000 Page Table Page Level 4 (PML4)
// 0x7e000 Initial top of stack; x86 is pre-decrement so this location is not written.

#include "asm_defs.h"

.align 4096
.code16
.globl _start16bit
.type _start16bit, @function

	// It is safe to assume we have memory in the low 1M. For more
	// complex cases, e.g. FSP, this file will not be used.
	// N.B. This set of instructions results in the IDT, below, being aligned.
	// It's not strictly necessary but it's nice. Be careful should you change it.
_start16bit:
	cli
	/* Save the BIST result */
	movl	%eax, %ebp

	//post_code(POST_RESET_VECTOR_CORRECT)

	/* IMMEDIATELY invalidate the translation lookaside buffer (TLB) before
	 * executing any further code. Even though paging is disabled we
	 * could still get false address translations due to the TLB if we
	 * didn't invalidate it. Thanks to kmliu@sis.com.tw for this TLB fix.
	 */

	xorl	%eax, %eax
	movl	%eax, %cr3    /* Invalidate TLB*/

	// In coreboot, in the early days, there was code here to invalidate
	// the cache. That later turned out to be a problem, which the following
	// comment explains.
	/* Invalidating the cache here seems to be a bad idea on
	 * modern processors.  Don't.
	 * If we are hyperthreaded or we have multiple cores it is bad,
	 * for SMP startup.  On Opterons it causes a 5 second delay.
	 * Invalidating the cache was pure paranoia in any event.
	 */

	// gas and 16-bit have been a problem from the beginning, as explained
	// in the next comment.
	/* Note: gas handles memory addresses in 16 bit code very poorly.
	 * In particular it doesn't appear to have a directive allowing you
	 * associate a section or even an absolute offset with a segment register.
	 *
	 * This means that anything except cs:ip relative offsets are
	 * a real pain in 16 bit mode.  And explains why it is almost
	 * impossible to get gas to do lgdt correctly.
	 *
	 * One way to work around this is to have the linker do the
	 * math instead of the assembler.  This solves the very
	 * pratical problem of being able to write code that can
	 * be relocated.
	 *
	 * An lgdt call before we have memory enabled cannot be
	 * position independent, as we cannot execute a call
	 * instruction to get our current instruction pointer.
	 * So while this code is relocateable it isn't arbitrarily
	 * relocatable.
	 *
	 * The criteria for relocation have been relaxed to their
	 * utmost, so that we can use the same code for both
	 * our initial entry point and startup of the second CPU.
	 * The code assumes when executing at _start16bit that:
	 * (((cs & 0xfff) == 0) and (ip == _start16bit & 0xffff))
	 * or
	 * ((cs == anything) and (ip == 0)).
	 *
	 * The restrictions in reset16.inc mean that _start16bit initially
	 * must be loaded at or above 0xffff0000 or below 0x100000.
	 *
	 * The linker scripts computes gdtptr16_offset by simply returning
	 * the low 16 bits.  This means that the initial segment used
	 * when start is called must be 64K aligned.  This should not
	 * restrict the address as the ip address can be anything.
	 *
	 * Also load an IDT with NULL limit to prevent the 16bit IDT being used
	 * in protected mode before c_start.S sets up a 32bit IDT when entering
	 * RAM stage. In practise: CPU will shutdown on any exception.
	 * See IA32 manual Vol 3A 19.26 Interrupts.
	 */

	// we place the address of the next block on the stack.
	// which means we need a stack. Just grab this address, we
	// don't need it for long. It's page 1; we don't touch
	// page 0 for all kinds of reasons.
	// TODO: is there a PIC way to do this? Don't do so if it
	// requires linker tricks. That way lies madness.
	movw $0x2000, %sp	
	call 3f
	// null idt
	// This is aligned because of the code above; if you change the code
	// make sure it stays aligned. It may require nops.
	.word	0	/* limit */
	.long	0
	.word	0
	// This is aligned because idt is aligned and sized to a 32-bit boundary
.globl gdtptr
gdtptr:
	.word	gdt_end - gdt -1 /* compute the table limit */
	.long	gdt		 /* we know the offset */

	.align	4
gdt:
	/* selgdt 0, unused */
	.word	0x0000, 0x0000		/* dummy */
	.byte	0x00, 0x00, 0x00, 0x00

	/* selgdt 0x08, flat code segment */
	.word	0xffff, 0x0000
	.byte	0x00, 0x9b, 0xcf, 0x00 /* G=1 and 0x0f, So we get 4Gbytes
					  for limit */
	/* selgdt 0x10,flat data segment */
	.word	0xffff, 0x0000
	.byte	0x00, 0x93, 0xcf, 0x00

	/* long mode code segment. */
	.quad	0x0020980000000000		/* Long mode CS */
	/* selgdt 0x18, flat code segment (64-bit) */
	.word   0xffff, 0x0000
	.byte   0x00, 0x9b, 0xaf, 0x00

gdt_end:
.globl gdtptr16
gdtptr16:
	.word	gdt_end - gdt -1 /* compute the table limit */
	.long	gdt		 /* we know the offset */
3:
	// The stack has the absolute address of the idt. Pop into %cx.
	popw	%cx
	movw	%cx, %bx
	movw	%cs, %ax
	shlw	$4, %ax
	subw	%ax, %bx
	lidt	%cs:(%bx)
	// The gdt is at the idt plus 8
	movw	%cx, %bx
	addw    $8, %bx
	subw	%ax, %bx
	lgdtl	%cs:(%bx)

	movl	%cr0, %eax
	andl	$0x7FFAFFD1, %eax /* PG,AM,WP,NE,TS,EM,MP = 0 */
	orl	$(CD | NW | PE), %eax
	movl	%eax, %cr0

	/* Restore BIST to %eax */
	movl	%ebp, %eax

	/* Now that we are in protected mode jump to a 32 bit code segment. */
	ljmpl	$8, $__protected_start

	// TODO: should set accessed and dirty bits in gdt entries
	// so CPU does not try to write them to ROM?
.align	4
.code32
	.code32

	// we're now in 32-bit mode.
/*
 *	When we come here we are in protected mode. We expand
 *	the stack and copies the data segment from ROM to the
 *	memory.
 *
 *	After that, we call the chipset bootstrap routine that
 *	does what is left of the chipset initialization.
 *
 *	NOTE aligned to 4 so that we are sure that the prefetch
 *	cache will be reloaded.
 *
 *	In the bootblock there is already a ljmp to __protected_start and
 *	the reset vector jumps to symbol _start16bit in entry16.inc from
 *	the reset vectors's symbol which is _start. Therefore, don't
 *	expose the _start symbol for bootblock.
 */
	.align	4
__protected_start:
	// Enter here in 32-bit protected mode. Welcome to 1982.
	// First thing you have to do is get the segments to
	// sane values. Only %cs is correct when we get here.
	/* Save the BIST value */
	movl	%eax, %ebp

	//post_code(POST_ENTER_PROTECTED_MODE)

	movw	$16, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss
	movw	%ax, %fs
	movw	%ax, %gs
	// Let's try to enable cache as ram.
	// This is from: coreboot/src/cpu/intel/car/p3/cache_as_ram.S
/* SPDX-License-Identifier: GPL-2.0-only */

_cache_as_ram_setup:
cache_as_ram:
	// Don't make a habit of using this macro.
	// It's deliberately made to be inconvenient.
	// It's very dangerous. Be careful what it is in %al.
	// it's best to make sure %eax is "dead"
#define post_code_be_careful_about_al(x) movb $x, %al ; outb %al, $0x80
	//post_code_be_careful_about_al(0x20)

	/* Clear/disable fixed MTRRs */
	mov	$fixed_mtrr_list_size, %ebx
	xor	%eax, %eax
	xor	%edx, %edx

clear_fixed_mtrr:
	add	$-2, %ebx
	movzwl	fixed_mtrr_list(%ebx), %ecx
	wrmsr
	jnz	clear_fixed_mtrr

	/* Figure out how many MTRRs we have, and clear them out */
	// This is a standard definition.
	mov	$MTRR_CAP_MSR, %ecx
	rdmsr
	movzb	%al, %ebx		/* Number of variable MTRRs */
	mov	/*$MTRR_PHYS_BASE(0)*/0x200, %ecx
	xor	%eax, %eax
	xor	%edx, %edx

clear_var_mtrr:
	wrmsr
	inc	%ecx
	wrmsr
	inc	%ecx
	dec	%ebx
	jnz	clear_var_mtrr

	//post_code_be_careful_about_al(0x21)

	/* Configure the default memory type to uncacheable. */
	movl	$MTRR_DEF_TYPE_MSR, %ecx
	rdmsr
	andl	$(~0x00000cff), %eax
	wrmsr

	//post_code_be_careful_about_al(0x22)

	/* Determine CPU_ADDR_BITS and load PHYSMASK high word to %edx. */
	movl	$1, %eax
	cpuid
	andl	$(1 << 6 | 1 << 17), %edx	/* PAE or PSE36 */
	jz	addrsize_set_high
	movl	$0x0f, %edx

	/* Preload high word of address mask (in %edx) for Variable
	   MTRRs 0 and 1. */
addrsize_set_high:
	xorl	%eax, %eax
	movl	/*$MTRR_PHYS_MASK(0)*/$(0x200 + 1), %ecx
	wrmsr
	movl	/*$MTRR_PHYS_MASK(1)*/$(0x202 + 1), %ecx
	wrmsr

	//post_code_be_careful_about_al(0x2a)

	/* Set Cache-as-RAM base address. */
	movl	/*$(MTRR_PHYS_BASE(0))*/$0x200, %ecx
	movl	$_car_mtrr_start, %eax
	orl	$MTRR_TYPE_WRBACK, %eax
	xorl	%edx, %edx
	wrmsr

	/* Set Cache-as-RAM mask. */
	movl	/*$(MTRR_PHYS_MASK(0))*/$0x201, %ecx
	rdmsr
	movl	$_car_mtrr_mask, %eax
	orl	$MTRR_PHYS_MASK_VALID, %eax
	wrmsr

	//post_code_be_careful_about_al(0x2b)

	/* Enable MTRR. */
	movl	$MTRR_DEF_TYPE_MSR, %ecx
	rdmsr
	orl	$MTRR_DEF_TYPE_EN, %eax
	wrmsr

	//post_code_be_careful_about_al(0x2c)

	/* Enable cache (CR0.CD = 0, CR0.NW = 0). */
	movl	%cr0, %eax
	andl	/*$(~(CR0_CacheDisable | CR0_NoWriteThrough))*/$((1<<30)|(1<<29)), %eax
	invd
	movl	%eax, %cr0

	/* Read then clear the CAR region. This will also fill up the cache.
	 * IMPORTANT: The read is mandatory.
	 */
	cld
	movl	$_car_mtrr_start, %edi
	movl	$_car_mtrr_size, %ecx
	shr	$2, %ecx
	movl	%ecx, %ebx
	movl	%edi, %esi
	rep	lodsl
	movl	%ebx, %ecx
	xorl	%eax, %eax
	rep	stosl

	//post_code_be_careful_about_al(0x2d)
	/* Enable Cache-as-RAM mode by disabling cache. */
	movl	%cr0, %eax
	orl	/*$CR0_CacheDisable*/$CR0_CD, %eax
	movl	%eax, %cr0

	/* Enable cache for our code in Flash because we do XIP here */
	movl	/*$MTRR_PHYS_BASE(1)*/$(0x202+1), %ecx
	xorl	%edx, %edx
	movl	$_program, %eax
	andl	$_xip_mtrr_mask, %eax
	orl	$MTRR_TYPE_WRPROT, %eax
	wrmsr
	movl	/*MTRR_PHYS_MASK(1)*/$(0x202+1), %ecx
	rdmsr
	movl	$_xip_mtrr_mask, %eax
	orl	$MTRR_PHYS_MASK_VALID, %eax
	wrmsr

	//post_code_be_careful_about_al(0x2e)
	/* Enable cache. */
	movl	%cr0, %eax
	andl	/*$(~(CR0_CacheDisable | CR0_NoWriteThrough))*/$(~((1<<30)|(1<<29))), %eax
	movl	%eax, %cr0

	/* Setup the stack. */
	mov	$_ecar_stack, %esp

	/* Need to align stack to 16 bytes at call instruction. Account for
	the pushes below. */
	andl	$0xfffffff0, %esp
	subl	$4, %esp

	/* push TSC and BIST to stack */
	movd	%mm0, %eax
	pushl	%eax	/* BIST */
	movd	%mm2, %eax
	pushl	%eax	/* tsc[63:32] */
	movd	%mm1, %eax
	pushl	%eax	/* tsc[31:0] */

before_c_entry:
	//post_code_be_careful_about_al(0x29)
	jmp 1f

	/* Should never see this postcode */
	//post_code_be_careful_about_al(0xfe)

.Lhlt:
	hlt
	jmp	.Lhlt

fixed_mtrr_list:
/*	.word	MTRR_FIX_64K_00000
	.word	MTRR_FIX_16K_80000
	.word	MTRR_FIX_16K_A0000
	.word	MTRR_FIX_4K_C0000
	.word	MTRR_FIX_4K_C8000
	.word	MTRR_FIX_4K_D0000
	.word	MTRR_FIX_4K_D8000
	.word	MTRR_FIX_4K_E0000
	.word	MTRR_FIX_4K_E8000
	.word	MTRR_FIX_4K_F0000
	.word	MTRR_FIX_4K_F8000
*/
	.long 0x250
	.long 0x258
	.long 0x259
	.long 0x268
	.long 0x269
	.long 0x26a
	.long 0x26b
	.long 0x26c
	.long 0x26d
	.long 0x26e
	.long 0x26f
fixed_mtrr_list_size = . - fixed_mtrr_list

1:
_cache_as_ram_setup_end:

	// Set a pointer to the page table pages in %cr3.
	// We can use cr3 as a scratch register here;
	// its value won't matter until we set PG in CR0 below.
	movl $0x7e000, %esp
	movl %esp, %cr3
	/* Restore the BIST value to %eax */
	movl	%ebp, %eax
	
	// Now for the big fun: Long Mode.
	// Once again we put the data structures inline in this
	// memory. This code is, we hope, PIC.
	// The call 2f is an old trick; it puts the address of the data following
	// this instruction on the stack. The current burning question: do we need
	// bother with another lgdt or should we let linux do it?
	// We'll leave the table here but suspect we can let Linux do it.
	call 2f
gdt64:
_gdt64p:
	.quad	0x0000000000000000		/* NULL descriptor */
	.quad	0x0020980000000000		/* CS */

_gdtptr64p:
	.word	2*8-1
	.quad	_gdt64p

	.align 4
2:
	// assumption: we are running somewhere in the low 1G.
	// we can fix this later, but it will at most be the
	// low 4G.
	// bits
	// Save %ecx for later mov to cr3
	// PML4 is at %ecx.
	// PML3 is at 4096(%ecx)
	// Set PML4(0) to point to %ecx
	movl %cr3, %ecx
	movl %ecx, %edx
	//$(PteRW|PteP)
	orl $(PteRW | PteP), %edx	
	addl $(Pte2MPAT), %edx
	movl %edx, 0(%ecx) // identity map entry to point to pml3
	movl $(PtePS|PteRW|PteP), %edx
	movl %edx, 0x1000(%ecx)
	addl $(0x40000000), %edx
	movl %edx, 0x1008(%ecx)
	addl $(0x40000000), %edx
	movl %edx, 0x1010(%ecx)
	addl $(0x40000000), %edx
	movl %edx, 0x1018(%ecx)
	// This should be relative load
	// In theory,
	// This is code which lives at 0xfffffff0.
//1:	 jmp 1b
	/* Enable and activate Long Mode. From the manual:
	* 	make sure Page Size Extentions are off, and Page Global
	*	Extensions and Physical Address Extensions are on in CR4;
	*	set Long Mode Enable in the Extended Feature Enable MSR;
	*	set Paging Enable in CR0;
	*	make an inter-segment jump to the Long Mode code.
	* It`s all in 32-bit mode until the jump is made.
	*/
lme:
	movl	%cr4, %eax
	andl	$(~Pse), %eax			/* Page Size */
	orl	$0x60, %eax		/* Page Global, Phys. Address */
	movl	%eax, %cr4
	movl	$(Efer | Lme), %ecx			/* Extended Feature Enable */
	RDMSR
	ORL	$Lme, %eax			/* Long Mode Enable */
	WRMSR

	movl	%cr0, %edx
	// yeah yeah repeat defines. It's ok. They've been constant for almost 40 years.
	// view screen scrape from the docs. Includes of 40-year-old constants are a PITA.
	ANDL	$~(CD|NW|TS|MP), %edx
	ORL	$(PG|WP), %edx			/* Paging Enable */
	movl	%edx, %cr0
	ljmp $0x18, $_identity


	/* Long mode. Welcome to 2003.
	 * (TODO maybe): load a proper long mode GDT. */
.code64

_identity:
	call _start
1:	 jmp 1b

	
	.section ".reset", "ax", %progbits
//	.code16
.globl _boot
_boot:
.globl	_resetvector
_resetvector:
	.byte  0xe9
	.int   _start16bit - ( . + 2 )
	/* Note: The above jump is hand coded to work around bugs in binutils.
	 * 5 byte are used for a 3 byte instruction.  This works because x86
	 * is little endian and allows us to use supported 32bit relocations
	 * instead of the weird 16 bit relocations that binutils does not
	 * handle consistently between versions because they are used so rarely.
	*/
	// This id padding to get us properly sized. That way we don't care that
	// our tools tend to load us, ARM-style, at the front of a region, rather
	// than the back, x86-style (ARM roms are a 0; x86 at the top of 4 GiB).
	.byte 0,0,0,0,0,0,0,0,0,0,0
	.previous
