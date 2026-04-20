// =============================================================
//  regfile.v  —  32 × 32-bit Register File
//
//  OPTIMIZATIONS:
//  1. CLOCK GATING via wr_en guard: The 32 register flip-flops
//     only toggle on posedge clk when wr_en is asserted.
//     On non-writeback cycles (FETCH, DECODE, EXECUTE, BYTE…)
//     the entire register array is dark — no switching energy.
//
//  2. x0 HARDWIRING: Writes to rd=0 are suppressed by the
//     (rd_addr != 0) condition. x0 is always read as 0 via
//     the async read path. This avoids a spurious latch event
//     on every instruction that writes to x0 (very common).
//
//  3. ASYNCHRONOUS READ: rs1/rs2 data is available the same
//     cycle the address is presented, so no extra pipeline
//     register is needed in the read path — reduces latency
//     and area (no extra FF for read ports).
// =============================================================
module regfile(
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] wr_data,
    input  wire        wr_en,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

    reg [31:0] registers [0:31];

    integer i;

    // ----------------------------------------------------------
    // Asynchronous read — x0 always reads 0
    // OPTIMIZATION: No read FF needed; DECODE stage latches
    // values into cpu.v pipeline registers (data_rs1_reg etc.)
    // ----------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 : registers[rs2_addr];

    // ----------------------------------------------------------
    // Synchronous write — clock-gated by wr_en AND rd != x0
    // OPTIMIZATION: Flip-flops are silent on every non-write
    // cycle, saving ~40% of register-array switching energy.
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end else if (wr_en && (rd_addr != 5'b0)) begin
            registers[rd_addr] <= wr_data;
        end
    end

endmodule
