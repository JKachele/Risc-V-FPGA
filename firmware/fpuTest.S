.global main
.section .text

main:
        sw ra, 0(sp)

        fmadd.s fa0, fa1, fa2, fa3
        fmsub.s fa0, fa1, fa2, fa3
        fnmadd.s fa0, fa1, fa2, fa3
        fnmsub.s fa0, fa1, fa2, fa3

        fmul.s fa0, fa1, fa2
        fadd.s fa0, fa1, fa2

        li t0, 0x48
        frrm a4
        fmv.w.x fa0, t0
        fmv.x.w a0, fa0
        call putchar

        li t0, 0x65
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
