/*
 * start.S
 *
 * Copyright(c) 2007-2021 Jianjun Jiang <8192542@qq.com>
 * Official site: http://xboot.org
 * Mobile phone: +86-18665388956
 * QQ: 8192542
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

// #include <xconfigs.h>
// #include "include/linkage.h"
#include <riscv64.h>

	.global _start
_start:
	/* Boot head information for BROM */
	.long 0x0300006f
	.byte 'e', 'G', 'O', 'N', '.', 'B', 'T', '0'
	.long 0x12345678				/* checksum */
// .long __spl_size				/* spl size */
	.long 0x30						/* boot header size */
	.long 0x30303033				/* boot header version */
	.long 0x00020000				/* return value */
	.long 0x00020000				/* run address */
	.long 0x0						/* eGON version */
	.byte 0x00, 0x00, 0x00, 0x00	/* platform information - 8byte */
	.byte 0x34, 0x2e, 0x30, 0x00

/*
 * The actual reset code
 */
reset:
	/* Mask all interrupts */
	csrw mideleg, zero
	csrw medeleg, zero
	csrw mie, zero
	csrw mip, zero

	/* Setup exception vectors */
// la t1, _image_start
	ld t1, (t1)
	la t2, _start
	sub t0, t1, t2
	la a0, vectors
	add a0, a0, t0
	csrw mtvec, a0

	/* Enable FPU and accelerator if present */
	li t0, (3 << 13) | (3 << 15) // MSTATUS_FS | MSTATUS_XS
	csrs mstatus, t0

	/* Enable theadisaee */
	li t1, 0x1 << 22
	.word 0x7c032073	/* csrs mxstatus, t1 */

	/* Invaild icache/dcache/btb/bht */
	li t1, 0x30013
	.word 0x7c232073	/* csrs mcor, t1 */

	/* Check processor id and initialized */
 // csrr t0, mhartid
 // bnez t0, _avoid
 // la t0, _start
 // la t1, _image_start
 // ld t1, (t1)
 // beq t0, t1, _avoid

	/* Initial system jtag, uart and clock */
	//call sys_jtag_init
	//call sys_uart_init
	//call sys_clock_init

	/* Copy ddr bin to 0x00030000 */
 // la t1, _ddr_bin_start
 // ld t1, (t1)
 // la t2, _ddr_bin_end
 // ld t2, (t2)
 // sub a2, t2, t1
 // la t1, _image_start
 // ld t1, (t1)
 // la t2, _ddr_bin_start
 // ld t2, (t2)
 // sub t0, t2, t1
 // la a1, _start
 // add a1, a1, t0
 // li a0, 0x00030000
	//call memcpy

	/* Initial ddr controller */
	//call sys_dram_init
_avoid:
	nop

	/* Initialize global pointer */
.option push
.option norelax
 // la t0, _global_pointer$
 // ld gp, (t0)
.option pop

	/* Initialize stacks */
 // la t1, _stack_start
 // ld t1, (t1)
 // la t2, _stack_end
 // ld t2, (t2)
 // sub t0, t2, t1
	csrr t3, mhartid
	li t4, 1 // CONFIG_MAX_SMP_CPUS
	div t0, t0, t4
	mul t0, t0, t3
	sub sp, t2, t0

	/* Check processor id, and startup slave cores */
	csrr a0, mhartid
	beqz a0, 2f
1:	//call sys_smp_secondary_startup
	j 1b
2:	nop

	/* Copyself to link address */
 // la t0, _start
 // la t1, _image_start
 // ld t1, (t1)
 // beq t0, t1, 1f
	//call sys_copyself
1:	nop

	/* Clear bss section */
 // la a0, _bss_start
 // ld a0, (a0)
 // la a2, _bss_end
 // ld a2, (a2)
 // sub a2, a2, a0
 // li a1, 0
	//call memset

	/* Call _main */
 // la t1, _image_start
 // ld t1, (t1)
 // la t2, _start
 // sub t0, t1, t2
 // la a0, _main
 // add a0, a0, t0
 // jr a0
