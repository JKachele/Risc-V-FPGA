#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wimplicit-function-declaration"
#pragma GCC diagnostic ignored "-Wimplicit-int"

#define RISCV
#define TIME
#define USE_MYSTDLIB

#include <stdio.h>
#include <string.h>

#include "dhrystones/dhry_1.c"
#include "dhrystones/dhry_2.c"
#include "dhrystones/stubs.c"

#pragma GCC diagnostic pop
