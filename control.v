module control(
    input clk,
    input rst,
    input isSystype,
    input isStype,
    input isLtype,
    input isJAL,
    input isJALR,
    output reg [3:0] state
);

    parameter RESET=0, WAIT=1, FETCH=2, DECODE=3, EXECUTE=4, BYTE=5, WAIT_LOADING=6, HLT=7;

    initial state = 0;

    always @(posedge clk) begin
        if(rst) begin
            state <= RESET;
        end else begin
            case(state)
                RESET: state <= WAIT;
                
                WAIT: state <= FETCH;
                
                FETCH: state <= DECODE;
                
                DECODE: state <= ~isSystype ? EXECUTE : HLT;
                
                EXECUTE: state <= !(isStype | isLtype | isJAL | isJALR) ? WAIT : BYTE;
                
                BYTE: state <= WAIT_LOADING;
                
                WAIT_LOADING: state <= WAIT;
                
                HLT: state <= HLT;
                
                default: state <= RESET;
            endcase
        end
    end

endmodule
