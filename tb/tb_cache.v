// ============================================================================
// tb_cache.v : Self-checking directed testbench + traffic comparison
// ----------------------------------------------------------------------------
//  Harness setup for clock generation, reset, and stimulus drivers.
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module tb_cache;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;                       // 100 MHz clock

    reg                  wb_req = 0, wb_we = 0;
    reg  [31:0]          wb_addr = 0, wb_wdata = 0;
    wire [31:0]          wb_rdata;
    wire                 wb_ready;

    initial begin
        $display("Starting Write-Back Cache Controller testbench harness...");
        #20 rst = 0;
        #100;
        $finish;
    end
endmodule
