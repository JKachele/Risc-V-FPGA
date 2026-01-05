/*************************************************
 *File----------riscVDis.cpp
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 22:06:38 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "riscVDis.h"

u32 opCode(u32 instruction) {
        return instruction & 0b1111111;
}

u32 funct3(u32 instruction) {
        return (instruction >> 12) & 0b111;
}

u32 funct7(u32 instruction) {
        return instruction >> 25;
}

bool riscV_isLUI(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b0110111;
}

bool riscV_isAUIPC(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b0010111;
}

bool riscV_isJAL(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b1101111;
}

bool riscV_isJALR(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b1100111;
}

bool riscV_isBranch(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b1100011;
}

bool riscV_isLoad(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b0000011;
}

bool riscV_isStore(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b0100011;
}

bool riscV_isALUI(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b0010011;
}

bool riscV_isALUR(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b0110011;
}

bool riscV_isFENCE(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b0001111;
}

bool riscV_isSYS(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b1110011;
}

bool riscV_isRV32M(u32 instruction) {
        return riscV_isALUR(instruction) && (funct7(instruction) == 1);
}

bool riscV_isMul(u32 instruction) {
        return riscV_isRV32M(instruction) && (funct3(instruction) < 0b100);
}

bool riscV_isDiv(u32 instruction) {
        return riscV_isRV32M(instruction) && (funct3(instruction) >= 0b100);
}

bool riscV_isFPU(u32 instruction) {
        return (instruction & 0b1100000) == 0b1000000;
}

bool riscV_isAMO(u32 instruction) {
        u32 opcode = opCode(instruction);
        return opcode == 0b0101111;
}
