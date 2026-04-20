// =============================================================
//  progmem.v  —  Program + Data Memory (32-bit word, byte-enable)
//
//  OPTIMIZATION: Read is gated by rd_strobe — the memory array
//  output register only toggles when the CPU actually requests
//  data. On non-read cycles the output is held, preventing
//  unnecessary bus toggling downstream.
// =============================================================
module progmem(
    input  wire        rst,
    input  wire        clk,
    input  wire [31:0] addr,
    input  wire [31:0] data_in,
    input  wire        rd_strobe,
    input  wire [3:0]  wr_strobe,
    output reg  [31:0] data_out
);

    // 1 KB memory — 256 words of 32 bits each
    reg [31:0] mem [0:255];

    // Byte-addressed → word index = addr[9:2]
    wire [7:0] word_addr = addr[9:2];

    // Initialise from firmware hex image
    initial $readmemh("firmware.hex", mem);

    // ----------------------------------------------------------
    // Synchronous read — gated by rd_strobe
    // OPTIMIZATION: data_out register silent on write cycles
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            data_out <= 32'b0;
        else if (rd_strobe)
            data_out <= mem[word_addr];
    end

    // ----------------------------------------------------------
    // Byte-enable synchronous write
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            if (wr_strobe[0]) mem[word_addr][7:0]   <= data_in[7:0];
            if (wr_strobe[1]) mem[word_addr][15:8]  <= data_in[15:8];
            if (wr_strobe[2]) mem[word_addr][23:16] <= data_in[23:16];
            if (wr_strobe[3]) mem[word_addr][31:24] <= data_in[31:24];
        end
    end

endmodule
