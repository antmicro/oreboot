OREBOOT=$(abspath $(CURDIR)/../../../../)
TARGET     = riscv64imac-unknown-none-elf
QEMU       ?= qemu-system-riscv64
QEMU_FLAGS += -m 1g -machine sifive_u,start-in-flash=true -nographic -device loader,addr=0x20000000,file=${IMAGE} -bios none -smp 4
include ../../../../Makefile.inc
include ../../../../Makefile.qemu.inc

openocd:
	echo run openocd -f openocd.cfg -c "flash write_image erase unlock $(IMAGE) 0x20000000; shutdown"

include ../../../../Makefile.mainboard.inc
cibuild: 
	echo Skipping cibuild for beaglev
ciclippy: skipclippy
citest: skiptest
