// ============================================================================
// cache_params.vh : shared geometry for the write-back / write-through caches
// ----------------------------------------------------------------------------
//  32-bit byte address, 32-bit words, 4 words (16 B) per block,
//  16 lines, direct-mapped  ->  256 B of cache data
//
//   31                         8 7        4 3     2 1    0
//  +----------------------------+----------+-------+------+
//  |        TAG (24 bits)       | INDEX(4) | WORD  | BYTE |
//  +----------------------------+----------+-------+------+
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
`define TAG_W       (`ADDR_W-`INDEX_W-`OFFSET_W)  // 24
`define BLK_W       (`ADDR_W-`OFFSET_W)           // block address width (28)

`endif
