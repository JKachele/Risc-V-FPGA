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

.global main
.text
main:
        # Store return address and saved registers on the stack
        addi sp, sp, -52
        sw ra ,  0(sp)
        sw s0 ,  4(sp)
        sw s1 ,  8(sp)
        sw s2 , 12(sp)
        sw s3 , 16(sp)
        sw s4 , 20(sp)
        sw s5 , 24(sp)
        sw s6 , 28(sp)
        sw s7 , 32(sp)
        sw s8 , 36(sp)
        sw s9 , 40(sp)
        sw s10, 44(sp)
        sw s11, 48(sp)

mandelStart:
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
        call __mulsi3
        srli s6, a0, MANDEL_SHIFT
	mv a0, s4       # Zri <- (Zr*Zi) >> (MANDEL_SHIFT-1)
	mv a1, s5
	call __mulsi3
	srai s7, a0, MANDEL_SHIFT-1
	mv a0, s5       # Zii <- (Zi*Zi) >> (MANDEL_SHIFT)
	mv a1, s5
	call __mulsi3
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

        call putchar
        li a0, 13
        call putchar
        li a0, 10
        call putchar

        # load return address and saved registers from the stack
        lw ra ,  0(sp)
        lw s0 ,  4(sp)
        lw s1 ,  8(sp)
        lw s2 , 12(sp)
        lw s3 , 16(sp)
        lw s4 , 20(sp)
        lw s5 , 24(sp)
        lw s6 , 28(sp)
        lw s7 , 32(sp)
        lw s8 , 36(sp)
        lw s9 , 40(sp)
        lw s10, 44(sp)
        lw s11, 48(sp)
        addi sp, sp, 52
        ret


# Multiply: a0 = a0 * a1
# mulsi3:
#         mv a2, a0
#         li a0, 0
# mulsi3_L0:
#         andi a3, a1, 1
#         beqz a3, mulsi3_L1
#         add a0, a0, a2
# mulsi3_L1:
#         srli a1, a1, 1
#         slli a2, a2, 1
#         bnez a1, mulsi3_L0
#         ret


.section .data
colorMap:
        .string " .,:;ox%#@"
