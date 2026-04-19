// =============================================================
//  top.v  —  SoC Top-Level
//
//  NEW: exec_done output port
//       Asserted HIGH for exactly ONE clock cycle whenever an
//       ADD (R-type) or ADDI (I-type) instruction retires at
//       the WRITEBACK stage.  Connect to an LED on the FPGA.
//
//  POWER NOTE: exec_done is a registered 1-bit signal — no
//  combinational glitches reach the LED driver.  Gray-code
//  WRITEBACK (01110) has a single-bit entry transition, so the
//  state comparison is hazard-free.
// =============================================================
// =============================================================
//  top.v  -  FPGA Implementation (Basys3 / Nexys / Artix-7)
//
//  PROBLEMS FIXED vs old top.v:
//  ─────────────────────────────────────────────────────────
//  1. OLD: exec_done was a 1-cycle pulse (10ns @ 100MHz)
//          → LED glows for 10 nanoseconds → INVISIBLE to eye
//     NEW: "sticky latch" - LED turns ON the moment ANY
//          operation completes and stays ON permanently.
//          Only a board reset (btn) clears it.
//
//  2. OLD: Only ADD/ADDI triggered the flag.
//     NEW: ANY instruction that reaches WRITEBACK or
//          WAIT_LOADING (load) fires the LED.
//          That way even the very first instruction lights it.
//
//  3. NEW: 1Hz heartbeat LED → confirms clock is running.
//          If led_hb blinks, clock is alive.
//          If led_exec still dark → firmware issue, not clock.
//
//  PORTS → map these in your .xdc constraint file (Basys3):
//  ─────────────────────────────────────────────────────────
//  clk       → W5   (100MHz oscillator)
//  rst       → U18  (btnC - ACTIVE HIGH)
//  led_exec  → U16  (LD0) sticky ON once any instr completes
//  led_hb    → E19  (LD1) 1Hz blink - clock alive indicator
//  led_add   → U19  (LD2) sticky ON once ADD/ADDI seen
//  led_hlt   → V19  (LD3) sticky ON when CPU halts (ECALL)
// =============================================================

