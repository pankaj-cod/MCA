# Prototype Demo Video – Script (≤ 5 minutes)

Target length about 4:30. Record with screen sharing (VS Code + terminal +
`docs/figures`). Each member speaks in their own segment.

| Time | Speaker | Show on screen | Say (key points) |
|---|---|---|---|
| 0:00–0:35 | Pankaj Upadhyay | Title slide / README | "We are Group **Khel Khatam**: **Pankaj Upadhyay, Prakhar Rawat, Harshit Kudhial, Om Chimurkar and Vishuti Jamwal**. Our project is Project 8, a **Write-Back Cache Controller** in Verilog. The goal is to reduce main-memory traffic with dirty bits, writing a block back only when it is evicted." |
| 0:35–1:15 | Pankaj Upadhyay | `docs/figures/fig_block.png`, then `rtl/cache_data_ram.v`, `dirty_ram.v` | Direct-mapped, 16 lines × 16 B. Address split tag/index/word. Separate Data, Tag, Valid and **Dirty** RAMs plus the comparator. Dirty is *set* on a write hit and *cleared* on refill. |
| 1:15–2:05 | Prakhar Rawat | `docs/figures/fig_fsm.png`, then `rtl/wb_fsm.v` | Four states. COMPARE handles hits. On a miss with a dirty victim, go to WRITE_BACK first, then ALLOCATE, then re-COMPARE. Explain why the old block must reach memory **before** the refill overwrites it. |
| 2:05–2:40 | Harshit Kudhial | `rtl/mem_interface.v`, `rtl/wt_cache_top.v` | Victim address = {stored tag, index}. Memory model has 10-cycle latency and counts words moved. The write-through cache is our baseline. |
| 2:40–3:35 | Om Chimurkar | Terminal: `./sim/run.sh`, then `fig_wave_evict.png` (or GTKWave) | Run the simulation live and show the T0–T11 test list and **6494 checks, 0 errors**, with all FSM transitions covered. On the waveform, point to dirty=1, WRITE_BACK with mem_we=1 at address 0x010, ALLOCATE at 0x110, dirty cleared, correct data returned. |
| 3:35–4:30 | Vishuti Jamwal | `fig_traffic.png`, table in README | W1/W4: write-back uses 78–88 % less traffic and runs ~3.7× faster. W5/W6: write-allocate and conflicts hurt write-back. This leads to the Phase II plan: write-validate, a write-back buffer and 2-way associativity. Show the GitHub repo and the report. |
| 4:30–4:45 | All | README | Thank you. |

Tips: export at 1080p and keep it under 5:00. Upload it to YouTube (unlisted) or
Google Drive (anyone with the link), then paste the link into `README.md`.
