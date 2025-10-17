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
SRC_DIST=src/RiscVDist.v

BIN=bin
.PHONY: clean

all: dirs build

dirs:
	mkdir -p ./$(BIN)

sim: all
	vvp $(BIN)/out

build: dirs
	$(VC) -o $(BIN)/out $(CFLAGS) $(TB) $(SRC)

simDist: buildDist
	vvp $(BIN)/out

buildDist: dirs
	$(VC) -o $(BIN)/out $(CFLAGS) $(TB) $(SRC_DIST)

clean:
	rm -rf ./bin

