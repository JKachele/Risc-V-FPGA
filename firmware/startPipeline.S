.equ STACK_BASE, 0x20000
.equ IO_BASE, 0x400000
.equ IO_LEDS, 0x04

.global _start
.section .text
_start:
        li gp, IO_BASE
        li sp, STACK_BASE
        call main
        ebreak
