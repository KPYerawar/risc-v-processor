// =============================================================
//  decoder.v  —  Instruction Decoder (Pure Combinational)
//  OPTIMIZATION: 5-bit opcode slice (instr[6:2]) drops the
//  always-constant lower 2 bits [1:0]=11, reducing the width
//  of every comparator from 7 to 5 bits → smaller, faster mux.
//  All immediates are sign-extended here (no repeated logic
//  elsewhere) so downstream units receive clean registered
//  values after DECODE latches them in cpu.v.
// =============================================================
module decoder(
    input  wire [31:0] instr,

    output wire [4:0]  opcode,
    output wire [4:0]  rd,
    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,

    // Sign-extended immediates
    output wire [31:0] imm_I,
    output wire [31:0] imm_B,
    output wire [31:0] imm_S,
    output wire [31:0] imm_J,
    output wire [31:0] imm_U,

    // Instruction-type one-hot flags
    output wire        isRtype,
    output wire        isItype,
    output wire        isBtype,
    output wire        isSystype,
    output wire        isStype,
    output wire        isLtype,
    output wire        isJAL,
    output wire        isJALR,
    output wire        isLUI,
    output wire        isAUIPC
);

    // ----------------------------------------------------------
    // Field extraction
    // ----------------------------------------------------------
    assign opcode   = instr[6:2];       // bits [1:0] always 11
    assign rd       = instr[11:7];
    assign funct3   = instr[14:12];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign funct7   = instr[31:25];

    // ----------------------------------------------------------
    // Sign-extended immediates (all computed in parallel)
    // ----------------------------------------------------------
    assign imm_I = {{21{instr[31]}}, instr[30:20]};
    assign imm_B = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_S = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    assign imm_J = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    assign imm_U = {instr[31:12], 12'h000};

    // ----------------------------------------------------------
    // Type decode — 5-bit opcode comparisons
    // OPTIMIZATION: one-hot flags are simple equality checks,
    // synthesised as a single decoder LUT block, not cascading
    // if-else priority chains.
    // ----------------------------------------------------------
    assign isRtype   = (opcode == 5'b01100);  // OP
    assign isItype   = (opcode == 5'b00100);  // OP-IMM
    assign isBtype   = (opcode == 5'b11000);  // BRANCH
    assign isSystype = (opcode == 5'b11100);  // SYSTEM (ECALL/EBREAK → HLT)
    assign isStype   = (opcode == 5'b01000);  // STORE
    assign isLtype   = (opcode == 5'b00000);  // LOAD
    assign isJAL     = (opcode == 5'b11011);  // JAL
    assign isJALR    = (opcode == 5'b11001);  // JALR
    assign isLUI     = (opcode == 5'b01101);  // LUI
    assign isAUIPC   = (opcode == 5'b00101);  // AUIPC

endmodule
