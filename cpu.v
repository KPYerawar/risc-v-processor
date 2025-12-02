module cpu(
    input rst, clk,
    input [31:0] mem_rdata,
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output mem_rstrb,
    output reg [31:0] cycle,
    output [3:0] mem_wstrb
);

    // Internal Wires
    wire [31:0] instr_data; // Instruction latched from mem
    reg [31:0] instr_reg;   // Instruction register
    
    wire [31:0] pc, pc_plus_4, pc_plus_imm;
    wire [3:0] state;
    
    // Decoder Outputs
    wire [4:0] opcode, rd, rs1_addr, rs2_addr;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [31:0] imm_I, imm_B, imm_S, imm_J, imm_U;
    wire isRtype, isItype, isBtype, isSystype, isStype, isLtype, isJAL, isJALR, isLUI, isAUIPC;

    // Register File Outputs
    wire [31:0] rf_rs1_data, rf_rs2_data;
    reg [31:0] data_rs1_reg, data_rs2_reg; // Latched RS data

    // ALU Outputs
    wire [31:0] alu_result;
    wire take_branch;
    
    // LSU Outputs
    wire [31:0] lsu_wb_data;
    wire [31:0] lsu_addr;

    // Parameters
    parameter RESET=0, WAIT=1, FETCH=2, DECODE=3, EXECUTE=4, BYTE=5, WAIT_LOADING=6, HLT=7;

    //----------------------------------------------------------------
    // 1. Control Unit
    //----------------------------------------------------------------
    control ctrl_unit (
        .clk(clk), .rst(rst),
        .isSystype(isSystype), .isStype(isStype), .isLtype(isLtype),
        .isJAL(isJAL), .isJALR(isJALR),
        .state(state)
    );

    //----------------------------------------------------------------
    // 2. Program Counter
    //----------------------------------------------------------------
    pc_unit pc_u (
        .clk(clk), .rst(rst), .state(state),
        .isBtype(isBtype), .isJAL(isJAL), .isJALR(isJALR),
        .take_branch(take_branch),
        .imm_B(imm_B), .imm_J(imm_J), .imm_U(imm_U),
        .alu_result(alu_result),
        .pc(pc), .pc_plus_4(pc_plus_4), .pc_plus_imm(pc_plus_imm)
    );

    // Instruction Fetch Register Logic
    always @(posedge clk) begin
        if (rst) instr_reg <= 0;
        else if (state == FETCH) instr_reg <= mem_rdata;
    end

    //----------------------------------------------------------------
    // 3. Decoder
    //----------------------------------------------------------------
    decoder dec (
        .instr(instr_reg),
        .opcode(opcode), .rd(rd),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .funct3(funct3), .funct7(funct7),
        .imm_I(imm_I), .imm_B(imm_B), .imm_S(imm_S), .imm_J(imm_J), .imm_U(imm_U),
        .isRtype(isRtype), .isItype(isItype), .isBtype(isBtype),
        .isSystype(isSystype), .isStype(isStype), .isLtype(isLtype),
        .isJAL(isJAL), .isJALR(isJALR), .isLUI(isLUI), .isAUIPC(isAUIPC)
    );

    //----------------------------------------------------------------
    // 4. Register File
    //----------------------------------------------------------------
    // Write Back Logic
    wire write_reg_en = ((isItype|isRtype|isJAL|isJALR|isLUI|isAUIPC) & (state==EXECUTE)) | 
                        (isLtype & (state==WAIT_LOADING));
    
    wire [31:0] write_reg_data = (isItype | isRtype) ? alu_result :
                                 isLtype ? lsu_wb_data :
                                 (isJAL | isJALR) ? pc_plus_4 :
                                 isLUI ? imm_U :
                                 isAUIPC ? pc_plus_imm : 32'b0;

    regfile rf (
        .clk(clk), .rst(rst),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd),
        .wr_data(write_reg_data), .wr_en(write_reg_en),
        .rs1_data(rf_rs1_data), .rs2_data(rf_rs2_data)
    );

    // Latch Register Data (matches original DECODE state behavior)
    always @(posedge clk) begin
        if (state == DECODE) begin
            data_rs1_reg <= rf_rs1_data;
            data_rs2_reg <= rf_rs2_data;
        end
    end

    //----------------------------------------------------------------
    // 5. ALU
    //----------------------------------------------------------------
    wire [31:0] alu_in2 = (isRtype | isBtype) ? data_rs2_reg : 
                          (isItype | isLtype | isJALR) ? imm_I : imm_S;

    alu alu_inst (
        .alu_in1(data_rs1_reg),
        .alu_in2(alu_in2),
        .funct3(funct3), .funct7(funct7),
        .isRtype(isRtype), .isItype(isItype), .isStype(isStype), .isLtype(isLtype), .isJALR(isJALR),
        .alu_result(alu_result),
        .take_branch(take_branch)
    );

    //----------------------------------------------------------------
    // 6. Load Store Unit
    //----------------------------------------------------------------
    lsu lsu_inst (
        .state(state),
        .alu_result(alu_result),
        .rs2_data(data_rs2_reg),
        .mem_rdata(mem_rdata),
        .funct3(funct3),
        .isStype(isStype), .isLtype(isLtype),
        .mem_addr(lsu_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .wb_data(lsu_wb_data),
        .mem_rstrb(mem_rstrb)
    );

    // Mux for memory address: 
    // If fetching instruction, use PC. If Load/Store, use LSU address.
    assign mem_addr = ((isStype | isLtype) & ((state == BYTE) | (state == WAIT_LOADING))) ? lsu_addr : pc;

    // Cycle Counter
    always @(posedge clk) begin
        if(rst) cycle <= 0;
        else if(state != HLT) cycle <= cycle + 1;
    end

endmodule
