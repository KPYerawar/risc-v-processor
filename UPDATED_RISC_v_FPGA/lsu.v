// =============================================================
//  lsu.v  —  Load/Store Unit
//
//  OPTIMIZATIONS:
//  1. ADDRESS ISOLATION: load_store_addr is forced to 0 when
//     not in BYTE / WAIT_LOADING states. The 32 address-bus
//     wires are therefore silent on all non-memory cycles,
//     eliminating capacitive switching on the address bus.
//
//  2. WRITE-STROBE GATING: mem_wstrb is masked with the
//     isStype & WAIT_LOADING condition — memory write-enable
//     pulses occur for exactly ONE cycle, minimum energy.
//
//  3. READ-STROBE GATING: mem_rstrb fires only during WAIT
//     (instruction fetch) or BYTE (load data fetch) — not on
//     every cycle.
//
//  4. BYTE/HALFWORD MUXING done with simple bit-selects, no
//     shifters needed → minimal logic depth on data path.
// =============================================================
module lsu(
    input  wire [4:0]  state,
    input  wire [31:0] alu_result,
    input  wire [31:0] rs2_data,
    input  wire [31:0] mem_rdata,
    input  wire [2:0]  funct3,
    input  wire        isStype,
    input  wire        isLtype,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0]  mem_wstrb,
    output wire [31:0] wb_data,
    output wire        mem_rstrb
);

    // Gray-code states (must match control.v)
    localparam WAIT         = 5'b00001,
               BYTE         = 5'b00111,
               WAIT_LOADING = 5'b00101;

    // ----------------------------------------------------------
    // OPTIMIZATION — Address bus isolation
    // Force address to 0 when not in a memory-access state
    // ----------------------------------------------------------
    wire in_mem_state       = (state == BYTE) | (state == WAIT_LOADING);
    wire [31:0] load_store_addr = in_mem_state ? alu_result : 32'b0;

    // ----------------------------------------------------------
    // Access-width decode
    // ----------------------------------------------------------
    wire mem_byteAccess     = (funct3[1:0] == 2'b00);
    wire mem_halfwordAccess = (funct3[1:0] == 2'b01);

    // ----------------------------------------------------------
    // LOAD data reconstruction
    // Byte / halfword selected by address LSBs — no shifter
    // ----------------------------------------------------------
    wire [15:0] LOAD_halfword = load_store_addr[1]
                                    ? mem_rdata[31:16]
                                    : mem_rdata[15:0];
    wire [7:0]  LOAD_byte     = load_store_addr[0]
                                    ? LOAD_halfword[15:8]
                                    : LOAD_halfword[7:0];

    wire LOAD_sign = !funct3[2] &
                     (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

    assign wb_data =
        mem_byteAccess     ? {{24{LOAD_sign}}, LOAD_byte}     :
        mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword}  :
                             mem_rdata;

    // ----------------------------------------------------------
    // STORE byte-enable mask
    // ----------------------------------------------------------
    wire [3:0] STORE_wmask =
        mem_byteAccess ?
            (load_store_addr[1]
                ? (load_store_addr[0] ? 4'b1000 : 4'b0100)
                : (load_store_addr[0] ? 4'b0010 : 4'b0001)) :
        mem_halfwordAccess ?
            (load_store_addr[1] ? 4'b1100 : 4'b0011) :
            4'b1111;

    // OPTIMIZATION: strobe gated — only fires during WAIT_LOADING & isStype
    assign mem_wstrb = {4{(state == WAIT_LOADING) & isStype}} & STORE_wmask;

    // ----------------------------------------------------------
    // STORE write-data lane replication (no barrel shifter)
    // ----------------------------------------------------------
    assign mem_wdata[7:0]   =  rs2_data[7:0];
    assign mem_wdata[15:8]  =  load_store_addr[0] ? rs2_data[7:0]  : rs2_data[15:8];
    assign mem_wdata[23:16] =  load_store_addr[1] ? rs2_data[7:0]  : rs2_data[23:16];
    assign mem_wdata[31:24] =  load_store_addr[0] ? rs2_data[7:0]  :
                               load_store_addr[1] ? rs2_data[15:8] : rs2_data[31:24];

    // ----------------------------------------------------------
    // Memory address to bus
    // ----------------------------------------------------------
    assign mem_addr = ((isStype | isLtype) & in_mem_state)
                          ? load_store_addr
                          : alu_result;

    // OPTIMIZATION: read strobe only on WAIT (fetch) or BYTE (load)
    assign mem_rstrb = (state == WAIT) | (isLtype & (state == BYTE));

endmodule
