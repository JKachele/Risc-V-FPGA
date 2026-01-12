/*************************************************
 *File----------Hello.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Nov 19, 2025 21:57:28 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include <stdio.h>

void printMachine() {
        printf("In Machine Mode\n");
}

void printMTrap() {
        printf("In Machine Trap\n");
}

void printSupervisor() {
        printf("In Supervisor Mode\n");
}

void printSTrap() {
        printf("In Supervisor Trap\n");
}

void printUser() {
        printf("In User Mode\n");
}

