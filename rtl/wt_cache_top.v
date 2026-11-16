// ============================================================================
// wt_cache_top.v : Direct-mapped WRITE-THROUGH, NO-WRITE-ALLOCATE cache
//                  (reference design for the memory-traffic comparison)
// ----------------------------------------------------------------------------
//  Same geometry and the same Data/Tag/Valid RAMs + comparator as the
//  write-back cache, but no dirty bits:
//    read  hit  -> return word
//    read  miss -> ALLOCATE block, re-compare, return word
//    write hit  -> update cache word AND write word to memory (WRITE_MEM)
//    write miss -> write word to memory only (no allocate)
//  The CPU stalls until the memory write completes (no write buffer).
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module wt_cache_top (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 cpu_req,
    input  wire                 cpu_we,
    input  wire [`ADDR_W-1:0]   cpu_addr,
    input  wire [`DATA_W-1:0]   cpu_wdata,
    output reg  [`DATA_W-1:0]   cpu_rdata,
    output reg                  cpu_ready,
    output wire                 mem_req,
    output wire                 mem_we,
    output wire [`BLK_W-1:0]    mem_addr,
    output wire [`LINE_W-1:0]   mem_wdata,
    output wire [`WORDS_PB-1:0] mem_wmask,
    input  wire [`LINE_W-1:0]   mem_rdata,
    input  wire                 mem_ready,
    output reg  [31:0]          hit_cnt,
    output reg  [31:0]          miss_cnt,
    output reg  [1:0]           state
);
    localparam IDLE = 2'd0, COMPARE = 2'd1, WRITE_MEM = 2'd2, ALLOCATE = 2'd3;

    reg [`ADDR_W-1:0] req_addr;
    reg               req_we;
    reg [`DATA_W-1:0] req_wdata;
    reg               first_cmp;

    wire [`TAG_W-1:0]   req_tag  = req_addr[`ADDR_W-1 -: `TAG_W];
    wire [`INDEX_W-1:0] req_idx  = req_addr[`OFFSET_W +: `INDEX_W];
    wire [1:0]          req_word = req_addr[3:2];

    wire [`LINE_W-1:0] line_out;
    wire [`TAG_W-1:0]  stored_tag;
    wire               valid, hit;

    wire refill   = (state == ALLOCATE) && mem_ready;
    wire we_word  = (state == COMPARE) && hit && req_we;

    cache_data_ram u_data (
        .clk(clk), .idx(req_idx),
        .we_line(refill), .line_in(mem_rdata),
        .we_word(we_word), .word_sel(req_word), .word_in(req_wdata),
        .line_out(line_out));

    tag_ram u_tag (
        .clk(clk), .idx(req_idx), .we(refill),
        .tag_in(req_tag), .tag_out(stored_tag));

    valid_ram u_valid (
        .clk(clk), .rst(rst), .idx(req_idx), .set(refill), .valid_out(valid));

    tag_comparator u_cmp (
        .req_tag(req_tag), .stored_tag(stored_tag), .valid(valid), .hit(hit));

    // memory bus: block read on allocate, single-word write on WRITE_MEM
    assign mem_req   = (state == ALLOCATE) || (state == WRITE_MEM);
    assign mem_we    = (state == WRITE_MEM);
    assign mem_addr  = {req_tag, req_idx};
    assign mem_wdata = {`WORDS_PB{req_wdata}};
    assign mem_wmask = (state == WRITE_MEM) ? (4'b0001 << req_word) : 4'b0000;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; first_cmp <= 0;
            req_addr <= 0; req_we <= 0; req_wdata <= 0;
            cpu_ready <= 0; cpu_rdata <= 0;
            hit_cnt <= 0; miss_cnt <= 0;
        end else begin
            cpu_ready <= 1'b0;
            case (state)
            IDLE: if (cpu_req) begin
                req_addr <= cpu_addr; req_we <= cpu_we; req_wdata <= cpu_wdata;
                first_cmp <= 1'b1;
                state <= COMPARE;
            end
            COMPARE: begin
                first_cmp <= 1'b0;
                if (first_cmp) begin
                    if (hit) hit_cnt  <= hit_cnt + 1;
                    else     miss_cnt <= miss_cnt + 1;
                end
                if (req_we)            state <= WRITE_MEM;   // always write through
                else if (hit) begin
                    cpu_rdata <= line_out[req_word*`DATA_W +: `DATA_W];
                    cpu_ready <= 1'b1;
                    state     <= IDLE;
                end else               state <= ALLOCATE;
            end
            WRITE_MEM: if (mem_ready) begin
                cpu_ready <= 1'b1;
                state     <= IDLE;
            end
            ALLOCATE: if (mem_ready) state <= COMPARE;
            endcase
        end
    end
endmodule
