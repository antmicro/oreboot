use clock::ClockNode;
use core::ops;
use model::*;

use register::mmio::{ReadOnly, ReadWrite};
use register::register_bitfields;

// D1 user manual, pp900
// https://dl.linux-sunxi.org/D1/D1_User_Manual_V0.1_Draft_Version.pdf

const CCU_BASE_ADDR: usize = 0x02001000;
const CCU_UART_BGR: usize = CCU_BASE_ADDR + 0x090C;

const RETRY_COUNT: u32 = 100_000;

// TODO TODO TODO :)
#[repr(C)]
pub struct RegisterBlock {
    bgr: ReadWrite<u32, CCU_UART_BGR::Register>, /* clock something */
    td: ReadWrite<u32, TD::Register>,            /* Transmit data register */
    rd: ReadOnly<u32, RD::Register>,             /* Receive data register */
    txc: ReadWrite<u32, TXC::Register>,          /* Transmit control register */
    rxc: ReadWrite<u32, RXC::Register>,          /* Receive control register */
    ie: ReadWrite<u32, IE::Register>,            /* UART interrupt enable */
    ip: ReadWrite<u32, IP::Register>,            /* UART interrupt pending */
    div: ReadWrite<u32, DIV::Register>,          /* Baud Rate Divisor */
}

pub struct Sunxi {
    base: usize,
    baudrate: u32,
}

impl ops::Deref for Sunxi {
    type Target = RegisterBlock;
    fn deref(&self) -> &Self::Target {
        unsafe { &*self.ptr() }
    }
}

/*
from xboot, for reference

void sys_uart_init(void)
{
    virtual_addr_t addr;
    u32_t val;

    /* Config GPIOB8 and GPIOB9 to txd0 and rxd0 */
    addr = 0x02000030 + 0x04;
    val = read32(addr);
    val &= ~(0xf << ((8 & 0x7) << 2));
    val |= ((0x6 & 0xf) << ((8 & 0x7) << 2));
    write32(addr, val);

    val = read32(addr);
    val &= ~(0xf << ((9 & 0x7) << 2));
    val |= ((0x6 & 0xf) << ((9 & 0x7) << 2));
    write32(addr, val);

    /* Open the clock gate for uart0 */
    addr = 0x0200190c;
    val = read32(addr);
    val |= 1 << 0;
    write32(addr, val);

    /* Deassert uart0 reset */
    addr = 0x0200190c;
    val = read32(addr);
    val |= 1 << 16;
    write32(addr, val);

    /* Config uart0 to 115200-8-1-0 */
    addr = 0x02500000;
    write32(addr + 0x04, 0x0);
    write32(addr + 0x08, 0xf7);
    write32(addr + 0x10, 0x0);
    val = read32(addr + 0x0c);
    val |= (1 << 7);
    write32(addr + 0x0c, val);
    write32(addr + 0x00, 0xd & 0xff);
    write32(addr + 0x04, (0xd >> 8) & 0xff);
    val = read32(addr + 0x0c);
    val &= ~(1 << 7);
    write32(addr + 0x0c, val);
    val = read32(addr + 0x0c);
    val &= ~0x1f;
    val |= (0x3 << 0) | (0 << 2) | (0x0 << 3);
    write32(addr + 0x0c, val);
}

*/

/*

from https://github.com/smaeul/sun20i_d1_spl for reference

void sunxi_clock_init_uart(int port)
{
    u32 i, reg;

    /* reset */
    reg = readl(CCMU_UART_BGR_REG);
    reg &= ~(1<<(CCM_UART_RST_OFFSET + port));
    writel(reg, CCMU_UART_BGR_REG);
    for (i = 0; i < 100; i++)
        ;
    reg |= (1 << (CCM_UART_RST_OFFSET + port));
    writel(reg, CCMU_UART_BGR_REG);

    /* gate */
    reg = readl(CCMU_UART_BGR_REG);
    reg &= ~(1<<(CCM_UART_GATING_OFFSET + port));
    writel(reg, CCMU_UART_BGR_REG);
    for (i = 0; i < 100; i++)
        ;
    reg |= (1 << (CCM_UART_GATING_OFFSET + port));
    writel(reg, CCMU_UART_BGR_REG);
}

    sunxi_clock_init_uart(uart_port);
    /* gpio */
#ifdef FPGA_PLATFORM
    boot_set_gpio(fpga_uart_gpio, gpio_max, 1);
#else
    boot_set_gpio(gpio_cfg, gpio_max, 1);
