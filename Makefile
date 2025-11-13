######################################################################
# @author      : Justin Kachele (justin@kachele.com)
# @file        : Makefile
# @created     : Friday Oct 17, 2025 14:39:28 UTC
######################################################################
CC = riscv64-unknown-linux-gnu-gcc
AS = riscv64-unknown-linux-gnu-as
LD = riscv64-unknown-linux-gnu-ld
OBJCOPY = riscv64-unknown-linux-gnu-objcopy
ASFLAGS = -march=rv32i -mabi=ilp32
LDFLAGS = -m elf32lriscv -nostdlib

SRC = firmware/program.S
OBJ = $(SRC:.S=.o)

LDSCRIPT = firmware/ram.ld

DIR=bin
.PHONY: all lint build dirs clean 

all: dirs out
	cd tcl; \
	vivado -mode tcl -source build.tcl; \
	vivado -mode tcl -source upload.tcl; \
	cd ..

dirs:
	mkdir -p ./$(DIR)

out: firmware dirs
	$(OBJCOPY) firmware.elf -O binary firmware.bin
	hexdump -ve '"%08x\n"' firmware.bin > $(DIR)/$@.hex
	rm firmware.elf
	rm firmware.bin

firmware: $(OBJ)
	$(LD) -T $(LDSCRIPT) $(OBJ) -o $@.elf $(LDFLAGS)
	rm $(OBJ)

%.o: %.S
	$(AS) $< -o $@ $(ASFLAGS)

lint: dirs out
	cd tcl; \
	vivado -mode tcl -source lint.tcl; \
	cd ..

build: dirs out
	cd tcl; \
	vivado -mode tcl -source build.tcl; \
	cd ..

upload: dirs
	cd tcl; \
	vivado -mode tcl -source upload.tcl; \
	cd ..

store: dirs
	cd tcl; \
	vivado -mode tcl -source store.tcl; \
	cd ..

clean:
	rm -rf ./bin

