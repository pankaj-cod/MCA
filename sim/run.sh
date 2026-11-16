#!/usr/bin/env bash
# Compile and run the write-back cache testbench with Icarus Verilog.
# Outputs (in sim/): sim.log, wb_cache.vcd (open with GTKWave), traffic.csv
set -euo pipefail
cd "$(dirname "$0")"
iverilog -g2012 -Wall -I ../rtl -o tb_cache.vvp \
    ../rtl/cache_data_ram.v ../rtl/tag_ram.v ../rtl/valid_ram.v \
    ../rtl/dirty_ram.v ../rtl/tag_comparator.v ../rtl/wb_fsm.v \
    ../rtl/mem_interface.v ../rtl/wb_cache_top.v ../rtl/wt_cache_top.v \
    ../rtl/main_memory.v ../tb/tb_cache.v
vvp -n tb_cache.vvp | tee sim.log
