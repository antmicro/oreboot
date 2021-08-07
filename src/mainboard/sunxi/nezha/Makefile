TARGET     = riscv64gc-unknown-none-elf # RV64GCV, ackshully
QEMU       ?= qemu-system-riscv64
QEMU_FLAGS += -m 1g -machine sifive_u,start-in-flash=true -nographic -device loader,addr=0x20000000,file=${IMAGE} -bios none -smp 4
include ../../../../Makefile.inc
include ../../../../Makefile.qemu.inc

openocd:
	$(shell which openocd) -f openocd.cfg -c "flash write_image erase unlock $(IMAGE) 0x20000000; shutdown"
