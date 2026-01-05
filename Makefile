######################################################################
# @author      : Justin Kachele (justin@kachele.com)
# @file        : Makefile
# @created     : Friday Oct 17, 2025 14:39:28 UTC
######################################################################
RVARCH = rv32imaf
RVABI = ilp32f
RVTOOL_PREFIX := riscv64-unknown-elf
RVTOOL_DIR := /opt/riscv
RV_LIB_DIR := $(RVTOOL_DIR)/$(RVTOOL_PREFIX)/lib/$(RVARCH)/$(RVABI)
GCC_LIB_DIR := /opt/riscv/lib/gcc/riscv64-unknown-elf/10.1.0/$(RVARCH)/$(RVABI)

CC := $(RVTOOL_PREFIX)-gcc
LD := $(RVTOOL_PREFIX)-ld
OBJCOPY := $(RVTOOL_PREFIX)-objcopy
OBJDUMP := $(RVTOOL_PREFIX)-objdump
CFLAGS  := -O2 -march=$(RVARCH) -mabi=$(RVABI) -Wno-builtin-declaration-mismatch
CFLAGS  += -fno-pic -fno-stack-protector -w -nostdlib
LDFLAGS := -m elf32lriscv -nostdlib
LDFLAGS += -L$(RV_LIB_DIR) -lm $(GCC_LIB_DIR)/libgcc.a
ODFLAGS := -sj .data -dj .text

# Verilog
VSRC := $(wildcard src/*.v) $(wildcard src/*/*.v) $(wildcard src/*/*/*.v)
TOP  := SOC
XDC  := src/Extern/NexusA7.xdc

# Simulation
TB := verilator
TBFLAGS := -DBENCH -Wno-fatal
TBFLAGS += --top-module $(TOP) --trace -cc -exe #--build
TBSRC := $(wildcard tb/*.cpp)

BIN_DIR := bin
BUILD_DIR := build

# Firmware
SRC := firmware/startPipeline.S firmware/raystones.c
SRC += $(wildcard firmware/libs/*.S) $(wildcard firmware/libs/*.c) 
OBJ := $(SRC:%=$(BUILD_DIR)/%.o)
LDSCRIPT = firmware/ram.ld

ROM := $(BIN_DIR)/ROM.hex
RAM := $(BIN_DIR)/RAM.hex
FIRMWARE := $(BIN_DIR)/firmware.elf

.PHONY: hex sim lint build dirs clean 

hex: $(ROM) $(RAM)

$(ROM): $(FIRMWARE)
	$(OBJCOPY) $< -R .data -O binary $@.bin
	hexdump -ve '"%08x\n"' $@.bin > $@
	rm $@.bin

$(RAM): $(FIRMWARE)
	$(OBJCOPY) $< -R .text -O binary $@.bin
	hexdump -ve '"%08x\n"' $@.bin > $@
	rm $@.bin

$(FIRMWARE): $(OBJ) Makefile
	@mkdir -p $(dir $@)
	$(LD) -T $(LDSCRIPT) $(OBJ) -o $@ $(LDFLAGS)
	$(OBJDUMP) $(ODFLAGS) $@ > $(BIN_DIR)/objdump.txt

$(BUILD_DIR)/%.S.o: %.S
	@mkdir -p $(dir $@)
	$(CC) -o $@ -c $< $(CFLAGS)

$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) -o $@ -c $< $(CFLAGS)

sim: $(ROM) $(RAM)
	rm -rf ./obj_dir
	$(TB) $(TBFLAGS) $(TBSRC) $(VSRC)
	cd obj_dir; make -f V$(TOP).mk -s
	cd obj_dir; ./V$(TOP)

$(BIN_DIR):
	mkdir -p $@

lint: $(BIN_DIR) $(ROM) $(RAM) 
	cd tcl; vivado -mode batch -nolog -nojournal -source lint.tcl -tclargs $(VSRC)

build: $(BIN_DIR) $(ROM) $(RAM) 
	cd tcl; vivado -mode batch -nolog -nojournal -source build.tcl -tclargs $(VSRC)

upload:
	cd tcl; vivado -mode tcl -nolog -nojournal -source upload.tcl

store:
	cd tcl; vivado -mode tcl -nolog -nojournal -source store.tcl

clean:
	rm -rf ./obj_dir
	rm -rf $(BIN_DIR)
	rm -rf $(BUILD_DIR)

