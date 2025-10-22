######################################################################
# @author      : Justin Kachele (justin@kachele.com)
# @file        : Makefile
# @created     : Friday Oct 17, 2025 14:39:28 UTC
######################################################################

VC=iverilog
CFLAGS=-DBENCH -DSIM -DPASSTHROUGH_PLL -DBOARD_FREQ=10 -DCPU_FREQ=10
CFLAGS+=-I src/ -I src/Extern/ -I src/Modules/

TB=src/TB_RiscV.v
SRC=src/RiscV.v

BIN=bin
.PHONY: all build dirs clean 

dirs:
	mkdir -p ./$(BIN)

sim: dirs
	$(VC) -o $(BIN)/out $(CFLAGS) $(TB) $(SRC); \
	vvp $(BIN)/out

all: dirs
	cd tcl; \
	vivado -mode tcl -source build.tcl; \
	vivado -mode tcl -source upload.tcl; \
	cd ..

build: dirs
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

