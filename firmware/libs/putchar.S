.equ IO_UART_DAT, 0x08
.equ IO_UART_CNTL, 0x10

.global putchar
.text
putchar:
        sw a0, IO_UART_DAT(gp)
        li t0, 1
        slli t0, t0, 9
putLoop:
        lw t1, IO_UART_CNTL(gp)
        and t1, t1, t0
        bnez t1, putLoop
        ret
