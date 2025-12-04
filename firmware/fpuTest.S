.global main
.section .text

main:
        sw ra, 0(sp)

        li t0, 0x48
        sw t0, 4(sp)
        flw fa0, 4(sp)
        fsw fa0, 8(sp)
        lw a0, 8(sp)
        call putchar

        li a0, 13
        call putchar
        li a0, 10
        call putchar

        lw ra, 0(sp)
        ret
