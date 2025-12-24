.equ IO_LEDS, 0x04

.global main
.text
main:
blink:
        # Blink 5 times
        li t0, 5
blink_L0:
        li a0, 0x5555
        sw a0, IO_LEDS(gp)
        # call wait
        li a0, 0xAAAA
        sw a0, IO_LEDS(gp)
        # call wait
        addi t0, t0, -1
        bnez t0, blink_L0
        li a0, 0
        sw a0, IO_LEDS(gp)
        ret
