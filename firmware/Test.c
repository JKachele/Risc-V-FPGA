/*************************************************
 *File----------Hello.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Nov 19, 2025 21:57:28 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include <stdio.h>

unsigned int readCSR() {
        unsigned int result;
        asm volatile (
                        "csrr %0, mstatus"
                        : "=r" (result)
            );
        return result;
}

void writeCSR(unsigned int value) {
        asm volatile (
                        "csrw mstatus, %0\n"
                        :
                        : "r"(value)
            );
}

void setCSR(unsigned int mask) {
        asm volatile(
                        "csrs mstatus, %0\n"
                        :
                        : "r"(mask)
            );
}

void clearCSR(unsigned int mask) {
        asm volatile(
                        "csrc mstatus, %0\n"
                        :
                        : "r"(mask)
            );
}

int main(void) {
        // printf("Hello, World!\n");

        unsigned int csrWrite = 0x2572; // 0b0010010101110010
        unsigned int csrSet   = 0x000d; // 0b0000000000001101
        unsigned int csrClear = 0x0070; // 0b0000000001110000

        printf("%x\n", readCSR());
        writeCSR(csrWrite);
        printf("%x\n", readCSR());
        setCSR(csrSet);
        printf("%x\n", readCSR());
        clearCSR(csrClear);
        printf("%x\n", readCSR());

        return 0;
}

