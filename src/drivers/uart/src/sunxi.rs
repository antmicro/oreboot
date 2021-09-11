use clock::ClockNode;
use core::ops;
use model::*;

use register::mmio::{ReadOnly, ReadWrite};
use register::register_bitfields;

// D1 user manual
// https://dl.linux-sunxi.org/D1/D1_User_Manual_V0.1_Draft_Version.pdf
// pp 1094
const GPIO_BASE_ADDR: usize = 0x02000000;
const GPIO_PB_CFG0: usize = GPIO_BASE_ADDR + 0x0030;
const GPIO_PB_CFG1: usize = GPIO_PB_CFG0 + 0x04;
// pp 900
const CCU_BASE_ADDR: usize = 0x02001000;
const CCU_UART_BGR: usize = CCU_BASE_ADDR + 0x090C;
// pp 910
const UART0: usize = 0x02500000;
const UART0_RB_TH_DLL: usize = UART0 + 0x0;
const UART0_DLH_IE: usize = UART0 + 0x4;
const UART0_II_FC: usize = UART0 + 0x8;
const UART0_LC: usize = UART0 + 0xc;

const RETRY_COUNT: u32 = 100_000;

// TODO TODO TODO :)
#[repr(C)]
pub struct RegisterBlock {
    bgr: ReadWrite<u32, CCU_UART_BGR::Register>, /* clock something */
    pbcfg0: ReadWrite<u32, GPIO_PB_CFG0::Register>, /* PB Config Register 0 */
    pbcfg1: ReadWrite<u32, GPIO_PB_CFG1::Register>, /* PB Config Register 1 */
    /* UART0 Receiver Buffer / Transmit Holding / Divisor Latch Low Register */
    u0rbthdll: ReadWrite<u32, UART0_RB_TH_DLL::Register>,
    /* UART0 Divisor Latch Low / Interrupt Enable Register */
    u0dlhie: ReadWrite<u32, UART0_DLH_IE::Register>,
    /* UART0 Interrupt Identity / FIFO Control Register */
    u0iifc: ReadWrite<u32, UART0_II_FC::Register>,
    /* UART0 Line Control Register */
    u0lc: ReadWrite<u32, UART0_LC::Register>,
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

// from https://github.com/smaeul/sun20i_d1_spl for reference

/// nboot/main/boot0_head.c

        /*__s32	uart_port;*/
        0,
        /*normal_gpio_cfg   uart_ctrl[2];*/
        {
            {2, 8, 6, 1, 0xff, 0xff, {0} }, /*PB8: 6--RX*/
            {2, 9, 6, 1, 0xff, 0xff, {0} }, /*PB9: 6--TX*/
        },

/// drivers/serial.c

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
    boot_set_gpio(gpio_cfg, gpio_max, 1);

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
        UART0_GATING OFFSET(0) NUMBITS(1) [],
        UART1_GATING OFFSET(1) NUMBITS(1) [],
        UART2_GATING OFFSET(2) NUMBITS(1) [],
        UART3_GATING OFFSET(3) NUMBITS(1) [],
        UART4_GATING OFFSET(4) NUMBITS(1) [],
        UART5_GATING OFFSET(5) NUMBITS(1) [],
        UART0_RST OFFSET(16) NUMBITS(1) [],
        UART1_RST OFFSET(17) NUMBITS(1) [],
        UART2_RST OFFSET(18) NUMBITS(1) [],
        UART3_RST OFFSET(19) NUMBITS(1) [],
        UART4_RST OFFSET(20) NUMBITS(1) [],
        UART5_RST OFFSET(21) NUMBITS(1) []
    ],
    GPIO_PB_CFG0 [
        PB0_SELECT OFFSET(0) NUMBITS(4) [],
        PB1_SELECT OFFSET(4) NUMBITS(4) [],
        PB2_SELECT OFFSET(8) NUMBITS(4) [],
        PB3_SELECT OFFSET(12) NUMBITS(4) [],
        PB4_SELECT OFFSET(16) NUMBITS(4) [],
        PB5_SELECT OFFSET(20) NUMBITS(4) [],
        PB6_SELECT OFFSET(24) NUMBITS(4) [],
        PB7_SELECT OFFSET(28) NUMBITS(4) []
    ],
    GPIO_PB_CFG1 [
        PB8_SELECT OFFSET(0) NUMBITS(4) [],
        PB9_SELECT OFFSET(4) NUMBITS(4) [],
        PB10_SELECT OFFSET(8) NUMBITS(4) [],
        PB11_SELECT OFFSET(12) NUMBITS(4) [],
        PB12_SELECT OFFSET(16) NUMBITS(4) []
        // last 12 bits are reserved
    ],
    UART0_RB_TH_DLL [
        VAL OFFSET(0) NUMBITS(8) []
    ],
    UART0_DLH_IE [
        DLH OFFSET(0) NUMBITS(8) [],
        /* IE */
        ERBFI OFFSET(0) NUMBITS(1) [],
        ETBEI OFFSET(1) NUMBITS(1) [],
        ELSI OFFSET(2) NUMBITS(1) [],
        EDSSI OFFSET(3) NUMBITS(1) [],
        RS485_INT_EN OFFSET(4) NUMBITS(1) [],
        // 6:5 are reserved
        PTIME OFFSET(7) NUMBITS(1) []
        // last 24 bits are reserved
    ],
    UART0_II_FC [
        IID OFFSET(0) NUMBITS(3) []
    ],
    UART0_LC [
        DLS OFFSET(0) NUMBITS(2) [],
        STOP OFFSET(2) NUMBITS(1) [],
        PEN OFFSET(3) NUMBITS(1) [],
        EPS OFFSET(4) NUMBITS(2) [],
        BC OFFSET(6) NUMBITS(1) [],
        DLAB OFFSET(7) NUMBITS(1) []
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

        self.pbcfg1.modify(GPIO_PB_CFG1::PB8_SELECT.val(6)); // 0110: UART0 TX
        self.pbcfg1.modify(GPIO_PB_CFG1::PB9_SELECT.val(6)); // 0110: UART0 RX

        /*
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
        */

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
        /*
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
        */
        Ok(data.len())
    }

    fn pwrite(&mut self, data: &[u8], _offset: usize) -> Result<usize> {
        /*
        'outer: for (sent_count, &c) in data.iter().enumerate() {
            for _ in 0..RETRY_COUNT {
                if !self.td.is_set(TD::Full) {
                    self.td.set(c.into());
                    continue 'outer;
                }
            }
            return Ok(sent_count);
        }
        */
        Ok(data.len())
    }

    fn shutdown(&mut self) {}
}
