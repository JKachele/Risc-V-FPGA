.global wait
.text
wait:
        li t0, 1
        slli t0, t0, 21
wait_L0:
        addi t0, t0, -1
        bnez t0, wait_L0
        ret
