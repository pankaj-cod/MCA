// ============================================================================
// dirty_ram.v : Dirty-bit array for the write-back policy.
//   set : CPU write hit  -> line now differs from main memory
//   clr : line refilled  -> fresh copy, identical to memory
//   Cleared on reset. `clr` has priority over `set` (never both in practice).
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module dirty_ram (
    input  wire                 clk,
    input  wire                 rst,
    input  wire [`INDEX_W-1:0]  idx,
    input  wire                 set,
    input  wire                 clr,
    output wire                 dirty_out
);
    reg [`NLINES-1:0] dirty;

    assign dirty_out = dirty[idx];

    always @(posedge clk) begin
        if (rst)       dirty      <= {`NLINES{1'b0}};
        else if (clr)  dirty[idx] <= 1'b0;
        else if (set)  dirty[idx] <= 1'b1;
    end
endmodule
