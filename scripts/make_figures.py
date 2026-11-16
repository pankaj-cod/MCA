#!/usr/bin/env python3
"""Generate report figures (pure Python, no third-party packages).

  docs/figures/fig_wave_writehit.svg  - waveform: write hits set the dirty bit
  docs/figures/fig_wave_evict.svg     - waveform: dirty eviction (WB -> ALLOC)
  docs/figures/fig_traffic.svg        - memory traffic WB vs WT per workload
  docs/figures/fig_cycles.svg         - execution cycles WB vs WT per workload
  docs/tables/traffic_table.md        - summary table

Usage:  python3 scripts/make_figures.py   (after sim/run.sh)
"""
import csv, os, re, html

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM = os.path.join(ROOT, "sim")
FIG = os.path.join(ROOT, "docs", "figures")
os.makedirs(FIG, exist_ok=True)
os.makedirs(os.path.join(ROOT, "docs", "tables"), exist_ok=True)

FONT = "font-family='Helvetica, Arial, sans-serif'"
INK, MUTED, GRID = "#1f2937", "#6b7280", "#e5e7eb"
C_WB, C_WB_L, C_WT = "#1d4ed8", "#93c5fd", "#ea580c"

# --------------------------------------------------------------------- VCD
def parse_vcd(path, wanted):
    """wanted: dict short_name -> full hierarchical name. Returns name->[(t,v)]."""
    ids, scope = {}, []
    changes = {}
    with open(path) as f:
        it = iter(f)
        for line in it:
            tok = line.split()
            if not tok:
                continue
            if tok[0] == "$scope":
                scope.append(tok[2])
            elif tok[0] == "$upscope":
                scope.pop()
            elif tok[0] == "$var":
                full = ".".join(scope + [tok[4]])
                ids.setdefault(tok[3], []).append(full)
            elif tok[0] == "$enddefinitions":
                break
        rev = {}
        for short, full in wanted.items():
            for i, names in ids.items():
                if full in names:
                    rev.setdefault(i, []).append(short)
            changes[short] = []
        t = 0
        for line in it:
            line = line.strip()
            if not line or line.startswith("$"):
                continue
            if line[0] == "#":
                t = int(line[1:])
            elif line[0] in "bB":
                v, i = line[1:].split()
                for s in rev.get(i, []):
                    changes[s].append((t, v))
            elif line[0] in "01xzXZ":
                for s in rev.get(line[1:], []):
                    changes[s].append((t, line[0]))
    return changes

def value_at(ch, t):
    v = "x"
    for tt, vv in ch:
        if tt > t:
            break
        v = vv
    return v

def to_int(v):
    try:
        return int(v, 2)
    except ValueError:
        return None

STATE_NAMES = {0: "IDLE", 1: "COMPARE", 2: "WRITE_BACK", 3: "ALLOCATE"}

