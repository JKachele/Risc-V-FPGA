/*************************************************
 *File----------printf_fp.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Thursday Dec 04, 2025 22:37:40 UTC
 *License-------GNU GPL-3.0
 ************************************************/

extern void putchar(char c);
extern void print_dec(int val);

void printf_fp(unsigned long long val) {
        // Split double into sign, exponent, and signigicand
        unsigned int sign = (val >> 63) & 0x1;
        unsigned int exp = (val >> 52) & 0x7FF;
        unsigned long long signi = val & 0xFFFFFFFFFFFFF;

        // De-Bias the exponent
        exp = exp - 1023;

        // Split significand into integer and fractional parts with the exponent
        // Shift significand to msb
        signi = (signi << 12);
        // shift out the fractional part and add the implicit bit
        unsigned long long intPart = signi >> (64 - exp);
        intPart = intPart | (1 << exp);
        unsigned long long fracPart = signi << exp;

        // Number is now in the form of intPart.fracPart
        // Convert the integer part to decimal
        char buffer[255];
        char *p = buffer;

        putchar('.');
        for (int i = (4*16)-4; i >= 0; i -= 4) {
                putchar("0123456789ABCDEF"[(fracPart >> i) % 16]);
        }
}

