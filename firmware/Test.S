.global main
.section .text
main:
        la s0, stuff
        lw s1, (s0)
        amoadd.w s2, s1, (s0)
        lw s3, (s0)

        lr.w s1, (s0)
        add s1, s1, s1
        sc.w s2, s1, (s0)
        lw s3, (s0)

        lr.w s1, (s0)
        sw s3, (s0)
        add s1, s1, s1
        sc.w s2, s1, (s0)
        lw s3, (s0)

.section .data
stuff:
        .word 0x12345678