#endif
    /* uart init */
    serial_ctrl_base = (serial_hw_t *)(uart0_base + uart_port * CCM_UART_ADDR_OFFSET);

    serial_ctrl_base->mcr = 0x3;
    uart_clk = (24000000 + 8 * UART_BAUD)/(16 * UART_BAUD);
    serial_ctrl_base->lcr |= 0x80;
    serial_ctrl_base->dlh = uart_clk>>8;
    serial_ctrl_base->dll = uart_clk&0xff;
    serial_ctrl_base->lcr &= ~0x80;
    serial_ctrl_base->lcr = ((PARITY&0x03)<<3) | ((STOP&0x01)<<2) | (DLEN&0x03);
    serial_ctrl_base->fcr = 0x7;

*/

register_bitfields! {
    u32,
    CCU_UART_BGR [
        UART5_RST OFFSET(21) NUMBITS(1) [],
        UART4_RST OFFSET(20) NUMBITS(1) [],
        UART3_RST OFFSET(19) NUMBITS(1) [],
        UART2_RST OFFSET(18) NUMBITS(1) [],
        UART1_RST OFFSET(17) NUMBITS(1) [],
        UART0_RST OFFSET(16) NUMBITS(1) [],
        UART5_GATING OFFSET(5) NUMBITS(1) [],
        UART4_GATING OFFSET(4) NUMBITS(1) [],
        UART3_GATING OFFSET(3) NUMBITS(1) [],
        UART2_GATING OFFSET(2) NUMBITS(1) [],
        UART1_GATING OFFSET(1) NUMBITS(1) [],
        UART0_GATING OFFSET(0) NUMBITS(1) []
    ],
    TD [
        Data OFFSET(0) NUMBITS(8) [],
        Full OFFSET(31) NUMBITS(1) []
    ],
    RD [
        Data OFFSET(0) NUMBITS(8) [],
        Empty OFFSET(31) NUMBITS(1) []
    ],
    IE[
        TX OFFSET(0) NUMBITS(1) [],
        RX OFFSET(1) NUMBITS(1) []
    ],
    TXC [
        Enable OFFSET(0) NUMBITS(1) [],
        StopBits OFFSET(1) NUMBITS(1) []
     //   TXCnt OFFSET(16) NUMBITS(16) [],
    ],
    RXC [
        Enable OFFSET(0) NUMBITS(1) []
    //    TXCnt OFFSET(16) NUMBITS(16) [],
    ],
    IP [
        TXWM OFFSET(0) NUMBITS(1) [],
        RXWM OFFSET(1) NUMBITS(1) []
    ],
    DIV [
        DIV OFFSET(0) NUMBITS(16) []
    ]
}

impl Sunxi {
    pub fn new(base: usize, baudrate: u32) -> Sunxi {
        Sunxi { base, baudrate }
    }

    /// Returns a pointer to the register block
    fn ptr(&self) -> *const RegisterBlock {
        self.base as *const _
    }
}

impl Driver for Sunxi {
    fn init(&mut self) -> Result<()> {
        // reset
        self.bgr.modify(CCU_UART_BGR::UART0_RST.val(0));
        for i in 1..100 {}
        self.bgr.modify(CCU_UART_BGR::UART0_RST.val(1));

        // gate
        self.bgr.modify(CCU_UART_BGR::UART0_GATING.val(0));
        for i in 1..100 {}
        self.bgr.modify(CCU_UART_BGR::UART0_GATING.val(1));

        /*
        // Disable UART interrupts.
        self.ie.set(0 as u32);
        // Enable transmit.
        self.txc.modify(TXC::Enable.val(1));
        // Enable receive.
        self.rxc.modify(RXC::Enable.val(1));
        */
        Ok(())
    }

    fn pread(&self, data: &mut [u8], _offset: usize) -> Result<usize> {
        'outer: for (read_count, c) in data.iter_mut().enumerate() {
            for _ in 0..RETRY_COUNT {
                // Create a copy of the rxdata register so that we don't
                // lose the Data field when we read the Empty field.
                let rd_copy = self.rd.extract();
                if !rd_copy.is_set(RD::Empty) {
                    *c = rd_copy.read(RD::Data) as u8;
                    continue 'outer;
                }
            }
            return Ok(read_count);
        }
        Ok(data.len())
    }

    fn pwrite(&mut self, data: &[u8], _offset: usize) -> Result<usize> {
        'outer: for (sent_count, &c) in data.iter().enumerate() {
            for _ in 0..RETRY_COUNT {
                if !self.td.is_set(TD::Full) {
                    self.td.set(c.into());
                    continue 'outer;
                }
            }
            return Ok(sent_count);
        }
        Ok(data.len())
    }

    fn shutdown(&mut self) {}
}
