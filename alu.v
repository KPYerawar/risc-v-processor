module alu(
    input [31:0] alu_in1,
    input [31:0] alu_in2,
    input [2:0] funct3,
    input [6:0] funct7,
    input isRtype, isItype, isStype, isLtype, isJALR,
    output [31:0] alu_result,
    output take_branch
);

    wire [31:0] ADD = alu_in1 + alu_in2;
    wire [31:0] XOR = alu_in1 ^ alu_in2;
    wire [31:0] OR  = alu_in1 | alu_in2;
    wire [31:0] AND = alu_in1 & alu_in2;
    wire [32:0] SUB = {1'b0, alu_in1} + {1'b1, ~alu_in2} + 1'b1; // 2's comp subtraction

    // Shift operations
    wire [31:0] shift_data_2 = isRtype ? alu_in2 : isItype ? {27'b0, alu_in2[4:0]} : 32'b0;
    wire [31:0] SLL = alu_in1 << shift_data_2;
    wire [31:0] SRL = alu_in1 >> shift_data_2;
    wire [31:0] SRA = $signed(alu_in1) >>> shift_data_2; 

    // Branch Logic
    wire EQUAL = (SUB[31:0] == 0);
    wire NEQUAL = !EQUAL;
    wire LESS_THAN = (alu_in1[31] ^ alu_in2[31]) ? alu_in1[31] : SUB[32];
    wire LESS_THAN_U = SUB[32];
    wire GREATER_THAN = !LESS_THAN;
    wire GREATER_THAN_U = !LESS_THAN_U;

    assign take_branch = ((funct3 == 3'b000) & EQUAL)          |
                         ((funct3 == 3'b111) & GREATER_THAN_U) |
                         ((funct3 == 3'b001) & NEQUAL)         |
                         ((funct3 == 3'b100) & LESS_THAN)      |
                         ((funct3 == 3'b101) & GREATER_THAN)   |
                         ((funct3 == 3'b110) & LESS_THAN_U);

    // ALU Result Mux
    assign alu_result = 
        ((funct3 == 3'b000) & isRtype & ~funct7[5]) ? ADD :
        ((funct3 == 3'b000) & isItype) ? ADD :
        ((funct3 == 3'b000) & ~(isStype | isLtype) & funct7[5]) ? SUB[31:0] :
        (funct3 == 3'b100) ? XOR :
        (funct3 == 3'b110) ? OR :
        (funct3 == 3'b111) ? AND :
        ((funct3 == 3'b010) & !(isStype | isLtype)) ? {31'b0, LESS_THAN} :
        (funct3 == 3'b011) ? {31'b0, LESS_THAN_U} :
        ((funct3 == 3'b001) & (!isStype)) ? SLL :
        ((funct3 == 3'b101) & ~funct7[5]) ? SRL :
        ((funct3 == 3'b101) & funct7[5]) ? SRA :
        (isStype | isLtype | isJALR) ? ADD : 32'b0;

endmodule
