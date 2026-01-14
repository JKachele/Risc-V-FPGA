/*************************************************
 *File----------common.h
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Wednesday Jan 14, 2026 16:48:46 UTC
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdint.h>

typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;

void *memset(void *buf, char c, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
char *strcpy(char *dst, const char *src);
int strcmp(const char *s1, const char *s2);

#endif

