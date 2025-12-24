/*************************************************
 *File----------Hello.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Nov 19, 2025 21:57:28 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "libs/printf.h"
#include <math.h>

static const float f1 = 41.3766783323;
static const float f2 = 78.4895102637;

int main(void) {
        // printf("Hello, World!\n");

        float a = 0.151061f;
        float b = 142.000000f;
        float r = powf(a, b);
        printf("%f\n", r);


        return 0;
}

