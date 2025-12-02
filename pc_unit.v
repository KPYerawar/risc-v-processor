module pc_unit(
    input clk,
    input rst,
    input [3:0] state,
    input isBtype, isJAL, isJALR,
    input take_branch,
    input [31:0] imm_B, imm_J, imm_U,
    input [31:0] alu_result, // For JALR
    output reg [31:0] pc,
    output [31:0] pc_plus_4,
    output [31:0] pc_plus_imm
);

    parameter RESET=0, EXECUTE=4;

    assign pc_plus_4 = pc + 4;
    assign pc_plus_imm = pc + (isBtype ? imm_B : isJAL ? imm_J : imm_U);

    wire [31:0] next_pc = (isBtype & take_branch) | isJAL ? pc_plus_imm :
                          isJALR ? alu_result : pc_plus_4;

    always @(posedge clk) begin
        if (rst) begin
            pc <= 0;
        end else if (state == EXECUTE) begin
            pc <= next_pc;
        end
    end

endmodule
