.global main
.section .text
main:
        la s0, stuff
        lw s1, 0(s0)
        amoadd.w s2, s1, (s0)
        lw s3, 0(s0)

.section .data
stuff:
        .word 0x12345678
