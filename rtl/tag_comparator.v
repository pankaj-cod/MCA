// ============================================================================
// tag_comparator.v : hit = valid AND (stored tag == requested tag)
// ============================================================================
`timescale 1ns/1ps
`include "cache_params.vh"

module tag_comparator (
    input  wire [`TAG_W-1:0] req_tag,
    input  wire [`TAG_W-1:0] stored_tag,
    input  wire              valid,
    output wire              hit
);
    assign hit = valid & (req_tag == stored_tag);
endmodule
