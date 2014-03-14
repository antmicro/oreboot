/*
 * Glue to UART code to enable serial console
 *
 * Copyright 2013 Google Inc.
 * Copyright (C) 2013  Alexandru Gagniuc <mr.nuke.me@gmail.com>
 * Subject to the GNU GPL v2, or (at your option) any later version.
 */

#include <config.h>
#include <types.h>
#include <console/uart.h>
#include <arch/io.h>
#include <boot/coreboot_tables.h>

#include <cpu/allwinner/a10/uart.h>

unsigned int uart_platform_base(int idx)
{
	/* UART blocks are mapped 0x400 bytes apart */
	if (idx < 8)
		return A1X_UART0_BASE + 0x400 * idx;
	else
		return 0;
}

/* FIXME: We assume clock is 24MHz, which may not be the case. */
unsigned int uart_platform_refclk(void)
{
	return 24000000;
}

void uart_init(int idx)
{
	void *uart_base = uart_platform_baseptr(idx);

	/* Use default 8N1 encoding */
	a10_uart_configure(uart_base, default_baudrate(),
		8, UART_PARITY_NONE, 1);
	a10_uart_enable_fifos(uart_base);
}

unsigned char uart_rx_byte(int idx)
{
	return a10_uart_rx_blocking(uart_platform_baseptr(idx));
}

void uart_tx_byte(int idx, unsigned char data)
{
	a10_uart_tx_blocking(uart_platform_baseptr(idx), data);
}

void uart_tx_flush(int idx)
{
}

#ifndef __PRE_RAM__
void uart_fill_lb(void *data)
{
	struct lb_serial serial;
	serial.type = LB_SERIAL_TYPE_MEMORY_MAPPED;
	serial.baseaddr = uart_platform_base(CONFIG_UART_FOR_CONSOLE);
	serial.baud = default_baudrate();
	lb_add_serial(&serial, data);

	lb_add_console(LB_TAG_CONSOLE_SERIAL8250MEM, data);
}
#endif
