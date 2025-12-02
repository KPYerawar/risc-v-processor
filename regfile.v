module regfile(
    input clk,
    input rst,
    input [4:0] rs1_addr,
    input [4:0] rs2_addr,
    input [4:0] rd_addr,
    input [31:0] wr_data,
    input wr_en,
    output [31:0] rs1_data,
    output [31:0] rs2_data
);

    reg [31:0] registers[0:31];

    // Asynchronous read (to match original behavior of latching in DECODE)
    assign rs1_data = registers[rs1_addr];
    assign rs2_data = registers[rs2_addr];

    integer i;
    initial begin
        for(i=0; i<32; i=i+1) registers[i] = 0;
    end

    always @(posedge clk) begin
        if (wr_en && rd_addr != 0) begin
            registers[rd_addr] <= wr_data;
        end
    end

endmodule
