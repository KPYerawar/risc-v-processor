// =============================================================
//  alu.v  —  Arithmetic Logic Unit
//
//  OPTIMIZATIONS:
//  1. OPERAND ISOLATION: Inputs to each functional unit are
//     forced to 0 when that unit is not selected. Prevents
//     data-dependent toggling inside idle adders/shifters.
//     Every switching event costs dynamic power (½CV²f).
//
//  2. PARALLEL COMPUTE + OUTPUT MUX: All units compute in
//     parallel in one clock phase; the mux at the output selects
//     the correct result. No serial dependency → shortest
//     critical path through the ALU stage.
//
//  3. SHARED SUB UNIT: SUB result is always available (needed
//     for branch comparisons) but is only wired to alu_result
//     when the instruction actually requires subtraction —
//     keeping logic compact without duplication.
// =============================================================
module alu(
    input  wire [31:0] alu_in1,
    input  wire [31:0] alu_in2,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire        isRtype,
    input  wire        isItype,
    input  wire        isStype,
    input  wire        isLtype,
    input  wire        isJALR,
    output wire [31:0] alu_result,
    output wire        take_branch
);

    // ----------------------------------------------------------
    // Operation-class decode (combinational, cheap)
    // ----------------------------------------------------------
    wire is_add_sub = (funct3 == 3'b000);
    wire is_shift   = (funct3 == 3'b001) | (funct3 == 3'b101);
    wire is_compare = (funct3 == 3'b010) | (funct3 == 3'b011);
    // logic group: XOR/OR/AND handled individually below

    // ----------------------------------------------------------
    // OPTIMIZATION T1 — Operand Isolation
    // Mask inputs to 0 when unit is idle → no internal toggling
    // ----------------------------------------------------------
    wire [31:0] in1_add   = is_add_sub ? alu_in1 : 32'b0;
    wire [31:0] in2_add   = is_add_sub ? alu_in2 : 32'b0;

    wire [31:0] in1_shift = is_shift   ? alu_in1 : 32'b0;
    wire [31:0] in2_shift = is_shift   ? alu_in2 : 32'b0;

    // ----------------------------------------------------------
    // Functional Units (all compute in parallel)
    // ----------------------------------------------------------

    // ADD — uses isolated inputs
    wire [31:0] ADD = in1_add + in2_add;

    // SUB — always computed (shared by SUB instruction AND all
    // branch comparisons). Uses full inputs intentionally.
    wire [32:0] SUB = {1'b0, alu_in1} + {1'b1, ~alu_in2} + 33'd1;

    // Shift amount: R-type uses rs2[4:0], I-type uses imm[4:0]
    wire [4:0]  shamt    = isRtype ? in2_shift[4:0] : in2_shift[4:0];
    wire [31:0] SLL      = in1_shift << shamt;
    wire [31:0] SRL      = in1_shift >> shamt;
    wire [31:0] SRA      = $signed(in1_shift) >>> shamt;

    // Logic — isolated by funct3 equality (cheap)
    wire [31:0] XOR = (funct3 == 3'b100) ? (alu_in1 ^ alu_in2) : 32'b0;
    wire [31:0] OR  = (funct3 == 3'b110) ? (alu_in1 | alu_in2) : 32'b0;
    wire [31:0] AND = (funct3 == 3'b111) ? (alu_in1 & alu_in2) : 32'b0;

    // ----------------------------------------------------------
    // Branch Comparators (use SUB result)
    // ----------------------------------------------------------
    wire EQUAL      =  (SUB[31:0] == 32'b0);
    wire NEQUAL     = !EQUAL;
    wire LESS_THAN  =  (alu_in1[31] ^ alu_in2[31]) ? alu_in1[31] : SUB[32];
    wire LESS_THAN_U=  SUB[32];

    assign take_branch =
        ((funct3 == 3'b000) &  EQUAL      ) |   // BEQ
        ((funct3 == 3'b001) &  NEQUAL     ) |   // BNE
        ((funct3 == 3'b100) &  LESS_THAN  ) |   // BLT
        ((funct3 == 3'b101) & !LESS_THAN  ) |   // BGE
        ((funct3 == 3'b110) &  LESS_THAN_U) |   // BLTU
        ((funct3 == 3'b111) & !LESS_THAN_U);    // BGEU

    // ----------------------------------------------------------
    // Output Mux — select correct result
    // OPTIMIZATION: priority chain ordered so common cases
    // (ADD/ADDI) resolve first → shorter average mux path.
    // ----------------------------------------------------------
    assign alu_result =
        // ADD (R-type, funct7[5]=0)
        (is_add_sub &  isRtype & ~funct7[5]) ? ADD          :
        // ADDI (I-type)
        (is_add_sub &  isItype             ) ? ADD          :
        // SUB (R-type, funct7[5]=1)
        (is_add_sub &  isRtype &  funct7[5]) ? SUB[31:0]   :
        // Address calc for STORE / LOAD / JALR — uses ADD
        (isStype | isLtype | isJALR        ) ? ADD          :
        // Logic
        (funct3 == 3'b100)                   ? XOR          :
        (funct3 == 3'b110)                   ? OR           :
        (funct3 == 3'b111)                   ? AND          :
        // Set-less-than (signed)
        (is_compare & (funct3 == 3'b010))    ? {31'b0, LESS_THAN  } :
        // Set-less-than (unsigned)
        (is_compare & (funct3 == 3'b011))    ? {31'b0, LESS_THAN_U} :
        // Shifts
        ((funct3 == 3'b001) & !isStype)      ? SLL          :
        ((funct3 == 3'b101) & ~funct7[5])    ? SRL          :
        ((funct3 == 3'b101) &  funct7[5])    ? SRA          :
                                               32'b0;

endmodule
