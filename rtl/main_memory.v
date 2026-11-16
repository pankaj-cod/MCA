// ============================================================================
// main_memory.v : Behavioural main-memory model with fixed latency and
//                 memory-traffic counters (simulation model).
// ----------------------------------------------------------------------------
//  - 4096 blocks x 128 bit (64 KiB). Block address = byte address >> 4.
//  - Each transaction takes LATENCY cycles, then mem_ready pulses for 1 cycle.
//  - Word-granular write mask so a write-through cache can store one word.
//  - Counters: transactions and 32-bit words moved in each direction.
//  - Initial content: word at word-address W holds 32'hA000_0000 | W.
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module main_memory #(
    parameter LATENCY = 10,
    parameter DEPTH_W = 12            // 2^12 blocks
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 mem_req,
    input  wire                 mem_we,
    input  wire [`BLK_W-1:0]    mem_addr,
    input  wire [`LINE_W-1:0]   mem_wdata,
    input  wire [`WORDS_PB-1:0] mem_wmask,
    output reg  [`LINE_W-1:0]   mem_rdata,
    output reg                  mem_ready,
    // traffic statistics
    output reg  [31:0]          rd_txn,
    output reg  [31:0]          wr_txn,
    output reg  [31:0]          rd_words,
    output reg  [31:0]          wr_words,
    output reg  [31:0]          busy_cycles
);
    reg [`LINE_W-1:0] mem [0:(1<<DEPTH_W)-1];

    reg                 busy;
    reg [15:0]          cnt;
    reg                 l_we;
    reg [DEPTH_W-1:0]   l_addr;
    reg [`LINE_W-1:0]   l_wdata;
    reg [`WORDS_PB-1:0] l_mask;

    // ---- (re)load the reference pattern; callable from the testbench ----
    task init;
        integer b, w;
        begin
            for (b = 0; b < (1<<DEPTH_W); b = b + 1)
                for (w = 0; w < `WORDS_PB; w = w + 1)
                    mem[b][w*32 +: 32] = 32'hA000_0000 | (b*`WORDS_PB + w);
        end
    endtask
    initial init;

    function [2:0] popcnt4(input [3:0] m);
        popcnt4 = m[0] + m[1] + m[2] + m[3];
    endfunction

    integer w;
    always @(posedge clk) begin
        if (rst) begin
            busy <= 0; cnt <= 0; mem_ready <= 0; mem_rdata <= 0;
            rd_txn <= 0; wr_txn <= 0; rd_words <= 0; wr_words <= 0;
            busy_cycles <= 0;
        end else begin
            mem_ready <= 1'b0;
            if (busy) begin
                busy_cycles <= busy_cycles + 1;
                if (cnt == LATENCY-1) begin
                    busy      <= 1'b0;
                    mem_ready <= 1'b1;
                    if (l_we) begin
                        for (w = 0; w < `WORDS_PB; w = w + 1)
                            if (l_mask[w]) mem[l_addr][w*32 +: 32] <= l_wdata[w*32 +: 32];
                        wr_txn   <= wr_txn + 1;
                        wr_words <= wr_words + popcnt4(l_mask);
                    end else begin
                        mem_rdata <= mem[l_addr];
                        rd_txn    <= rd_txn + 1;
                        rd_words  <= rd_words + `WORDS_PB;
                    end
                end else
                    cnt <= cnt + 1;
            end else if (mem_req && !mem_ready) begin
                busy    <= 1'b1;
                cnt     <= 0;
                l_we    <= mem_we;
                l_addr  <= mem_addr[DEPTH_W-1:0];
                l_wdata <= mem_wdata;
                l_mask  <= mem_wmask;
            end
        end
    end
endmodule
