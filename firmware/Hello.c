/*************************************************
 *File----------Hello.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Nov 19, 2025 21:57:28 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "libs/printf.h"
#include <math.h>

int main(void) {
        // printf("Hello, World!\n");

        float a = NAN;
        float b = 3.14f;
        float r = a / b;
        printf("%f\n", r);


        return 0;
}

