// ============================================================================
// cache_params.vh : shared geometry for the write-back / write-through caches
// ----------------------------------------------------------------------------
//  32-bit byte address, 32-bit words, 4 words (16 B) per block,
//  16 lines, direct-mapped -> 256 B of cache data
// ============================================================================
`ifndef CACHE_PARAMS_VH
`define CACHE_PARAMS_VH

`define ADDR_W      32
`define DATA_W      32
`define WORDS_PB    4                       // words per block
`define LINE_W      (`DATA_W*`WORDS_PB)     // 128-bit cache line
`define OFFSET_W    4                       // log2(16 bytes)
`define INDEX_W     4                       // 16 lines
`define NLINES      (1<<`INDEX_W)
`define TAG_W       (32-4-4)               // 24 bits
`define BLK_W       (32-4)                 // block address width (28)

`endif