def waveform_svg(ch, t0, t1, rows, title, out, period=10000, markers=()):
    """rows: list of (label, key, kind) kind in {'bit','hex','state','blk'}"""
    lw, rh, top = 118, 26, 34
    ncyc = (t1 - t0) // period
    pw = 16
    W = lw + ncyc * pw + 12
    H = top + rh * len(rows) + 22
    x = lambda t: lw + (t - t0) / period * pw
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {W} {H}' width='{W}' height='{H}' {FONT}>",
         f"<rect width='{W}' height='{H}' fill='white'/>",
         f"<text x='8' y='18' font-size='12' font-weight='bold' fill='{INK}'>{html.escape(title)}</text>"]
    # cycle grid
    for c in range(ncyc + 1):
        xx = lw + c * pw
        s.append(f"<line x1='{xx}' y1='{top-6}' x2='{xx}' y2='{H-18}' stroke='{GRID}' stroke-width='0.6'/>")
        if c % 5 == 0:
            s.append(f"<text x='{xx}' y='{H-6}' font-size='8' fill='{MUTED}' text-anchor='middle'>{c}</text>")
    for (mt, mlabel) in markers:
        xx = x(mt)
        s.append(f"<line x1='{xx}' y1='{top-8}' x2='{xx}' y2='{H-18}' stroke='#dc2626' stroke-width='0.8' stroke-dasharray='3,2'/>")
        s.append(f"<text x='{xx+2}' y='{top-10}' font-size='8' fill='#dc2626'>{html.escape(mlabel)}</text>")
    for r, (label, key, kind) in enumerate(rows):
        y0 = top + r * rh
        yh, yl, ym = y0 + 4, y0 + rh - 6, y0 + rh / 2 - 1
        s.append(f"<text x='8' y='{ym+4}' font-size='10' fill='{INK}'>{html.escape(label)}</text>")
        c = ch[key]
        # build segments
        segs, cur_t, cur_v = [], t0, value_at(c, t0)
        for tt, vv in c:
            if t0 < tt < t1:
                segs.append((cur_t, tt, cur_v)); cur_t, cur_v = tt, vv
        segs.append((cur_t, t1, cur_v))
        if kind == "clk":
            pts = []
            for a, b, v in segs:
                yy = yh if v == "1" else yl
                pts += [f"{x(a):.1f},{yy}", f"{x(b):.1f},{yy}"]
            s.append(f"<polyline points='{' '.join(pts)}' fill='none' stroke='{MUTED}' stroke-width='0.8'/>")
        elif kind == "bit":
            pts = []
            for a, b, v in segs:
                yy = yh if v == "1" else yl
                pts += [f"{x(a):.1f},{yy}", f"{x(b):.1f},{yy}"]
                if v == "1":
                    s.append(f"<rect x='{x(a):.1f}' y='{yh}' width='{x(b)-x(a):.1f}' height='{yl-yh}' fill='{C_WB}' opacity='0.12'/>")
            s.append(f"<polyline points='{' '.join(pts)}' fill='none' stroke='{C_WB}' stroke-width='1.3'/>")
        else:
            for a, b, v in segs:
                xa, xb = x(a), x(b)
                d = 2.5
                n = to_int(v)
                if kind == "state":
                    txt = STATE_NAMES.get(n, v)
                    fill = {0: "#f3f4f6", 1: "#dbeafe", 2: "#fee2e2", 3: "#dcfce7"}.get(n, "white")
                elif kind == "blk":
                    txt = "-" if n is None else f"{n << 4:04X}"
                    fill = "white"
                else:
                    txt = "x" if n is None else f"{n:08X}"
                    fill = "white"
                s.append(f"<polygon points='{xa+d:.1f},{yh} {xb-d:.1f},{yh} {xb:.1f},{ym} {xb-d:.1f},{yl} {xa+d:.1f},{yl} {xa:.1f},{ym}' "
                         f"fill='{fill}' stroke='{INK}' stroke-width='0.8'/>")
                maxch = int((xb - xa - 4) / 5.2)
                if maxch >= 2:
                    t_ = txt if len(txt) <= maxch else txt[:max(1, maxch - 1)] + "…"
                    s.append(f"<text x='{(xa+xb)/2:.1f}' y='{ym+3.5}' font-size='8.5' text-anchor='middle' fill='{INK}'>{html.escape(t_)}</text>")
    s.append(f"<text x='{lw-10}' y='{H-6}' font-size='8' fill='{MUTED}' text-anchor='end'>cycle</text>")
    s.append("</svg>")
    open(out, "w").write("\n".join(s))

def first_time(ch, key, val, after=0):
    for t, v in ch[key]:
        if t >= after and to_int(v) == val:
            return t
    return None

