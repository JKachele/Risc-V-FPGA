.equ STACK_BASE, 0x1800

.equ IO_BASE, 0x400000
.equ IO_LEDS, 0x04
.equ IO_UART_DAT, 0x08
.equ IO_UART_CNTL, 0x10
.equ IO_SSEG, 0x10

.global _start
.text
_start:
        li sp, STACK_BASE
        li gp, IO_BASE

        # Blink 5 times
        li s0, 5
blink:
        li a0, 0x5555
        sw a0, IO_LEDS(gp)
        # call wait
        li a0, 0xAAAA
        sw a0, IO_LEDS(gp)
        # call wait
        addi s0, s0, -1
        bnez s0, blink
        li a0, 0
        sw a0, IO_LEDS(gp)

        ebreak
