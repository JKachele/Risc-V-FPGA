# 5-Stage RISC Pipeline

## Fetch Unit
- Contains Program Counter
- Checks if compressed instruction
- Increments PC 2 or 4 based off if instruction is compressed
- Updated PC with branch prediction from Decode and Execute units
- Fetched instruction from instruction memory based off PC
### Fetch-Decode Interface
   - Fetched Instruction
   - Program Counter
   - Is compressed instruction

## Decode Unit
- Uncompressed instruction if compressed
- Decodes instruction into its OpCode, Registers, Immedaites, and function fields
- predicts branching instructions
   - GShare dynamic branch prediction
   - Return address stack
- Handles traps (Exceptions / Interupts)
   - Sets privilage level
   - Sets PC to trap handler
### Decode-Execute Interface
- Instruction
- PC
- Decoded OpCode
- Register IDs
- Function Fields
- Immediates
- Writeback Enable
- Branch prediction

## Execute Unit
- Fetches register values
    - Uses forwarded values from Memory/Writeback units if needed
- Executes ALU opperations
   - Dividing and some FPU opps take multiple clocks
   - Stall signal used to halt processor during computations
- Reads data fom memory/IO
   - Used in atomic memory opperations
- Fetches CSR values and applies CSR opperations
- Calculates branch condition and corrcts PC if needed
### Execute-Memory Interface
- Instruction
- PC
- Decoded instruction fields needed for memory ops
- Value read from memory
- Value read from CSRs
- Memory address
- Result from all ALU ops
- Writeback Enable

## Memory Unit
- Sets LRSC Flags
- Stores data in memory/IO
- Aligns and extends data read from memory
- Writes to CSRs
### Memory-Writeback Interface
- Instruction
- PC
- Writeback Enable
- Writeback data
- Writeback register

## Writeback Unit
- Writes data to registers
