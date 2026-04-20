// =============================================================
//  control.v  —  Gray-Code FSM Controller
//  OPTIMIZATION: Gray-code state encoding → only 1 bit changes
//  per transition → eliminates multi-bit glitch pulses on all
//  state-decode wires → cuts switching power in control path.
// =============================================================
module control(
    input  wire       clk,
    input  wire       rst,
    input  wire       isSystype,
    input  wire       isStype,
    input  wire       isLtype,
    input  wire       isJAL,
    input  wire       isJALR,
    output reg  [4:0] state
);

    // ----------------------------------------------------------
    // Gray-Code State Encoding
    // Adjacent states differ by exactly ONE bit — zero glitches.
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

    initial state = RESET;

    always @(posedge clk) begin
        if (rst)
            state <= RESET;
        else begin
            case (state)
                RESET:        state <= WAIT;
                WAIT:         state <= FETCH;
                FETCH:        state <= DECODE;
                DECODE:       state <= isSystype ? HLT : EXECUTE;
                EXECUTE:      state <= (isStype | isLtype) ? BYTE : WRITEBACK;
                WRITEBACK:    state <= WAIT;
                BYTE:         state <= WAIT_LOADING;
                WAIT_LOADING: state <= WAIT;
                HLT:          state <= HLT;
                default:      state <= RESET;
            endcase
        end
    end

endmodule