module top(
    input  wire clk,        // 100 MHz board oscillator
    input  wire rst,        // Active-HIGH reset (centre button)
    output reg  led_exec,   // ANY instruction done  (sticky ON)
    output reg  led_add,    // ADD / ADDI done        (sticky ON)
    output reg  led_hb,     // 1 Hz heartbeat blink
    output reg  led_hlt     // CPU halted             (sticky ON)
);

    // =========================================================
    // 1. HEARTBEAT - 100MHz → 1Hz toggle
    //    Proves the clock is alive before debugging anything else
    // =========================================================
    reg [26:0] hb_cnt;
    localparam HB_TOP = 27'd49_999_999; // toggle every 0.5s → 1Hz blink

    always @(posedge clk) begin
        if (rst) begin
            hb_cnt <= 27'd0;
            led_hb <= 1'b0;
        end else if (hb_cnt == HB_TOP) begin
            hb_cnt <= 27'd0;
            led_hb <= ~led_hb;
        end else begin
            hb_cnt <= hb_cnt + 27'd1;
        end
    end

    // =========================================================
    // 2. CPU ↔ MEMORY WIRES
    // =========================================================
    wire [31:0] mem_rdata, mem_wdata, addr;
    wire        rstrb;
    wire [3:0]  wr_strobe;

    wire [4:0]  mon_state;
    wire [4:0]  mon_opcode;
    wire [2:0]  mon_funct3;
    wire [6:0]  mon_funct7;

    // =========================================================
    // 3. CPU
    // =========================================================
    cpu cpu0 (
        .rst        (rst),
        .clk        (clk),
        .mem_rdata  (mem_rdata),
        .mem_addr   (addr),
        .mem_rstrb  (rstrb),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (wr_strobe),
        .mon_state  (mon_state),
        .mon_opcode (mon_opcode),
        .mon_funct3 (mon_funct3),
        .mon_funct7 (mon_funct7)
    );

    // =========================================================
    // 4. MEMORY
    // =========================================================
    progmem mem0 (
        .rst        (rst),
        .clk        (clk),
        .addr       (addr),
        .data_in    (mem_wdata),
        .rd_strobe  (rstrb),
        .wr_strobe  (wr_strobe),
        .data_out   (mem_rdata)
    );

    // =========================================================
    // 5. GRAY-CODE STATE CONSTANTS (must match control.v)
    // =========================================================
    localparam WRITEBACK    = 5'b01110;
    localparam WAIT_LOADING = 5'b00101;
    localparam HLT          = 5'b00100;

    // =========================================================
    // 6. OPERATION DETECT WIRES
    // =========================================================

    // Any instruction retiring (R/I/J/U types)
    wire instr_wb   = (mon_state == WRITEBACK);

    // Load instruction retiring
    wire instr_load = (mon_state == WAIT_LOADING) &&
                      (mon_opcode == 5'b00000);

    // ANY operation completed this cycle
    wire any_done   = instr_wb | instr_load;

    // ADD (R-type, funct7[5]=0 distinguishes from SUB)
    wire is_ADD     = (mon_opcode == 5'b01100) &&
                      (mon_funct3 == 3'b000)   &&
                      (mon_funct7[5] == 1'b0);

    // ADDI (I-type, funct3=000)
    wire is_ADDI    = (mon_opcode == 5'b00100) &&
                      (mon_funct3 == 3'b000);

    // ADD/ADDI retiring
    wire add_done   = instr_wb && (is_ADD || is_ADDI);

    // CPU entered HLT state
    wire halted     = (mon_state == HLT);

    // =========================================================
    // 7. STICKY LED LATCHES
    //
    //    WHY STICKY?
    //    At 100MHz each clock = 10ns.
    //    A 1-cycle pulse lights LED for 10ns → eye sees nothing.
    //    Sticky latch: once SET it stays SET until rst pressed.
    //    Human eye easily sees a permanently lit LED.
    //
    //    HOW TO TEST on board:
    //    1. Press rst → all LEDs OFF
    //    2. Release rst → CPU starts running firmware
    //    3. led_hb blinks at 1Hz  (clock confirmed alive)
    //    4. led_exec glows solid   (first instruction done)
    //    5. led_add  glows solid   (if ADD/ADDI in firmware)
    //    6. led_hlt  glows solid   (if firmware ends with ECALL)
    // =========================================================
    always @(posedge clk) begin
        if (rst) begin
            led_exec <= 1'b0;
            led_add  <= 1'b0;
            led_hlt  <= 1'b0;
        end else begin
            // Once HIGH, OR keeps it HIGH forever (sticky)
            led_exec <= led_exec | any_done;
            led_add  <= led_add  | add_done;
            led_hlt  <= led_hlt  | halted;
        end
    end

endmodule

// =============================================================
//  VIVADO XDC - paste into your constraints file
//  (Basys3 pin mapping)
// =============================================================
//
//  ## 100 MHz Clock
//  set_property PACKAGE_PIN W5    [get_ports clk]
//  set_property IOSTANDARD LVCMOS33 [get_ports clk]
//  create_clock -add -name sys_clk -period 10.00 -waveform {0 5} [get_ports clk]
//
//  ## Reset - Centre button (active HIGH on Basys3)
//  set_property PACKAGE_PIN U18   [get_ports rst]
//  set_property IOSTANDARD LVCMOS33 [get_ports rst]
//
//  ## LD0 - Any instruction done (sticky)
//  set_property PACKAGE_PIN U16   [get_ports led_exec]
//  set_property IOSTANDARD LVCMOS33 [get_ports led_exec]
//
//  ## LD1 - Heartbeat 1Hz blink
//  set_property PACKAGE_PIN E19   [get_ports led_hb]
//  set_property IOSTANDARD LVCMOS33 [get_ports led_hb]
//
//  ## LD2 - ADD/ADDI done (sticky)
//  set_property PACKAGE_PIN U19   [get_ports led_add]
//  set_property IOSTANDARD LVCMOS33 [get_ports led_add]
//
//  ## LD3 - CPU halted (sticky)
//  set_property PACKAGE_PIN V19   [get_ports led_hlt]
//  set_property IOSTANDARD LVCMOS33 [get_ports led_hlt]
//
// =============================================================
