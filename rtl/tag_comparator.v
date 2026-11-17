`timescale 1ns/1ps
`include "cache_params.vh"

module tag_comparator (
    input  wire [`TAG_W-1:0] req_tag,
    input  wire [`TAG_W-1:0] stored_tag,
    input  wire              valid,
    output wire              hit
);
    // Basic tag equality check
    assign hit = (req_tag == stored_tag) && valid;
endmodule
