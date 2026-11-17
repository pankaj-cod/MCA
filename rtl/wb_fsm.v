`timescale 1ns/1ps
// ============================================================================
// wb_fsm.v : Write-Back Cache Controller FSM
// ----------------------------------------------------------------------------
//  States: IDLE, COMPARE, WRITE_BACK, ALLOCATE
// ============================================================================
module wb_fsm (
    input  wire       clk,
    input  wire       rst,
    // CPU side
    input  wire       cpu_req,
    input  wire       req_we,        // latched R/W of current request
    // datapath status
    input  wire       hit,
    input  wire       victim_valid,
    input  wire       victim_dirty,
    // memory interface status
    input  wire       mem_ready,
    // datapath controls
    output reg        latch_req,     // capture CPU request registers
    output reg        done,          // request complete this cycle
    output reg        data_we_word,  // CPU store into data RAM
    output reg        refill,        // write line/tag, set valid, clr dirty
    output reg        dirty_set,
    output reg        mem_rd,        // memory interface: read block
    output reg        mem_wr,        // memory interface: write victim block
    // event strobes (for performance counters)
    output reg        ev_hit,
    output reg        ev_miss,
    output reg        ev_writeback,
    output reg [1:0]  state
);
    localparam IDLE       = 2'd0,
               COMPARE    = 2'd1,
               WRITE_BACK = 2'd2,
               ALLOCATE   = 2'd3;

    reg [1:0] next_state;
    reg       first_cmp;

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            first_cmp <= 1'b0;
        end else begin
            state <= next_state;
            if (state == IDLE && cpu_req)          first_cmp <= 1'b1;
            else if (state == COMPARE)             first_cmp <= 1'b0;
        end
    end

    always @(*) begin
        next_state   = state;
        latch_req    = 1'b0;
        done         = 1'b0;
        data_we_word = 1'b0;
        refill       = 1'b0;
        dirty_set    = 1'b0;
        mem_rd       = 1'b0;
        mem_wr       = 1'b0;
        ev_hit       = 1'b0;
        ev_miss      = 1'b0;
        ev_writeback = 1'b0;

        case (state)
        IDLE: begin
            if (cpu_req) begin
                latch_req  = 1'b1;
                next_state = COMPARE;
            end
        end

        COMPARE: begin
            if (hit) begin
                ev_hit = first_cmp;
                done   = 1'b1;
                if (req_we) begin
                    data_we_word = 1'b1;
                    dirty_set    = 1'b1;     // block now differs from memory
                end
                next_state = IDLE;
            end else begin
                ev_miss = first_cmp;
                if (victim_valid && victim_dirty) begin
                    ev_writeback = 1'b1;
                    next_state   = WRITE_BACK;
                end else begin
                    next_state   = ALLOCATE;
                end
            end
        end

        WRITE_BACK: begin
            mem_wr = 1'b1;                   // old block -> memory first
            if (mem_ready) next_state = ALLOCATE;
        end

        ALLOCATE: begin
            mem_rd = 1'b1;                   // then fetch the new block
            if (mem_ready) begin
                refill     = 1'b1;
                next_state = COMPARE;
            end
        end
        endcase
    end
endmodule
