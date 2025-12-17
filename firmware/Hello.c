/*************************************************
 *File----------Hello.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Nov 19, 2025 21:57:28 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include <stdio.h>

int main(void) {
    // printf("Hello, World!\n");
    float f1 = 826.32185;
    float f2 = 62.458;
    // float f1 = 0.0000000000000000000012345;
    // float f2 = 0.00000000000000000000012563;
    float f = f1 * f2;
    printf("%f * %f = %f\n", f1, f2, f);

    long i;
    i = *(long*)&f;
    printf("\n%x\n", i);

    i = 52775061;
    f = (float)i;
    printf("%f\n", f);

    i = 52775062;
    f = (float)i;
    printf("%f\n", f);

    return 0;
}

