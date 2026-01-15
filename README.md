# Kache-Risc-V
### Risc-V SOC written in verilog

Custom Pipelined 32-Bit Risc-V SOC to run on an FPGA<br>
End goal is to run Linux or a custom OS

#### Current Features
- Full RV32I ISA
- Extensions:
    - (M) Integer Multiply/Divide
    - (A) Atomic memory operations
    - (F) Single-Precision floating point support
    - (C) Compressed instruction support
    - (Zicsr) Control and Status Register support
- Partial Machine Level ISA
    - Supports ecall exceptions and privilaged instructions
- Uses FPGA Block Memory programed during synthesys
- UART for I/O

#### Planed Features
- D Extension for double-precision floating point
- Full Machine and Supervisor Mode ISA support
- Add support for DDR3 memory on the Arty-A7
- Cached memory
- External storage (SPI Flash / Micro SD) for loading programs
- Virtual memory / MMU

#### Other Potential Feautres
- Multicore Support
- V extension for Vector Operations
- Out-of-order processing
- Superscalar (Dual-issue) processing
