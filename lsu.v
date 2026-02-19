module lsu(
    input [3:0] state, // Passed from FSM
    input [31:0] alu_result, // Calculated Address
    input [31:0] rs2_data,   // Data to store
    input [31:0] mem_rdata,  // Data read from memory
    input [2:0] funct3,
    input isStype, isLtype,
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0] mem_wstrb,
    output [31:0] wb_data,    // Data to write back to register
    output mem_rstrb
);

    // Parameters for states  (must match Control Unit)
    parameter WAIT=1, BYTE=5, WAIT_LOADING=6;

    wire load_store_state_flag = (state == BYTE);
    wire [31:0] load_store_addr = (load_store_state_flag | (state == WAIT_LOADING)) ? alu_result : 32'b0;

    wire mem_byteAccess     = (funct3[1:0] == 2'b00);
    wire mem_halfwordAccess = (funct3[1:0] == 2'b01);

    // LOAD Logic
    wire [15:0] LOAD_halfword = load_store_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];
    wire [7:0]  LOAD_byte     = load_store_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];
    
    // Sign extension for Load
    wire LOAD_sign = !funct3[2] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]); // funct3[2] is bit 14 in instr (unsigned flag)
    
    assign wb_data = mem_byteAccess ? {{24{LOAD_sign}}, LOAD_byte} :
                     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} : mem_rdata;

    // STORE Logic
    wire [3:0] STORE_wmask = mem_byteAccess ? 
                                (load_store_addr[1] ? (load_store_addr[0] ? 4'b1000 : 4'b0100) : 
                                                      (load_store_addr[0] ? 4'b0010 : 4'b0001)) :
                             mem_halfwordAccess ? 
                                (load_store_addr[1] ? 4'b1100 : 4'b0011) : 
                                4'b1111;

    assign mem_wstrb = {4{(state == WAIT_LOADING) & isStype}} & STORE_wmask;

    // Memory Interface Outputs
    assign mem_addr = ((isStype | isLtype) & (load_store_state_flag | (state == WAIT_LOADING))) ? load_store_addr : alu_result; // Note: Logic adjusted to pass alu_result as PC when not LS
    assign mem_rstrb = (state == WAIT) | (isLtype & load_store_state_flag);

    assign mem_wdata[7:0]   = rs2_data[7:0];
    assign mem_wdata[15:8]  = load_store_addr[0] ? rs2_data[7:0]  : rs2_data[15:8];
    assign mem_wdata[23:16] = load_store_addr[1] ? rs2_data[7:0]  : rs2_data[23:16];
    assign mem_wdata[31:24] = load_store_addr[0] ? rs2_data[7:0]  :
                              load_store_addr[1] ? rs2_data[15:8] : rs2_data[31:24];

endmodule

