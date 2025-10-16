#!/usr/bin/env sh

######################################################################
# @author      : Justin Kachele (justin@kachele.com)
# @file        : test
# @created     : Wednesday Oct 15, 2025 17:19:05 UTC
#
# @description : Test verilog with iverilog
######################################################################

rm -f a.out
iverilog -DBENCH -DSIM -DPASSTHROUGH_PLL -DBOARD_FREQ=10 -DCPU_FREQ=10 TB_RiscV.v $1 $2
vvp a.out

