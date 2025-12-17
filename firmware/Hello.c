/*************************************************
 *File----------Hello.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Nov 19, 2025 21:57:28 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include <stdio.h>
#include <math.h>

int main(void) {
    // printf("Hello, World!\n");

    int a = 2147483647;
    float f = (float)a;
    int b = (int)f;

    printf("%d -> %f -> %d\n", a, f, b);

    return 0;
}

