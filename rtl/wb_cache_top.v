// ============================================================================
// wb_cache_top.v : Direct-mapped WRITE-BACK, WRITE-ALLOCATE cache
// ----------------------------------------------------------------------------
//  Integrates: Cache Data RAM, Tag RAM, Valid RAM, Dirty-Bit RAM,
//              Tag Comparator, Write-Back FSM, Memory Interface.
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module wb_cache_top (
    input  wire                 clk,
    input  wire                 rst,
    // CPU interface
    input  wire                 cpu_req,
    input  wire                 cpu_we,
    input  wire [`ADDR_W-1:0]   cpu_addr,
    input  wire [`DATA_W-1:0]   cpu_wdata,
    output reg  [`DATA_W-1:0]   cpu_rdata,
    output reg                  cpu_ready,
    // main-memory interface
    output wire                 mem_req,
    output wire                 mem_we,
    output wire [`BLK_W-1:0]    mem_addr,
    output wire [`LINE_W-1:0]   mem_wdata,
    output wire [`WORDS_PB-1:0] mem_wmask,
    input  wire [`LINE_W-1:0]   mem_rdata,
    input  wire                 mem_ready,
    // performance counters
    output reg  [31:0]          hit_cnt,
    output reg  [31:0]          miss_cnt,
    output reg  [31:0]          wb_cnt,
    output wire [31:0]          rd_bursts,
    output wire [31:0]          wr_bursts,
    output wire [1:0]           fsm_state
);
    // ---------------- request registers ----------------
    reg [`ADDR_W-1:0] req_addr;
    reg               req_we;
    reg [`DATA_W-1:0] req_wdata;

    wire [`TAG_W-1:0]   req_tag  = req_addr[`ADDR_W-1 -: `TAG_W];
    wire [`INDEX_W-1:0] req_idx  = req_addr[`OFFSET_W +: `INDEX_W];
    wire [1:0]          req_word = req_addr[3:2];

    // ---------------- datapath wires -------------------
    wire [`LINE_W-1:0] line_out;
    wire [`TAG_W-1:0]  stored_tag;
    wire               valid, dirty, hit;

    // ---------------- controller wires -----------------
    wire latch_req, done, data_we_word, refill, dirty_set;
    wire mem_rd, mem_wr, mem_done;
    wire ev_hit, ev_miss, ev_wb;

    // ---------------- sub-modules ----------------------
    cache_data_ram u_data (
        .clk(clk), .idx(req_idx),
        .we_line(refill), .line_in(mem_rdata),
        .we_word(data_we_word), .word_sel(req_word), .word_in(req_wdata),
        .line_out(line_out));

    tag_ram u_tag (
        .clk(clk), .idx(req_idx), .we(refill),
        .tag_in(req_tag), .tag_out(stored_tag));

    valid_ram u_valid (
        .clk(clk), .rst(rst), .idx(req_idx), .set(refill),
        .valid_out(valid));

    dirty_ram u_dirty (
        .clk(clk), .rst(rst), .idx(req_idx),
        .set(dirty_set), .clr(refill), .dirty_out(dirty));

    tag_comparator u_cmp (
        .req_tag(req_tag), .stored_tag(stored_tag), .valid(valid), .hit(hit));

    wb_fsm u_fsm (
        .clk(clk), .rst(rst),
        .cpu_req(cpu_req), .req_we(req_we),
        .hit(hit), .victim_valid(valid), .victim_dirty(dirty),
        .mem_ready(mem_done),
        .latch_req(latch_req), .done(done),
        .data_we_word(data_we_word), .refill(refill), .dirty_set(dirty_set),
        .mem_rd(mem_rd), .mem_wr(mem_wr),
        .ev_hit(ev_hit), .ev_miss(ev_miss), .ev_writeback(ev_wb),
        .state(fsm_state));

    mem_interface u_mif (
        .clk(clk), .rst(rst),
        .mem_rd(mem_rd), .mem_wr(mem_wr),
        .req_tag(req_tag), .req_idx(req_idx),
        .victim_tag(stored_tag), .victim_line(line_out),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_ready(mem_ready), .done(mem_done),
        .rd_bursts(rd_bursts), .wr_bursts(wr_bursts));

    // ---------------- sequential glue ------------------
    always @(posedge clk) begin
        if (rst) begin
            req_addr  <= 0;  req_we <= 0;  req_wdata <= 0;
            cpu_ready <= 0;  cpu_rdata <= 0;
            hit_cnt   <= 0;  miss_cnt <= 0; wb_cnt <= 0;
        end else begin
            if (cpu_req) begin
                req_addr  <= cpu_addr;
                req_we    <= cpu_we;
                req_wdata <= cpu_wdata;
            end
            cpu_ready <= done;
            if (done && !req_we)
                cpu_rdata <= line_out[req_word*`DATA_W +: `DATA_W];
            if (ev_hit)  hit_cnt  <= hit_cnt  + 1;
            if (ev_miss) miss_cnt <= miss_cnt + 1;
            if (ev_wb)   wb_cnt   <= wb_cnt   + 1;
        end
    end
endmodule
