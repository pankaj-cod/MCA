# Write-Back Cache Controller (Verilog HDL)

**Modern Computer Architecture – Project 8 (Advanced Intermediate)**
Phase I submission · **Group: Khel Khatam**

A direct-mapped **write-back, write-allocate** cache controller with dirty-bit
management. On a miss, a dirty victim is written back to memory before the new
block is refilled. The design is verified with a self-checking directed testbench
and compared against a write-through, no-write-allocate reference cache.

## Team

| Member | Roll No. | Contribution |
|---|---|---|
| Pankaj Upadhyay | 2401010317 | Data RAM, Tag RAM, Valid RAM, Dirty-Bit RAM, Tag Comparator, `cache_params.vh` |
| Prakhar Rawat | 2401020045 | Write-back FSM (`wb_fsm.v`), state diagram, top-level integration |
| Harshit Kudhial | 2401010182 | Memory interface, main-memory model + traffic counters, write-through cache |
| Om Chimurkar | 2401010306 | Testbench, golden model, directed tests, coherence + FSM coverage, waveforms |
| Vishuti Jamwal | 2401010506 | Workloads, traffic analysis, figure scripts, literature review, report, video |

## Architecture

* 32-bit byte address, 16 lines × 16 B (4 words), direct-mapped (256 B of data)
* Address split: `tag[31:8] | index[7:4] | word[3:2] | byte[1:0]`
* Main memory: 128-bit block transfers, 10-cycle latency, `req/ready` handshake

### Controller FSM

| State | Action |
|---|---|
| `IDLE` | Wait for `cpu_req`, latch the request |
| `COMPARE` | Hit: read word, or write word and **set dirty**, then return to IDLE. Miss: go to `WRITE_BACK` if the victim is valid and dirty, else go to `ALLOCATE` |
| `WRITE_BACK` | Write the **old** block `{victim_tag, index}` to memory and wait for `mem_ready` |
| `ALLOCATE` | Read the new block. On `mem_ready`, write line and tag, **set valid, clear dirty**, then return to COMPARE |

## Repository layout

```
rtl/
  cache_params.vh     geometry (`define)
  cache_data_ram.v    Cache Data RAM
  tag_ram.v           Tag RAM
  valid_ram.v         Valid RAM
  dirty_ram.v         Dirty-Bit RAM
  tag_comparator.v    Tag Comparator
  wb_fsm.v            Write-Back controller FSM
  mem_interface.v     Memory Interface (address mux, burst counters)
  wb_cache_top.v      Write-back cache top level
  wt_cache_top.v      Write-through reference cache (for comparison)
  main_memory.v       Behavioural memory model with traffic counters
tb/tb_cache.v         Self-checking directed testbench + workloads
sim/run.sh            Compile + run (Icarus Verilog)
scripts/              Figure generation
report/               IEEE report (.tex)
```
