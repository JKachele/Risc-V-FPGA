/*************************************************
 *File----------printf_fp.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Thursday Dec 04, 2025 22:37:40 UTC
 *License-------GNU GPL-3.0
 ************************************************/

extern void putchar(char c);

static void print_int_part(unsigned long long val) {
        char buffer[255];
        char *p = buffer;
        while (val || p == buffer) {
                *(p++) = val % 10;
                val = val / 10;
        }
        while (p != buffer) {
                putchar('0' + *(--p));
        }
}

static void print_frac_part(unsigned long long val, unsigned int exp,
                unsigned int precision) {

        unsigned int bits = 52 - exp;
        unsigned long long div = (1ull << bits);

        // Shift back fractional part
        val = val >> (64 - bits);

        for (int i = 0; i < precision; i++) {
                val *= 10;
                unsigned int digit = val / div;
                val = val % div;
                // Round for last digit
                if (i == precision-1 && val > div/2) {
                        digit = digit == 9 ? 0 : digit + 1;
                }
                putchar(digit + '0');
                if (val == 0)
                        break;
        }
}

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
        // Print negative sign if sign bit set
        if (sign == 1) {
                putchar('-');
        }

        // Convert the integer part to decimal
        print_int_part(intPart);
        putchar('.');

        // Convert fractional part. Default precision if 6 decimal places
        print_frac_part(fracPart, exp, 6);
}

