// ============================================================================
// valid_ram.v : Valid-bit array. Cleared on reset (all lines invalid),
//               set when a line is refilled from memory.
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module valid_ram (
    input  wire                 clk,
    input  wire                 rst,
    input  wire [`INDEX_W-1:0]  idx,
    input  wire                 set,
    output wire                 valid_out
);
    reg [`NLINES-1:0] valid;

    assign valid_out = valid[idx];

    always @(posedge clk) begin
        if (rst)       valid      <= {`NLINES{1'b0}};
        else if (set)  valid[idx] <= 1'b1;
    end
endmodule
