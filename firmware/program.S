.equ STACK_BASE, 0x1800

.equ IO_BASE, 0x400000
.equ IO_LEDS, 0x04
.equ IO_UART_DAT, 0x08
.equ IO_UART_CNTL, 0x10
.equ IO_SSEG, 0x10

# Fixed point numbers
.equ MANDEL_SHIFT, 10
.equ MANDEL_MUL, (1 << MANDEL_SHIFT)

.equ XMIN, -2*MANDEL_MUL
.equ XMAX,  2*MANDEL_MUL
.equ YMIN, -2*MANDEL_MUL
.equ YMAX,  2*MANDEL_MUL	
.equ DX, (XMAX-XMIN)/80
.equ DY, (YMAX-YMIN)/80
.equ NORM_MAX,(4 << MANDEL_SHIFT)

.global _start
.text
_start:
        li sp, STACK_BASE
        li gp, IO_BASE

mandelStart:
        # Blink 5 times
        li s0, 5
blink:
        li a0, 0x5555
        sw a0, IO_LEDS(gp)
        call wait
        li a0, 0xAAAA
        sw a0, IO_LEDS(gp)
        call wait
        addi s0, s0, -1
        bnez s0, blink
        li a0, 0
        sw a0, IO_LEDS(gp)

        li s1, 0
        li s3, XMIN
        li s11, 80

loopY:
        li s0, 0
        li s2, YMIN

loopX:
        mv s4, s2       # Z <= C
        mv s5, s3

        li s10, 9       # 9 Itterations

loopZ:
        mv a0, s4       # Zrr <= (Zr*Zr) >> MANDEL_SHIFT
        mv a1, s4
        call mulsi3
        srli s6, a0, MANDEL_SHIFT
	mv a0, s4       # Zri <- (Zr*Zi) >> (MANDEL_SHIFT-1)
	mv a1, s5
	call mulsi3
	srai s7, a0, MANDEL_SHIFT-1
	mv a0, s5       # Zii <- (Zi*Zi) >> (MANDEL_SHIFT)
	mv a1, s5
	call mulsi3
	srli s8, a0, MANDEL_SHIFT
	sub s4, s6, s8  # Zr <- Zrr - Zii + Cr  
	add s4, s4, s2
        add s5, s7, s3  # Zi <- 2Zri + Cr

        add s6, s6, s8  # if norm > norm max, exit loop
        li  s7, NORM_MAX
	bgt s6, s7, exitZ

        add s10, s10, -1  # iter--, loop if non-zero
	bnez s10, loopZ

exitZ:
        la a0, colorMap
        add a0, a0, s10
        lbu a0, 0(a0)
        call putchar

        add s0, s0, 1
        add s2, s2, DX
        bne s0, s11, loopX

        li a0, 13
        call putchar
        li a0, 10
        call putchar

        add s1, s1, 1
        add s3, s3, DY
        bne s1, s11, loopY

        li t0, 0xffff
        sw t0, IO_LEDS(gp)

        call putchar
        li a0, 13
        call putchar
        li a0, 10
        call putchar

        ebreak


# Multiply: a0 = a0 * a1
mulsi3:
        mv a2, a0
        li a0, 0
mulsi3_L0:
        andi a3, a1, 1
        beqz a3, mulsi3_L1
        add a0, a0, a2
mulsi3_L1:
        srli a1, a1, 1
        slli a2, a2, 1
        bnez a1, mulsi3_L0
        ret


putchar:
        sw a0, IO_UART_DAT(gp)
        li t0, 1
        slli t0, t0, 9
putLoop:
        lw t1, IO_UART_CNTL(gp)
        and t1, t1, t0
        bnez t1, putLoop
        ret


wait:
        li t0, 1
        slli t0, t0, 21
wait_L0:
        addi t0, t0, -1
        bnez t0, wait_L0
        ret


.section .data
colorMap:
        .string " .,:;ox%#@"
