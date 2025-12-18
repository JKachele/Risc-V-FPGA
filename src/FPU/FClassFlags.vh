/*************************************************
 *File----------FClassFlags.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 18, 2025 14:53:46 UTC
 ************************************************/

localparam CLASS_BIT_ZERO = 0;
localparam CLASS_BIT_SUB  = 1;
localparam CLASS_BIT_NORM = 2;
localparam CLASS_BIT_INF  = 3;
localparam CLASS_BIT_SNAN = 4;
localparam CLASS_BIT_QNAN = 5;
localparam CLASS_ZERO = 6'b000001;
localparam CLASS_SUB  = 6'b000010;
localparam CLASS_NORM = 6'b000100;
localparam CLASS_INF  = 6'b001000;
localparam CLASS_SNAN = 6'b010000;
localparam CLASS_QNAN = 6'b100000;
localparam INF_NAN_MASK = 6'b111000;
