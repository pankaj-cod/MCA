// ============================================================================
// mem_interface.v : Cache <-> main-memory block-transfer interface
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module mem_interface (
    input  wire                 clk,
    input  wire                 rst,
    // from controller FSM
    input  wire                 mem_rd,
    input  wire                 mem_wr,
    // datapath
    input  wire [`TAG_W-1:0]    req_tag,
    input  wire [`INDEX_W-1:0]  req_idx,
    input  wire [`TAG_W-1:0]    victim_tag,
    input  wire [`LINE_W-1:0]   victim_line,
    // memory bus
    output wire                 mem_req,
    output wire                 mem_we,
    output wire [`BLK_W-1:0]    mem_addr,
    output wire [`LINE_W-1:0]   mem_wdata,
    output wire [`WORDS_PB-1:0] mem_wmask,
    input  wire                 mem_ready,
    output wire                 done,
    // statistics
    output reg  [31:0]          rd_bursts,
    output reg  [31:0]          wr_bursts
);
    assign mem_req   = mem_rd | mem_wr;
    assign mem_we    = mem_wr;
    assign mem_addr  = mem_wr ? {victim_tag, req_idx} : {req_tag, req_idx};
    assign mem_wdata = victim_line;
    assign mem_wmask = 4'b1111;
    assign done      = mem_ready;

    always @(posedge clk) begin
        if (rst) begin
            rd_bursts <= 0;
            wr_bursts <= 0;
        end else if (mem_ready) begin
            if (mem_wr)      wr_bursts <= wr_bursts + 1;
            else if (mem_rd) rd_bursts <= rd_bursts + 1;
        end
    end
endmodule
