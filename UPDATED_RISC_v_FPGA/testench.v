// =============================================================
//  testbench.v  -  Simulation Testbench
//  FIXED: Updated port connections to match new top.v
//         top now has: led_exec, led_add, led_hb, led_hlt
//         (old exec_done port no longer exists)
// =============================================================
`timescale 1ns/1ps

module testbench;

    reg  rst;
    reg  clk;

    // ── New LED outputs from top.v ────────────────────────
    wire led_exec;   // ANY instruction done (sticky)
    wire led_add;    // ADD / ADDI done      (sticky)
    wire led_hb;     // 1Hz heartbeat
    wire led_hlt;    // CPU halted           (sticky)

    // ── DUT ──────────────────────────────────────────────
    top dut (
        .rst      (rst),
        .clk      (clk),
        .led_exec (led_exec),
        .led_add  (led_add),
        .led_hb   (led_hb),
        .led_hlt  (led_hlt)
    );

    // 10 ns clock period → 100 MHz simulation
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // Reset: hold high for 4 cycles then release
    initial begin
        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst = 1'b0;
    end

    // ── Monitor: print whenever a sticky LED first goes HIGH
    reg prev_exec = 0, prev_add = 0, prev_hlt = 0;

    always @(posedge clk) begin
        if (led_exec && !prev_exec)
            $display("[%0t ns]  led_exec ON  - first instruction completed", $time);
        if (led_add  && !prev_add)
            $display("[%0t ns]  led_add  ON  - ADD/ADDI instruction completed", $time);
        if (led_hlt  && !prev_hlt)
            $display("[%0t ns]  led_hlt  ON  - CPU halted (ECALL/EBREAK)", $time);

        prev_exec <= led_exec;
        prev_add  <= led_add;
        prev_hlt  <= led_hlt;
    end

    // ── Simulation timeout ────────────────────────────────
    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, testbench);
        #50000;
        $display("Simulation complete.");
        $finish;
    end

endmodule
