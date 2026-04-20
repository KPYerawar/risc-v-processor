// =============================================================
//  pc_unit.v  —  Program Counter Unit
//
//  OPTIMIZATIONS:
//  1. PC only updates at WRITEBACK (or EXECUTE for branches) —
//     never toggles during FETCH/DECODE/BYTE/WAIT_LOADING,
//     saving the PC register switching energy on most cycles.
//
//  2. pc_plus_4 and pc_plus_imm are combinational (no extra
//     registers) — they feed the mux that selects next_pc,
//     which is then registered in one step.
//
//  3. next_pc mux is compact: branch/JAL share pc_plus_imm
//     path; JALR uses alu_result directly (already computed
//     in EXECUTE stage as rs1+imm_I).
// =============================================================
module pc_unit(
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  state,
    input  wire        isBtype,
    input  wire        isJAL,
    input  wire        isJALR,
    input  wire        take_branch,
    input  wire [31:0] imm_B,
    input  wire [31:0] imm_J,
    input  wire [31:0] imm_U,
    input  wire [31:0] alu_result,
    output reg  [31:0] pc,
    output wire [31:0] pc_plus_4,
    output wire [31:0] pc_plus_imm
);

    // Gray-code state values (must match control.v)
    localparam EXECUTE   = 5'b00110,
               WRITEBACK = 5'b01110;

    // ----------------------------------------------------------
    // Combinational next-PC logic
    // ----------------------------------------------------------
    assign pc_plus_4   = pc + 32'd4;
    assign pc_plus_imm = pc + (isBtype ? imm_B : isJAL ? imm_J : imm_U);

    wire [31:0] next_pc =
        ((isBtype & take_branch) | isJAL) ? pc_plus_imm :
         isJALR                           ? alu_result   :
                                            pc_plus_4;

    // ----------------------------------------------------------
    // PC register — updates only at end of instruction
    // OPTIMIZATION: PC silent during FETCH/DECODE/BYTE etc.
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            pc <= 32'b0;
        else if ((state == WRITEBACK) || (state == EXECUTE && isBtype))
            pc <= next_pc;
    end

endmodule
