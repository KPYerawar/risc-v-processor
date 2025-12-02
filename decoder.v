module decoder(
    input [31:0] instr,
    output [4:0] opcode,
    output [4:0] rd,
    output [4:0] rs1_addr,
    output [4:0] rs2_addr,
    output [2:0] funct3,
    output [6:0] funct7,
    output [31:0] imm_I,
    output [31:0] imm_B,
    output [31:0] imm_S,
    output [31:0] imm_J,
    output [31:0] imm_U,
    output isRtype, isItype, isBtype, isSystype, isStype, isLtype, isJAL, isJALR, isLUI, isAUIPC
);

    assign opcode = instr[6:2];
    assign rd = instr[11:7];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];

    // Sign-extended immediates
    assign imm_I = {{21{instr[31]}}, instr[30:20]};
    assign imm_B = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_S = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    assign imm_J = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    assign imm_U = {instr[31], instr[30:12], 12'h000};

    // Type decoding
    assign isRtype   = (opcode == 5'b01100);
    assign isItype   = (opcode == 5'b00100);
    assign isBtype   = (opcode == 5'b11000);
    assign isSystype = (opcode == 5'b11100);
    assign isStype   = (opcode == 5'b01000);
    assign isLtype   = (opcode == 5'b00000);
    assign isJAL     = (opcode == 5'b11011);
    assign isJALR    = (opcode == 5'b11001);
    assign isLUI     = (opcode == 5'b01101);
    assign isAUIPC   = (opcode == 5'b00101);

endmodule
