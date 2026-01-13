/*************************************************
 *File----------SBI.h
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 13, 2026 19:35:13 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef SBI_H
#define SBI_H

#include <stdint.h>

#define SBI_SUCCESS                0
#define SBI_ERR_FAILED            -1
#define SBI_ERR_NOT_SUPPORTED     -2
#define SBI_ERR_INVALID_PARAM     -3
#define SBI_ERR_DENIED            -4
#define SBI_ERR_INVALID_ADDRESS   -5
#define SBI_ERR_ALREADY_AVAILABLE -6
#define SBI_ERR_ALREADY_STARTED   -7
#define SBI_ERR_ALREADT_STOPPED   -8
#define SBI_ERR_NO_SHMEM          -9
#define SBI_ERR_INVALID_STATE     -10
#define SBI_ERR_BAD_RANGE         -11
#define SBI_ERR_TIMEOUT           -12
#define SBI_ERR_IO                -13
#define SBI_ERR_DENIED_LOCKOUT    -14

typedef uint8_t u8;
typedef uint32_t u32;

struct sbiret {
        long error;
        union {
                long value;
                unsigned long uvalue;
        };
};

struct trap_frame {
         u32 ra;
         u32 gp;
         u32 tp;
         u32 t0;
         u32 t1;
         u32 t2;
         u32 t3;
         u32 t4;
         u32 t5;
         u32 t6;
         u32 a0;
         u32 a1;
         u32 a2;
         u32 a3;
         u32 a4;
         u32 a5;
         u32 a6;
         u32 a7;
         u32 s0;
         u32 s1;
         u32 s2;
         u32 s3;
         u32 s4;
         u32 s5;
         u32 s6;
         u32 s7;
         u32 s8;
         u32 s9;
         u32 s10;
         u32 s11;
         u32 sp;
} __attribute((packed));


#endif

