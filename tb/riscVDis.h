/*************************************************
 *File----------riscVDis.h
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 22:07:13 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef RISCVDIS_H
#define RISCVDIS_H

#include <cstdint>

typedef uint32_t u32;
typedef uint64_t u64;

bool riscV_isLUI(u32 instruction);
bool riscV_isAUIPC(u32 instruction);
bool riscV_isJAL(u32 instruction);
bool riscV_isJALR(u32 instruction);
bool riscV_isBranch(u32 instruction);
bool riscV_isLoad(u32 instruction);
bool riscV_isStore(u32 instruction);
bool riscV_isALUI(u32 instruction);
bool riscV_isALUR(u32 instruction);
bool riscV_isFENCE(u32 instruction);
bool riscV_isSYS(u32 instruction);
bool riscV_isRV32M(u32 instruction);
bool riscV_isMul(u32 instruction);
bool riscV_isDiv(u32 instruction);
bool riscV_isFPU(u32 instruction);
bool riscV_isAMO(u32 instruction);

#endif

