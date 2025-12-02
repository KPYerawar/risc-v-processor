# 32-bit Multi-Cycle RISC-V Processor

This repository contains the Verilog HDL source code for a 32-bit multi-cycle RISC-V processor (RV32I). The design is optimized for power efficiency and delay reduction, intended for FPGA implementation.

## Project Structure
```text
/risc-v-processor
  |-- alu.v              // Arithmetic Logic Unit
  |-- control.v          // Control Unit FSM
  |-- cpu.v              // CPU Top Module
  |-- decoder.v          // Instruction Decoder
  |-- lsu.v              // Load Store Unit
  |-- pc_unit.v          // Program Counter Logic
  |-- progmem.v          // Program Memory
  |-- regfile.v          // Register File
  |-- top.v              // Top-level System Wrapper
  |-- firmware.hex       // Machine code for testing
  |-- testbench.v        // Simulation Testbench
```
