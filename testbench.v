module testbench;
    reg clk;
    reg rst;
    wire [31:0] cycle;

    // Instantiate the Top Module
    top uut (
        .clk(clk),
        .rst(rst),
        .cycle(cycle)
    );

    // Clock Generation (Assuming 1ns time step, #5 = 5ns half cycle -> 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        // ---------------------------------------------------------
        // GTKWave Dump Commands
        // ---------------------------------------------------------
        $dumpfile("cpu_tb.vcd"); // Name of the output file
        $dumpvars(0, testbench); // Dump all variables (level 0) starting from 'testbench' module
        // ---------------------------------------------------------

        // Reset Sequence
        rst = 1;
        #20;       // Hold reset for 20 time units
        rst = 0;   // Release reset
        
        // Run simulation
        #5000;     // Run for 5000 time units
        $finish;   // End simulation
    end

    // Monitor cycle count in console
    initial begin
        $monitor("Time: %0t | Cycle: %d", $time, cycle);
    end

endmodule
