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

# Firmware
SRC  = $(wildcard firmware/*.S) $(wildcard firmware/*.c) 
SRC += $(wildcard firmware/*/*.S) $(wildcard firmware/*/*.c) 
OBJ  = $(SRC:.c=.o)
OBJ := $(OBJ:.S=.o)
LDSCRIPT = firmware/ram.ld

DIR=bin
.PHONY: all firmware sim lint build dirs clean 

all: dirs program
	cd tcl; \
	vivado -mode tcl -source build.tcl; \
	vivado -mode tcl -source upload.tcl; \
	cd ..

dirs:
	mkdir -p ./$(DIR)

program: firmware dirs
	$(OBJCOPY) $(DIR)/firmware.elf -R .data -O binary $(DIR)/ROM.bin
	$(OBJCOPY) $(DIR)/firmware.elf -R .text -O binary $(DIR)/RAM.bin
	hexdump -ve '"%08x\n"' $(DIR)/ROM.bin > $(DIR)/ROM.hex
	hexdump -ve '"%08x\n"' $(DIR)/RAM.bin > $(DIR)/RAM.hex
	# rm $(DIR)/firmware.elf
	rm $(DIR)/ROM.bin
	rm $(DIR)/RAM.bin

firmware: $(OBJ)
	$(LD) -T $(LDSCRIPT) $(OBJ) -o $(DIR)/$@.elf $(LDFLAGS)
	rm $(OBJ)

%.o: %.S
	$(CC) -o $@ -c $^ $(CFLAGS)

%.o: %.c
	$(CC) -o $@ -c $^ $(CFLAGS)

sim: program
	rm -f obj_dir/*.cpp obj_dir/*.o obj_dir/*.a obj_dir/*.vcd obj_dir/V$(TOP)
	$(TB) $(TBFLAGS) $(TBSRC) $(VSRC)
	cd obj_dir && ./V$(TOP)

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
	rm -rf ./obj_dir
	rm $(OBJ)

