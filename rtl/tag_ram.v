// ============================================================================
// tag_ram.v : Tag RAM (NLINES x TAG_W). Async read, sync write on refill.
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module tag_ram (
    input  wire                 clk,
    input  wire [`INDEX_W-1:0]  idx,
    input  wire                 we,
    input  wire [`TAG_W-1:0]    tag_in,
    output wire [`TAG_W-1:0]    tag_out
);
    reg [`TAG_W-1:0] mem [0:`NLINES-1];

    integer i;
    initial for (i = 0; i < `NLINES; i = i + 1) mem[i] = {`TAG_W{1'b0}};

    assign tag_out = mem[idx];

    always @(posedge clk)
        if (we) mem[idx] <= tag_in;
endmodule
