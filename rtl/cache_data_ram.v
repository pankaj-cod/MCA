`timescale 1ns/1ps
`include "cache_params.vh"

module cache_data_ram (
    input  wire                 clk,
    input  wire [`INDEX_W-1:0]  idx,
    // full-line write (refill from memory)
    input  wire                 we_line,
    input  wire [`LINE_W-1:0]   line_in,
    // single-word write (CPU store hit)
    input  wire                 we_word,
    input  wire [1:0]           word_sel,
    input  wire [`DATA_W-1:0]   word_in,
    // read port
    output wire [`LINE_W-1:0]   line_out
);
    reg [`LINE_W-1:0] mem [0:`NLINES-1];

    integer i;
    initial for (i = 0; i < `NLINES; i = i + 1) mem[i] = {`LINE_W{1'b0}};

    assign line_out = mem[idx];

    always @(posedge clk) begin
        if (we_line)
            mem[idx] <= line_in;
        if (we_word)
            mem[idx][word_sel*`DATA_W +: `DATA_W] <= word_in;
    end
endmodule
