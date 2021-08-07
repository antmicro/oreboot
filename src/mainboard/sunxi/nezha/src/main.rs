#![feature(llvm_asm)]
#![feature(lang_items, start)]
#![no_std]
#![no_main]
#![feature(global_asm)]

use core::panic::PanicInfo;
use core::{fmt::Write, ptr};
use model::Driver;
use uart::sunxi::Sunxi;

global_asm!(include_str!("../start.S"));

// p897
//  | UART ID |   address    |
//  | ------- | ------------ |
//  |  UART0  |  0x02500000  |
//  |  UART1  |  0x02500400  |
//  |  UART2  |  0x02500800  |
//  |  UART3  |  0x02500C00  |
//  |  UART4  |  0x02501000  |
//  |  UART5  |  0x02501400  |

// hart = hardware thread (something like core)
#[no_mangle]
pub extern "C" fn _start_boot_hart(_hart_id: usize, fdt_address: usize) -> ! {
    let uart0 = &mut Sunxi::new(/*soc::UART0*/ 0x02500000, 115200);
    let w = &mut print::WriteTo::new(uart0);
    w!("Hello, world!");
}

/// This function is called on panic.
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    // Assume that uart0.init() has already been called before the panic.
    let uart0 = &mut Sunxi::new(/*soc::UART0*/ 0x02500000, 115200);
    let w = &mut print::WriteTo::new(uart0);
    // Printing in the panic handler is best-effort because we really don't want to invoke the panic
    // handler from inside itself.
    let _ = writeln!(w, "PANIC: {}\r", info);
    arch::halt()
}