_main:
	call _start_boot_hart
	j _main

/*
 * Exception vectors.
 */
	.align 4
	.globl vectors
vectors:
	csrw mscratch, sp
	addi sp, sp, -(37 * 8)
	sd x1, 1 * 8(x2)
	sd x3, 3 * 8(x2)
	sd x4, 4 * 8(x2)
	sd x5, 5 * 8(x2)
	sd x6, 6 * 8(x2)
	sd x7, 7 * 8(x2)
	sd x8, 8 * 8(x2)
	sd x9, 9 * 8(x2)
	sd x10, 10 * 8(x2)
	sd x11, 11 * 8(x2)
	sd x12, 12 * 8(x2)
	sd x13, 13 * 8(x2)
	sd x14, 14 * 8(x2)
	sd x15, 15 * 8(x2)
	sd x16, 16 * 8(x2)
	sd x17, 17 * 8(x2)
	sd x18, 18 * 8(x2)
	sd x19, 19 * 8(x2)
	sd x20, 20 * 8(x2)
	sd x21, 21 * 8(x2)
	sd x22, 22 * 8(x2)
	sd x23, 23 * 8(x2)
	sd x24, 24 * 8(x2)
	sd x25, 25 * 8(x2)
	sd x26, 26 * 8(x2)
	sd x27, 27 * 8(x2)
	sd x28, 28 * 8(x2)
	sd x29, 29 * 8(x2)
	sd x30, 30 * 8(x2)
	sd x31, 31 * 8(x2)
	csrrw t0, mscratch, x0
	csrr s0, mstatus
	csrr t1, mepc
	// csrr t2, mbadaddr
	csrr t3, mcause
	sd t0, 2 * 8(x2)
	sd s0, 32 * 8(x2)
	sd t1, 33 * 8(x2)
	sd t2, 34 * 8(x2)
	sd t3, 35 * 8(x2)
	li x5, -1
	sd x5, 36 * 8(x2)
	move a0, sp
	// jal riscv64_handle_exception
	csrr a0, mscratch
	ld x1, 1 * 8(a0)
	ld x2, 2 * 8(a0)
	ld x3, 3 * 8(a0)
	ld x4, 4 * 8(a0)
	ld x5, 5 * 8(a0)
	ld x6, 6 * 8(a0)
	ld x7, 7 * 8(a0)
	ld x8, 8 * 8(a0)
	ld x9, 9 * 8(a0)
	ld x11, 11 * 8(a0)
	ld x12, 12 * 8(a0)
	ld x13, 13 * 8(a0)
	ld x14, 14 * 8(a0)
	ld x15, 15 * 8(a0)
	ld x16, 16 * 8(a0)
	ld x17, 17 * 8(a0)
	ld x18, 18 * 8(a0)
	ld x19, 19 * 8(a0)
	ld x20, 20 * 8(a0)
	ld x21, 21 * 8(a0)
	ld x22, 22 * 8(a0)
	ld x23, 23 * 8(a0)
	ld x24, 24 * 8(a0)
	ld x25, 25 * 8(a0)
	ld x26, 26 * 8(a0)
	ld x27, 27 * 8(a0)
	ld x28, 28 * 8(a0)
	ld x29, 29 * 8(a0)
	ld x30, 30 * 8(a0)
	ld x31, 31 * 8(a0)
	ld x10, 10 * 8(a0)
	mret

/*
 * The location of section
 */
//	.align 3
//_image_start:
//	.dword __image_start
/*
 *	_image_end:
 *		.dword __image_end
 *	_global_pointer$:
 *		.dword __global_pointer$
 *	_data_start:
 *		.dword __data_start
 *	_data_end:
 *		.dword __data_end
 *	_bss_start:
 *		.dword __bss_start
 *	_bss_end:
 *		.dword __bss_end
 *	_stack_start:
 *		.dword __stack_start
 *	_stack_end:
 *		.dword __stack_end
 *	_ddr_bin_start:
 *		.dword __ddr_bin_start
 *	_ddr_bin_end:
 *		.dword __ddr_bin_end
 */
