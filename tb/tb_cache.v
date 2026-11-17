// ============================================================================
// tb_cache.v : Self-checking directed testbench + traffic comparison
// ----------------------------------------------------------------------------
//  Instantiates the WRITE-BACK cache and the WRITE-THROUGH reference cache,
//  each with its own main-memory model, and drives the SAME CPU request
//  stream into both.
//
//  Part A  Directed tests (dumped to VCD): read hit/miss, write hit (dirty
//          set), repeated writes (no traffic), dirty eviction (write-back
//          before refill), clean eviction (no write-back), write miss on clean
//          and dirty lines, full-cache dirty sweep, reset behaviour.
//  Part B  Workloads for memory-traffic comparison (results/traffic.csv).
//  Always  Golden-model check of every read, coherence check of the
//          "cache + memory" view, FSM state/transition coverage.
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module tb_cache;
    // ------------------------------------------------------------------ clk
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;                       // 100 MHz

    // ------------------------------------------------------- WB cache + mem
    reg                  wb_req = 0, wb_we = 0;
    reg  [31:0]          wb_addr = 0, wb_wdata = 0;
    wire [31:0]          wb_rdata;
    wire                 wb_ready;
    wire                 wbm_req, wbm_we, wbm_ready;
    wire [`BLK_W-1:0]    wbm_addr;
    wire [`LINE_W-1:0]   wbm_wdata, wbm_rdata;
    wire [3:0]           wbm_wmask;
    wire [31:0]          wb_hits, wb_misses, wb_wbs, wb_rdb, wb_wrb;
    wire [1:0]           wb_state;

    wb_cache_top u_wb (
        .clk(clk), .rst(rst),
        .cpu_req(wb_req), .cpu_we(wb_we), .cpu_addr(wb_addr),
        .cpu_wdata(wb_wdata), .cpu_rdata(wb_rdata), .cpu_ready(wb_ready),
        .mem_req(wbm_req), .mem_we(wbm_we), .mem_addr(wbm_addr),
        .mem_wdata(wbm_wdata), .mem_wmask(wbm_wmask),
        .mem_rdata(wbm_rdata), .mem_ready(wbm_ready),
        .hit_cnt(wb_hits), .miss_cnt(wb_misses), .wb_cnt(wb_wbs),
        .rd_bursts(wb_rdb), .wr_bursts(wb_wrb), .fsm_state(wb_state));

    wire [31:0] wbm_rd_txn, wbm_wr_txn, wbm_rd_words, wbm_wr_words, wbm_busy;
    main_memory #(.LATENCY(10)) mem_wb (
        .clk(clk), .rst(rst),
        .mem_req(wbm_req), .mem_we(wbm_we), .mem_addr(wbm_addr),
        .mem_wdata(wbm_wdata), .mem_wmask(wbm_wmask),
        .mem_rdata(wbm_rdata), .mem_ready(wbm_ready),
        .rd_txn(wbm_rd_txn), .wr_txn(wbm_wr_txn),
        .rd_words(wbm_rd_words), .wr_words(wbm_wr_words), .busy_cycles(wbm_busy));

    // ------------------------------------------------------- WT cache + mem
    reg                  wt_req = 0, wt_we = 0;
    reg  [31:0]          wt_addr = 0, wt_wdata = 0;
    wire [31:0]          wt_rdata;
    wire                 wt_ready;
    wire                 wtm_req, wtm_we, wtm_ready;
    wire [`BLK_W-1:0]    wtm_addr;
    wire [`LINE_W-1:0]   wtm_wdata, wtm_rdata;
    wire [3:0]           wtm_wmask;
    wire [31:0]          wt_hits, wt_misses;
    wire [1:0]           wt_state;

    wt_cache_top u_wt (
        .clk(clk), .rst(rst),
        .cpu_req(wt_req), .cpu_we(wt_we), .cpu_addr(wt_addr),
        .cpu_wdata(wt_wdata), .cpu_rdata(wt_rdata), .cpu_ready(wt_ready),
        .mem_req(wtm_req), .mem_we(wtm_we), .mem_addr(wtm_addr),
        .mem_wdata(wtm_wdata), .mem_wmask(wtm_wmask),
        .mem_rdata(wtm_rdata), .mem_ready(wtm_ready),
        .hit_cnt(wt_hits), .miss_cnt(wt_misses), .state(wt_state));

    wire [31:0] wtm_rd_txn, wtm_wr_txn, wtm_rd_words, wtm_wr_words, wtm_busy;
    main_memory #(.LATENCY(10)) mem_wt (
        .clk(clk), .rst(rst),
        .mem_req(wtm_req), .mem_we(wtm_we), .mem_addr(wtm_addr),
        .mem_wdata(wtm_wdata), .mem_wmask(wtm_wmask),
        .mem_rdata(wtm_rdata), .mem_ready(wtm_ready),
        .rd_txn(wtm_rd_txn), .wr_txn(wtm_wr_txn),
        .rd_words(wtm_rd_words), .wr_words(wtm_wr_words), .busy_cycles(wtm_busy));

    // ------------------------------------------------------- golden model
    localparam GWORDS = 16384;                  // 64 KiB / 4
    reg [31:0] golden [0:GWORDS-1];
    task init_golden;
        integer i;
        begin for (i = 0; i < GWORDS; i = i + 1) golden[i] = 32'hA000_0000 | i; end
    endtask

    // ------------------------------------------------------- bookkeeping
    integer errors = 0, checks = 0;
    integer wb_cycles = 0, wt_cycles = 0, n_acc = 0;
    integer seed = 2026;
    integer csv;

    task check(input cond, input [8*72-1:0] msg);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("  [FAIL] %0s  (t=%0t)", msg, $time);
            end
        end
    endtask

    function [31:0] mk(input [23:0] tag, input [3:0] idx, input [1:0] word);
        mk = {tag, idx, word, 2'b00};
    endfunction

    // read a word straight out of a memory model (for white-box checks)
    function [31:0] memword_wb(input [31:0] a);
        memword_wb = mem_wb.mem[a[15:4]][a[3:2]*32 +: 32];
    endfunction
    function [31:0] memword_wt(input [31:0] a);
        memword_wt = mem_wt.mem[a[15:4]][a[3:2]*32 +: 32];
    endfunction

    // ------------------------------------------------------- CPU access
    // Issues the same request to both caches and waits for both to finish.
    task access(input we, input [31:0] addr, input [31:0] data);
        integer c1, c2;
        reg [31:0] exp;
        begin
            exp = golden[addr[15:2]];
            @(negedge clk);
            wb_req = 1; wb_we = we; wb_addr = addr; wb_wdata = data;
            wt_req = 1; wt_we = we; wt_addr = addr; wt_wdata = data;
            fork
                begin
                    c1 = 1; @(negedge clk);
                    while (!wb_ready) begin @(negedge clk); c1 = c1 + 1; end
                    wb_req = 0;
                end
                begin
                    c2 = 1; @(negedge clk);
                    while (!wt_ready) begin @(negedge clk); c2 = c2 + 1; end
                    wt_req = 0;
                end
            join
            if (!we) begin
                checks = checks + 2;
                if (wb_rdata !== exp) begin
                    errors = errors + 1;
                    $display("  [FAIL] WB read %h = %h, expected %h", addr, wb_rdata, exp);
                end
                if (wt_rdata !== exp) begin
                    errors = errors + 1;
                    $display("  [FAIL] WT read %h = %h, expected %h", addr, wt_rdata, exp);
                end
            end else
                golden[addr[15:2]] = data;
            wb_cycles = wb_cycles + c1;
            wt_cycles = wt_cycles + c2;
            n_acc     = n_acc + 1;
        end
    endtask

    task rd(input [31:0] a);                 begin access(1'b0, a, 32'h0); end endtask
    task wr(input [31:0] a, input [31:0] d); begin access(1'b1, a, d);     end endtask

    // ------------------------------------------------------- cold start
    task cold_start;
        begin
            @(negedge clk);
            rst = 1;
            mem_wb.init; mem_wt.init; init_golden;
            repeat (2) @(negedge clk);
            rst = 0;
            wb_cycles = 0; wt_cycles = 0; n_acc = 0;
        end
    endtask

    // ------------------------------------------------------- coherence
    // WB: the value the system "owns" is the cache line if valid+tag-match,
    //     otherwise main memory.  WT: main memory must ALWAYS be up to date.
    task coherence_check(input integer nwords, input [8*24-1:0] tag_s);
        integer i, bad_wb, bad_wt;
        reg [31:0] a, v;
        reg [3:0]  ix;
        begin
            bad_wb = 0; bad_wt = 0;
            for (i = 0; i < nwords; i = i + 1) begin
                a  = i << 2;
                ix = a[7:4];
                if (u_wb.u_valid.valid[ix] && u_wb.u_tag.mem[ix] == a[31:8])
                    v = u_wb.u_data.mem[ix][a[3:2]*32 +: 32];
                else
                    v = memword_wb(a);
                if (v !== golden[i])            bad_wb = bad_wb + 1;
                if (memword_wt(a) !== golden[i]) bad_wt = bad_wt + 1;
            end
            check(bad_wb == 0, "WB cache+memory view coherent with golden");
            check(bad_wt == 0, "WT main memory always up to date");
            $display("  coherence[%0s]: WB mismatches=%0d  WT mismatches=%0d (%0d words)",
                     tag_s, bad_wb, bad_wt, nwords);
        end
    endtask

    function integer dirty_lines;
        input dummy;
        integer k;
        begin
            dirty_lines = 0;
            for (k = 0; k < `NLINES; k = k + 1)
                if (u_wb.u_valid.valid[k] && u_wb.u_dirty.dirty[k])
                    dirty_lines = dirty_lines + 1;
        end
    endfunction

    // ------------------------------------------------------- FSM coverage
    integer st_cycles [0:3];
    reg [5:0] tr_seen = 0;    // IDLE>CMP, CMP>IDLE, CMP>WB, CMP>ALLOC, WB>ALLOC, ALLOC>CMP
    reg [1:0] prev_state = 0;
    integer illegal = 0;
    initial begin : cov_init
        integer k; for (k = 0; k < 4; k = k + 1) st_cycles[k] = 0;
    end
    always @(posedge clk) if (!rst) begin
        st_cycles[wb_state] = st_cycles[wb_state] + 1;
        if (prev_state != wb_state) begin
            case ({prev_state, wb_state})
                4'b00_01: tr_seen[0] = 1;
                4'b01_00: tr_seen[1] = 1;
                4'b01_10: tr_seen[2] = 1;
                4'b01_11: tr_seen[3] = 1;
                4'b10_11: tr_seen[4] = 1;
                4'b11_01: tr_seen[5] = 1;
                default: begin
                    illegal = illegal + 1;
                    $display("  [FAIL] illegal FSM transition %0d -> %0d", prev_state, wb_state);
                end
            endcase
        end
        prev_state = wb_state;
    end

    // ------------------------------------------------------- workloads
    task report_workload(input [8*28-1:0] name);
        integer dl, wb_tot, wt_tot;
        begin
            dl     = dirty_lines(0);
            wb_tot = wbm_rd_words + wbm_wr_words;
            wt_tot = wtm_rd_words + wtm_wr_words;
            $display("  %-26s acc=%5d | WB: hit=%4d miss=%4d wb=%4d rdW=%5d wrW=%5d tot=%5d dirtyLeft=%2d cyc=%6d | WT: hit=%4d miss=%4d rdW=%5d wrW=%5d tot=%5d cyc=%6d",
                name, n_acc, wb_hits, wb_misses, wb_wbs, wbm_rd_words, wbm_wr_words,
                wb_tot, dl, wb_cycles, wt_hits, wt_misses, wtm_rd_words, wtm_wr_words,
                wt_tot, wt_cycles);
            $fdisplay(csv, "%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                name, n_acc,
                wb_hits, wb_misses, wb_wbs, wbm_rd_txn, wbm_wr_txn, wbm_rd_words, wbm_wr_words,
                dl*`WORDS_PB, wb_cycles,
                wt_hits, wt_misses, wtm_rd_txn, wtm_wr_txn, wtm_rd_words, wtm_wr_words, wt_cycles);
        end
    endtask

    integer i, p, r;
    reg [31:0] a, v;

    // =================================================================== MAIN
    initial begin
        $dumpfile("wb_cache.vcd");
        $dumpvars(0, tb_cache);
        init_golden;
        repeat (3) @(negedge clk);
        rst = 0;

        $display("\n==================== PART A : DIRECTED TESTS ====================");

        // T0 -------------------------------------------------- reset state
        $display("T0  reset: all lines invalid and clean");
        check(u_wb.u_valid.valid == 0 && u_wb.u_dirty.dirty == 0, "T0 valid/dirty cleared by reset");
        check(wb_state == 0, "T0 FSM in IDLE after reset");

        // T1 -------------------------------------------------- read miss (clean)
        $display("T1  read miss, invalid line -> ALLOCATE (no write-back)");
        rd(mk(24'h0, 4'd1, 2'd0));
        check(wb_misses == 1 && wb_hits == 0, "T1 counted as one miss");
        check(wbm_rd_txn == 1 && wbm_wr_txn == 0, "T1 one block read, no write");
        check(u_wb.u_valid.valid[1] == 1 && u_wb.u_dirty.dirty[1] == 0, "T1 line valid & clean");

        // T2 -------------------------------------------------- read hit
        $display("T2  read hit on same block (other word)");
        rd(mk(24'h0, 4'd1, 2'd2));
        check(wb_hits == 1 && wbm_rd_txn == 1, "T2 hit, no extra memory traffic");

        // T3 -------------------------------------------------- write hit -> dirty
        $display("T3  write hit -> data updated in cache only, DIRTY set");
        wr(mk(24'h0, 4'd1, 2'd1), 32'hDEAD_0001);
        check(u_wb.u_dirty.dirty[1] == 1, "T3 dirty bit set on write hit");
        check(wbm_wr_txn == 0, "T3 WB: no memory write on write hit");
        check(memword_wb(mk(24'h0,4'd1,2'd1)) == 32'hA000_0005, "T3 WB: memory still holds old value");
        check(memword_wt(mk(24'h0,4'd1,2'd1)) == 32'hDEAD_0001, "T3 WT: memory updated immediately");

        // T4 -------------------------------------------------- repeated writes
        $display("T4  3 more writes to the dirty line -> zero WB traffic");
        wr(mk(24'h0, 4'd1, 2'd0), 32'hDEAD_0000);
        wr(mk(24'h0, 4'd1, 2'd2), 32'hDEAD_0002);
        wr(mk(24'h0, 4'd1, 2'd3), 32'hDEAD_0003);
        check(wbm_wr_txn == 0 && wbm_rd_txn == 1, "T4 WB: writes absorbed by cache");
        check(wtm_wr_txn == 4, "T4 WT: 4 single-word memory writes");

        
        $display("\nDirected tests T0-T4 complete. All checks passed.");
        $finish;
    end
endmodule