def make_waves():
    T = "tb_cache"
    wanted = {
        "clk": f"{T}.clk", "req": f"{T}.wb_req", "we": f"{T}.wb_we",
        "addr": f"{T}.wb_addr", "wdata": f"{T}.wb_wdata", "rdata": f"{T}.wb_rdata",
        "ready": f"{T}.wb_ready", "state": f"{T}.u_wb.fsm_state",
        "hit": f"{T}.u_wb.hit", "dirty": f"{T}.u_wb.dirty",
        "mreq": f"{T}.wbm_req", "mwe": f"{T}.wbm_we", "maddr": f"{T}.wbm_addr",
        "mready": f"{T}.wbm_ready", "dirtyvec": f"{T}.u_wb.u_dirty.dirty",
    }
    ch = parse_vcd(os.path.join(SIM, "wb_cache.vcd"), wanted)
    P = 10000  # ps per cycle
    rows_common = [
        ("clk", "clk", "clk"), ("cpu_req", "req", "bit"), ("cpu_we", "we", "bit"),
        ("cpu_addr", "addr", "hex"), ("FSM state", "state", "state"),
        ("hit", "hit", "bit"), ("dirty[idx]", "dirty", "bit"),
    ]
    # --- Fig: write hits (T3) : first write while dirty vec == 0 after reads
    t_wr = None
    for t, v in ch["we"]:
        if v == "1":
            t_wr = t; break
    t0 = (t_wr // P) * P - 3 * P + 5000 - 5000
    t1 = t0 + 34 * P
    waveform_svg(ch, t0, t1,
                 rows_common[:4] + [("cpu_wdata", "wdata", "hex")] + rows_common[4:] +
                 [("cpu_ready", "ready", "bit"), ("mem_req", "mreq", "bit")],
                 "Write hits: data written in cache, dirty bit set, no memory transaction",
                 os.path.join(FIG, "fig_wave_writehit.svg"))
    # --- Fig: dirty eviction (T5) : first WRITE_BACK state
    t_wb = first_time(ch, "state", 2)
    t0 = (t_wb // P) * P - 4 * P
    t1 = t0 + 34 * P
    t_alloc = first_time(ch, "state", 3, t_wb)
    t_cmp = first_time(ch, "state", 1, t_alloc)
    waveform_svg(ch, t0, t1,
                 rows_common + [("mem_req", "mreq", "bit"), ("mem_we", "mwe", "bit"),
                                ("mem_addr", "maddr", "blk"), ("mem_ready", "mready", "bit"),
                                ("cpu_rdata", "rdata", "hex"), ("cpu_ready", "ready", "bit")],
                 "Dirty eviction: read 0x110 misses on dirty line 1 -> write back 0x010, then refill",
                 os.path.join(FIG, "fig_wave_evict.svg"),
                 markers=[(t_wb, "write-back"), (t_alloc, "allocate"), (t_cmp, "re-compare")])

# --------------------------------------------------------------------- charts
def nice_max(v):
    for m in [100, 200, 250, 500, 1000, 2000, 2500, 4000, 5000, 6000, 8000, 10000, 20000, 25000, 50000]:
        if v <= m:
            return m
    return v

def grouped_bars(rows, title, ylabel, series, out, stack=None):
    """series: list of (label, key, color); stack: (base_key, extra_key, color, label) for WB."""
    W, H = 640, 300
    ml, mr, mt, mb = 52, 12, 46, 64
    pw, ph = W - ml - mr, H - mt - mb
    vals = []
    for r in rows:
        for _, k, _ in series:
            vals.append(r[k] + (r[stack[1]] if stack and k == stack[0] else 0))
    ymax = nice_max(max(vals) * 1.08)
    y = lambda v: mt + ph - v / ymax * ph
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {W} {H}' width='{W}' height='{H}' {FONT}>",
         f"<rect width='{W}' height='{H}' fill='white'/>",
         f"<text x='{ml}' y='18' font-size='13' font-weight='bold' fill='{INK}'>{html.escape(title)}</text>"]
    for k in range(6):
        v = ymax * k / 5
        s.append(f"<line x1='{ml}' x2='{W-mr}' y1='{y(v):.1f}' y2='{y(v):.1f}' stroke='{GRID}'/>")
        s.append(f"<text x='{ml-5}' y='{y(v)+3:.1f}' font-size='9' text-anchor='end' fill='{MUTED}'>{int(v)}</text>")
    s.append(f"<text transform='translate(13,{mt+ph/2}) rotate(-90)' font-size='10' text-anchor='middle' fill='{MUTED}'>{html.escape(ylabel)}</text>")
    gw = pw / len(rows)
    bw = min(26, gw * 0.8 / len(series))
    for i, r in enumerate(rows):
        gx = ml + i * gw + (gw - bw * len(series) - 2) / 2
        for j, (lab, k, col) in enumerate(series):
            bx = gx + j * (bw + 2)
            v = r[k]
            s.append(f"<rect x='{bx:.1f}' y='{y(v):.1f}' width='{bw:.1f}' height='{y(0)-y(v):.1f}' fill='{col}' rx='1'/>")
            top = v
            if stack and k == stack[0] and r[stack[1]] > 0:
                e = r[stack[1]]
                s.append(f"<rect x='{bx:.1f}' y='{y(v+e):.1f}' width='{bw:.1f}' height='{y(v)-y(v+e):.1f}' fill='{stack[2]}' rx='1'/>")
                top = v + e
            s.append(f"<text x='{bx+bw/2:.1f}' y='{y(top)-3:.1f}' font-size='8' text-anchor='middle' fill='{INK}'>{top}</text>")
        name = r["workload"].split(" ", 1)
        s.append(f"<text x='{ml+i*gw+gw/2:.1f}' y='{H-mb+14}' font-size='9.5' font-weight='bold' text-anchor='middle' fill='{INK}'>{name[0]}</text>")
        words = name[1].split()
        line1 = " ".join(words[:2]); line2 = " ".join(words[2:])
        s.append(f"<text x='{ml+i*gw+gw/2:.1f}' y='{H-mb+26}' font-size='8' text-anchor='middle' fill='{MUTED}'>{html.escape(line1)}</text>")
        s.append(f"<text x='{ml+i*gw+gw/2:.1f}' y='{H-mb+36}' font-size='8' text-anchor='middle' fill='{MUTED}'>{html.escape(line2)}</text>")
    s.append(f"<line x1='{ml}' x2='{W-mr}' y1='{y(0)}' y2='{y(0)}' stroke='{INK}'/>")
    # legend
    lx = ml
    leg = [(l, c) for l, _, c in series]
    if stack:
        leg.insert(1, (stack[3], stack[2]))
    for l, c in leg:
        s.append(f"<rect x='{lx}' y='28' width='10' height='10' fill='{c}' rx='1'/>")
        s.append(f"<text x='{lx+14}' y='37' font-size='10' fill='{INK}'>{html.escape(l)}</text>")
        lx += 14 + 5.6 * len(l) + 16
    s.append("</svg>")
    open(out, "w").write("\n".join(s))

def make_charts():
    rows = []
    with open(os.path.join(SIM, "traffic.csv")) as f:
        for r in csv.DictReader(f):
            for k in r:
                if k != "workload":
                    r[k] = int(r[k])
            r["wb_total"] = r["wb_rd_words"] + r["wb_wr_words"]
            r["wt_total"] = r["wt_rd_words"] + r["wt_wr_words"]
            rows.append(r)
    grouped_bars(rows, "Main-memory traffic (32-bit words transferred)", "words",
                 [("Write-back (during run)", "wb_total", C_WB),
                  ("Write-through", "wt_total", C_WT)],
                 os.path.join(FIG, "fig_traffic.svg"),
                 stack=("wb_total", "wb_flush_words", C_WB_L, "WB final flush of dirty lines"))
    grouped_bars(rows, "Execution time (CPU cycles, 10-cycle memory latency)", "cycles",
                 [("Write-back", "wb_cycles", C_WB), ("Write-through", "wt_cycles", C_WT)],
                 os.path.join(FIG, "fig_cycles.svg"))
    # markdown table
    lines = ["| Workload | Acc. | WB hit % | WB write-backs | WB words (+flush) | WT words | Traffic WB/WT | WB cycles | WT cycles |",
             "|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        wbt = r["wb_total"] + r["wb_flush_words"]
        lines.append(f"| {r['workload']} | {r['accesses']} | {100*r['wb_hits']/r['accesses']:.1f} | {r['wb_writebacks']} | "
                     f"{r['wb_total']} (+{r['wb_flush_words']}) | {r['wt_total']} | {wbt/r['wt_total']:.2f} | {r['wb_cycles']} | {r['wt_cycles']} |")
    open(os.path.join(ROOT, "docs", "tables", "traffic_table.md"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))

if __name__ == "__main__":
    make_waves()
    make_charts()
    print("figures written to", FIG)
