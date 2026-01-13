/*************************************************
 *File----------kernel.h
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 13, 2026 14:47:25 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef KERNEL_H
#define KERNEL_H

typedef unsigned char uint8_t;
typedef uint8_t u8;
typedef unsigned int uint32_t;
typedef uint32_t u32;
typedef uint32_t size_t;

struct sbiret {
        long error;
        long value;
};

#endif

