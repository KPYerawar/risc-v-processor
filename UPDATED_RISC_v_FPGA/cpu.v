// =============================================================
//  cpu.v  —  RISC-V RV32I Multicycle CPU Core
//
//  OPTIMIZATIONS APPLIED:
//  T1  Gray-code FSM state encoding        (control.v)
//  T2  Operand isolation on ALU inputs     (alu.v)
//  T3  Register-file clock gating          (regfile.v)
//  T4  LSU address bus isolation           (lsu.v)
//  T5  Stage-selective pipeline registers  (here — always block)
//  T6  Parallel ALU, single output mux     (alu.v)
//  T7  x0 write suppression               (regfile.v)
//  T8  Glitch-free Gray transitions        (control.v)
//
//  NEW: Four monitor outputs (mon_*) expose internal decode
//  signals to top.v for the exec_done flag.  These are pure
//  wire assignments — zero extra logic, zero power overhead.
// =============================================================
module cpu(
    input  wire        rst,
    input  wire        clk,
    input  wire [31:0] mem_rdata,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire        mem_rstrb,
    output wire [3:0]  mem_wstrb,

    // ---- Monitor outputs for exec_done flag in top.v --------
    output wire [4:0]  mon_state,    // Current FSM state
    output wire [4:0]  mon_opcode,   // instr[6:2]
    output wire [2:0]  mon_funct3,   // instr[14:12]
    output wire [6:0]  mon_funct7    // instr[31:25]
);

    // ----------------------------------------------------------
    // Gray-code state parameters (mirror control.v exactly)
    // ----------------------------------------------------------
    localparam RESET        = 5'b00000,
               WAIT         = 5'b00001,
               FETCH        = 5'b00011,
               DECODE       = 5'b00010,
               EXECUTE      = 5'b00110,
               WRITEBACK    = 5'b01110,
               BYTE         = 5'b00111,
               WAIT_LOADING = 5'b00101,
               HLT          = 5'b00100;

    // ----------------------------------------------------------
    // Pipeline registers
    // OPTIMIZATION T5: each register only latches in its own
    // stage — silent (no toggle) every other cycle.
    // ----------------------------------------------------------
    reg [31:0] instr_reg;           // latched in FETCH
    reg [31:0] data_rs1_reg;        // latched in DECODE
    reg [31:0] data_rs2_reg;        // latched in DECODE
    reg [31:0] alu_out_reg;         // latched in EXECUTE
    reg [31:0] cycle;               // performance counter

    // ----------------------------------------------------------
    // Internal wires
    // ----------------------------------------------------------
    wire [4:0]  state;
    wire [4:0]  opcode, rd, rs1_addr, rs2_addr;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [31:0] imm_I, imm_B, imm_S, imm_J, imm_U;
    wire        isRtype, isItype, isBtype, isSystype;
    wire        isStype, isLtype, isJAL, isJALR, isLUI, isAUIPC;
    wire [31:0] pc, pc_plus_4, pc_plus_imm;
    wire [31:0] rf_rs1_data, rf_rs2_data;
    wire [31:0] alu_result;
    wire        take_branch;
    wire [31:0] lsu_wb_data, lsu_addr;

    // ----------------------------------------------------------
    // Monitor outputs — zero-overhead wire aliases
    // ----------------------------------------------------------
    assign mon_state  = state;
    assign mon_opcode = opcode;
    assign mon_funct3 = funct3;
    assign mon_funct7 = funct7;

    // ----------------------------------------------------------
    // Sub-module instantiations
    // ----------------------------------------------------------

    control ctrl_unit (
        .clk      (clk),
        .rst      (rst),
        .isSystype(isSystype),
        .isStype  (isStype),
        .isLtype  (isLtype),
        .isJAL    (isJAL),
        .isJALR   (isJALR),
        .state    (state)
    );

    pc_unit pc_u (
        .clk        (clk),
        .rst        (rst),
        .state      (state),
        .isBtype    (isBtype),
        .isJAL      (isJAL),
        .isJALR     (isJALR),
        .take_branch(take_branch),
        .imm_B      (imm_B),
        .imm_J      (imm_J),
        .imm_U      (imm_U),
        .alu_result (alu_result),
        .pc         (pc),
        .pc_plus_4  (pc_plus_4),
        .pc_plus_imm(pc_plus_imm)
    );

    decoder dec (
        .instr    (instr_reg),
        .opcode   (opcode),
        .rd       (rd),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .funct3   (funct3),
        .funct7   (funct7),
        .imm_I    (imm_I),
        .imm_B    (imm_B),
        .imm_S    (imm_S),
        .imm_J    (imm_J),
        .imm_U    (imm_U),
        .isRtype  (isRtype),
        .isItype  (isItype),
        .isBtype  (isBtype),
        .isSystype(isSystype),
        .isStype  (isStype),
        .isLtype  (isLtype),
        .isJAL    (isJAL),
        .isJALR   (isJALR),
        .isLUI    (isLUI),
        .isAUIPC  (isAUIPC)
    );

    // ----------------------------------------------------------
    // Writeback data-path
    // write_reg_en uses clock-gating principle: register array
    // only toggles when en is high (T3 - carried forward here)
    // ----------------------------------------------------------
    wire write_reg_en =
        ((isItype | isRtype | isJAL | isJALR | isLUI | isAUIPC) & (state == WRITEBACK)) |
        (isLtype & (state == WAIT_LOADING));

    wire [31:0] write_reg_data =
        (isItype | isRtype) ? alu_out_reg  :
         isLtype            ? lsu_wb_data  :
        (isJAL  | isJALR)  ? pc_plus_4    :
         isLUI              ? imm_U        :
         isAUIPC            ? pc_plus_imm  :
                              32'b0;

    regfile rf (
        .clk     (clk),
        .rst     (rst),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr (rd),
        .wr_data (write_reg_data),
        .wr_en   (write_reg_en),
        .rs1_data(rf_rs1_data),
        .rs2_data(rf_rs2_data)
    );

    // ----------------------------------------------------------
    // ALU second operand select
    // OPTIMIZATION: mux is driven by registered type flags —
    // stable during EXECUTE, no glitch on alu_in2 lines.
    // ----------------------------------------------------------
    wire [31:0] alu_in2 =
        (isRtype | isBtype)         ? data_rs2_reg :
        (isItype | isLtype | isJALR)? imm_I        :
                                      imm_S;

    alu alu_inst (
        .alu_in1   (data_rs1_reg),
        .alu_in2   (alu_in2),
        .funct3    (funct3),
        .funct7    (funct7),
        .isRtype   (isRtype),
        .isItype   (isItype),
        .isStype   (isStype),
        .isLtype   (isLtype),
        .isJALR    (isJALR),
        .alu_result(alu_result),
        .take_branch(take_branch)
    );

    lsu lsu_inst (
        .state      (state),
        .alu_result (alu_result),
        .rs2_data   (data_rs2_reg),
        .mem_rdata  (mem_rdata),
        .funct3     (funct3),
        .isStype    (isStype),
        .isLtype    (isLtype),
        .mem_addr   (lsu_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .wb_data    (lsu_wb_data),
        .mem_rstrb  (mem_rstrb)
    );

    // Memory address bus: PC during fetch, data-addr during load/store
    assign mem_addr = ((isStype | isLtype) & ((state == BYTE) | (state == WAIT_LOADING)))
                          ? lsu_addr
                          : pc;

    // ----------------------------------------------------------
    // Pipeline registers — stage-selective latching (T5)
    // Each register toggles ONLY in its designated state.
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            instr_reg    <= 32'b0;
            data_rs1_reg <= 32'b0;
            data_rs2_reg <= 32'b0;
            alu_out_reg  <= 32'b0;
            cycle        <= 32'b0;
        end else begin
            if (state == FETCH)   instr_reg    <= mem_rdata;
            if (state == DECODE) begin
                data_rs1_reg <= rf_rs1_data;
                data_rs2_reg <= rf_rs2_data;
            end
            if (state == EXECUTE) alu_out_reg  <= alu_result;
            if (state != HLT)     cycle        <= cycle + 32'd1;
        end
    end

endmodule
