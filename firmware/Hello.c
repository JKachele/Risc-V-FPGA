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
    float f = 826.32185;
    float f2 = 62.458;
    float f3 = f * f2;
    printf("%f\n", f3);

    float f4 = 51610.40625;
    if (f3 < f4) {
            printf("Less!\n");
    } else if (f3 > f4){
            printf("More!\n");
    } else {
            printf("Equal!\n");
    }
    return 0;
}

