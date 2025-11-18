######################################################################
# @author      : Justin Kachele (justin@kachele.com)
# @file        : Makefile
# @created     : Friday Oct 17, 2025 14:39:28 UTC
######################################################################
RVTOOL_PREFIX = riscv64-unknown-elf
RVTOOL_DIR = /opt/riscv
RV_LIB_DIR = $(RVTOOL_DIR)/$(RVTOOL_PREFIX)/lib/rv32i/ilp32
GCC_LIB_DIR = /opt/riscv/lib/gcc/riscv64-unknown-elf/10.1.0/rv32i/ilp32

CC = $(RVTOOL_PREFIX)-gcc
LD = $(RVTOOL_PREFIX)-ld
OBJCOPY = $(RVTOOL_PREFIX)-objcopy
CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -Wno-builtin-declaration-mismatch
LDFLAGS  = -m elf32lriscv -nostdlib --no-relax
LDFLAGS += -L$(RV_LIB_DIR) -lm $(GCC_LIB_DIR)/libgcc.a

# Verilog
VSRC = src/pipeline/SOC.v
TOP = SOC
XDC = src/Extern/NexusA7.xdc

# Simulation
TB = verilator
TBFLAGS  = -DBENCH -Wno-fatal -Isrc -Isrc/pipeline -Isrc/Extern
TBFLAGS += --top-module $(TOP) --trace --build -cc -exe
TBSRC = $(wildcard tb/*.cpp)

BIN_DIR := bin
BUILD_DIR := build

# Firmware
SRC := firmware/startPipeline.S firmware/raystones.c
SRC += $(wildcard firmware/*/*.S) $(wildcard firmware/*/*.c) 
OBJ := $(SRC:%=$(BUILD_DIR)/%.o)
LDSCRIPT = firmware/ram.ld

ROM := $(BIN_DIR)/ROM.hex
RAM := $(BIN_DIR)/RAM.hex
FIRMWARE := $(BIN_DIR)/firmware.elf

.PHONY: all hex sim lint build dirs clean 

hex: $(ROM) $(RAM)

$(ROM): $(FIRMWARE)
	$(OBJCOPY) $< -R .data -O binary $@.bin
	hexdump -ve '"%08x\n"' $@.bin > $@
	rm $@.bin

$(RAM): $(FIRMWARE)
	$(OBJCOPY) $< -R .text -O binary $@.bin
	hexdump -ve '"%08x\n"' $@.bin > $@
	rm $@.bin

$(FIRMWARE): $(OBJ)
	@mkdir -p $(dir $@)
	$(LD) -T $(LDSCRIPT) $(OBJ) -o $@ $(LDFLAGS)

$(BUILD_DIR)/%.S.o: %.S
	@mkdir -p $(dir $@)
	$(CC) -o $@ -c $< $(CFLAGS)

$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) -o $@ -c $< $(CFLAGS)

sim: $(ROM) $(RAM)
	cd obj_dir; rm -f *.cpp *.o *.a *.vcd V$(TOP)
	$(TB) $(TBFLAGS) $(TBSRC) $(VSRC)
	cd obj_dir && ./V$(TOP)

all: $(BIN_DIR) $(ROM) $(RAM)
	cd tcl; vivado -mode tcl -source build.tcl
	cd tcl; vivado -mode tcl -source upload.tcl

$(BIN_DIR):
	mkdir -p $@

lint: $(BIN_DIR) $(ROM) $(RAM) 
	cd tcl; vivado -mode tcl -source lint.tcl

build: $(BIN_DIR) $(ROM) $(RAM) 
	cd tcl; vivado -mode tcl -source build.tcl

upload:
	cd tcl; vivado -mode tcl -source upload.tcl

store:
	cd tcl; vivado -mode tcl -source store.tcl

clean:
	rm -rf ./obj_dir
	rm -rf $(BIN_DIR)
	rm -rf $(BUILD_DIR)

