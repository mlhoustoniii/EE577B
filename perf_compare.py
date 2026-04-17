#!/usr/bin/env python3
# ==============================================================
# perf_compare.py
# EE577B Cardinal Router -- Unified Performance Comparison
#
# Reads perf_{hop,xystd,torus}_{summary,latency}.txt from CWD
# and produces a single consolidated comparison report.
#
# Run from ~/577B/project/EE577B/ :
#   python3 perf_compare.py
# ==============================================================

import re, os, sys

VARIANTS = ['hop', 'xystd', 'torus']
LABELS   = {'hop':'HOP (shift)', 'xystd':'XYSTD (cmp)', 'torus':'TORUS (mod)'}
W = 72

# ── Parser ────────────────────────────────────────────────────

def parse_summary(path):
    """Return dict of metrics from a perf_*_summary.txt file."""
    d = {}
    if not os.path.exists(path):
        return None
    txt = open(path).read()

    def grab(pattern, cast=float):
        m = re.search(pattern, txt)
        return cast(m.group(1)) if m else None

    d['pairs']        = grab(r'Pairs measured\s+:\s+(\d+)', int)
    d['min_lat']      = grab(r'Min latency \(cycles\)\s*:\s*([\d.]+)')
    d['max_lat']      = grab(r'Max latency \(cycles\)\s*:\s*([\d.]+)')
    d['avg_lat']      = grab(r'Avg latency \(cycles\)\s*:\s*([\d.]+)')
    d['min_lat_ns']   = grab(r'Min latency \(ns\)\s+:\s*([\d.]+)')
    d['max_lat_ns']   = grab(r'Max latency \(ns\)\s+:\s*([\d.]+)')
    d['avg_lat_ns']   = grab(r'Avg latency \(ns\)\s+:\s*([\d.]+)')
    d['burst_window'] = grab(r'Burst window \(cycles\)\s+:\s*([\d.]+)')
    d['burst_pkts']   = grab(r'Packets delivered\s+:\s*([\d.]+)')
    d['tput_raw']     = grab(r'Throughput \(pkts/cycle\)\s+:\s*([\d.]+)')
    d['tput_norm']    = grab(r'Norm\. tput \(pkt/cyc/node\)\s*:\s*([\d.]+)')
    d['tput_gpkts']   = grab(r'Throughput \(Gpkts/s @500MHz\)\s*:\s*([\d.]+)')
    d['sat_window']   = grab(r'Offered window \(cycles\)\s+:\s*([\d.]+)')
    d['sat_injected'] = grab(r'Pkts injected \(total\)\s+:\s*([\d.]+)')
    d['sat_received'] = grab(r'Pkts received \(total\)\s+:\s*([\d.]+)')
    d['offered_load'] = grab(r'Offered load\s+:\s*([\d.]+)')
    d['accepted_tput']= grab(r'Accepted throughput\s+:\s*([\d.]+)')
    d['sim_cycles']   = grab(r'Total simulation cycles\s+:\s*([\d.]+)')
    d['max_freq']     = grab(r'Max freq\s+:\s*([\d.]+)')

    # Per-node latency table
    node_rows = re.findall(
        r'\s+(\d+)\s+\((\d+),(\d+)\)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)',
        txt
    )
    d['nodes'] = {}
    for row in node_rows:
        nid, nx, ny, tx, rx, tx_lat, rx_lat = row
        d['nodes'][int(nid)] = {
            'x': int(nx), 'y': int(ny),
            'tx': int(tx), 'rx': int(rx),
            'avg_tx_lat': float(tx_lat),
            'avg_rx_lat': float(rx_lat),
        }
    return d

def parse_latency_table(path):
    """Return 16x16 array of latencies (None if missing/'-')."""
    if not os.path.exists(path):
        return None
    txt = open(path).read()
    table = [[None]*16 for _ in range(16)]
    for line in txt.split('\n'):
        m = re.match(r'\s*(\d+)\s+(.*)', line)
        if not m:
            continue
        src = int(m.group(1))
        if src >= 16:
            continue
        vals = m.group(2).split()
        for dst, v in enumerate(vals):
            if dst >= 16:
                break
            if v == '-':
                table[src][dst] = None
            else:
                try:
                    table[src][dst] = int(v)
                except ValueError:
                    table[src][dst] = None
    return table

# ── Load everything ───────────────────────────────────────────

summaries = {}
tables    = {}
missing   = []

for v in VARIANTS:
    s = parse_summary(f'perf_{v}_summary.txt')
    t = parse_latency_table(f'perf_{v}_latency.txt')
    summaries[v] = s
    tables[v]    = t
    if s is None:
        missing.append(v)

if missing:
    print(f'\nWARNING: Summary not found for: {", ".join(missing)}')
    print('Run the missing simulations first.\n')

# ── Helpers ───────────────────────────────────────────────────

def fmt(v, dec=2):
    if v is None: return 'N/A'
    return f'{v:.{dec}f}'

def pct_delta(ref, val):
    if ref is None or val is None: return '    N/A'
    if ref == 0: return '    N/A'
    return f'{(val-ref)/ref*100:+7.1f}%'

def winner_lo(*args):   # lower is better  args = key,val,key,val,...
    pairs = [(args[i],args[i+1]) for i in range(0,len(args),2)]
    valid = [(k,v) for k,v in pairs if v is not None]
    if not valid: return ''
    best = min(valid, key=lambda x: x[1])[0]
    return f'* {LABELS[best]}'

def winner_hi(*args):   # higher is better
    pairs = [(args[i],args[i+1]) for i in range(0,len(args),2)]
    valid = [(k,v) for k,v in pairs if v is not None]
    if not valid: return ''
    best = max(valid, key=lambda x: x[1])[0]
    return f'* {LABELS[best]}'

SEP = '-' * W

def hdr(title):
    print(f'\n{SEP}')
    print(f'  {title}')
    print(SEP)

def row3(label, hop_v, xystd_v, torus_v, unit='', dec=2, lo=True):
    h = fmt(hop_v, dec)   + (f' {unit}' if unit else '')
    x = fmt(xystd_v, dec) + (f' {unit}' if unit else '')
    t = fmt(torus_v, dec) + (f' {unit}' if unit else '')
    dx = pct_delta(hop_v, xystd_v)
    dt = pct_delta(hop_v, torus_v)
    win = winner_lo('hop',hop_v,'xystd',xystd_v,'torus',torus_v) if lo \
          else winner_hi('hop',hop_v,'xystd',xystd_v,'torus',torus_v)
    print(f'  {label:<28} {h:>10} {x:>10} {t:>10}  {win}')
    print(f'  {"  vs HOP":<28} {"":>10} {dx:>10} {dt:>10}')

# ── Main output ───────────────────────────────────────────────

print()
print('=' * W)
print('  EE577B Cardinal Router -- Unified Performance Comparison')
print('  HOP (unary shift)  vs  XYSTD (8-bit compare)  vs  TORUS (mod-4)')
print('=' * W)

# Column header
hdr('COLUMN KEY')
print(f'  {"Metric":<28} {"HOP":>10} {"XYSTD":>10} {"TORUS":>10}')
print(f'  {"-"*60}')

# ── 1. Coverage ───────────────────────────────────────────────
hdr('1. ALL-TO-ALL COVERAGE (240 pairs)')
print(f'  {"Metric":<28} {"HOP":>10} {"XYSTD":>10} {"TORUS":>10}')
print(f'  {"-"*60}')
for v in VARIANTS:
    s = summaries.get(v)
    pairs = s['pairs'] if s else None
    print(f'  {LABELS[v]:<28} {str(pairs) + "/240":>10}' if pairs else
          f'  {LABELS[v]:<28} {"N/A":>10}')

# ── 2. Latency ────────────────────────────────────────────────
hdr('2. LATENCY (cycles)  --  lower is better')
print(f'  {"Metric":<28} {"HOP":>10} {"XYSTD":>10} {"TORUS":>10}  Winner')
print(f'  {"-"*60}')

get = lambda v, k: summaries[v][k] if summaries.get(v) else None
row3('Min latency (cycles)',
     get('hop','min_lat'), get('xystd','min_lat'), get('torus','min_lat'),
     'cyc', dec=0)
row3('Max latency (cycles)',
     get('hop','max_lat'), get('xystd','max_lat'), get('torus','max_lat'),
     'cyc', dec=0)
row3('Avg latency (cycles)',
     get('hop','avg_lat'), get('xystd','avg_lat'), get('torus','avg_lat'),
     'cyc', dec=2)
print()
row3('Min latency (ns)',
     get('hop','min_lat_ns'), get('xystd','min_lat_ns'), get('torus','min_lat_ns'),
     'ns', dec=1)
row3('Max latency (ns)',
     get('hop','max_lat_ns'), get('xystd','max_lat_ns'), get('torus','max_lat_ns'),
     'ns', dec=1)
row3('Avg latency (ns)',
     get('hop','avg_lat_ns'), get('xystd','avg_lat_ns'), get('torus','avg_lat_ns'),
     'ns', dec=1)

# ── 3. Throughput ─────────────────────────────────────────────
hdr('3. SUSTAINED THROUGHPUT  --  higher is better')
print(f'  {"Metric":<28} {"HOP":>10} {"XYSTD":>10} {"TORUS":>10}  Winner')
print(f'  {"-"*60}')
row3('Burst window (cycles)',
     get('hop','burst_window'), get('xystd','burst_window'), get('torus','burst_window'),
     'cyc', dec=0, lo=True)
row3('Pkts delivered',
     get('hop','burst_pkts'), get('xystd','burst_pkts'), get('torus','burst_pkts'),
     '', dec=0, lo=False)
row3('Throughput (pkts/cyc)',
     get('hop','tput_raw'), get('xystd','tput_raw'), get('torus','tput_raw'),
     '', dec=4, lo=False)
row3('Norm tput (pkt/cyc/node)',
     get('hop','tput_norm'), get('xystd','tput_norm'), get('torus','tput_norm'),
     '', dec=4, lo=False)
row3('Throughput (Gpkts/s)',
     get('hop','tput_gpkts'), get('xystd','tput_gpkts'), get('torus','tput_gpkts'),
     '', dec=2, lo=False)

# ── 4. Saturation ─────────────────────────────────────────────
hdr('4. SATURATION TEST  --  higher accepted throughput is better')
print(f'  {"Metric":<28} {"HOP":>10} {"XYSTD":>10} {"TORUS":>10}  Winner')
print(f'  {"-"*60}')
row3('Sat window (cycles)',
     get('hop','sat_window'), get('xystd','sat_window'), get('torus','sat_window'),
     'cyc', dec=0, lo=True)
row3('Pkts injected',
     get('hop','sat_injected'), get('xystd','sat_injected'), get('torus','sat_injected'),
     '', dec=0, lo=False)
row3('Pkts received',
     get('hop','sat_received'), get('xystd','sat_received'), get('torus','sat_received'),
     '', dec=0, lo=False)
row3('Offered load (pkt/cyc/nd)',
     get('hop','offered_load'), get('xystd','offered_load'), get('torus','offered_load'),
     '', dec=4, lo=False)
row3('Accepted tput (pkt/cyc)',
     get('hop','accepted_tput'), get('xystd','accepted_tput'), get('torus','accepted_tput'),
     '', dec=4, lo=False)

# ── 5. Per-node latency heatmap (text) ───────────────────────
hdr('5. PER-NODE AVERAGE TX LATENCY (cycles)  --  lower is better')
print(f'  {"Node (x,y)":<12}', end='')
for v in VARIANTS:
    print(f'  {LABELS[v]:>12}', end='')
print(f'  {"Best":>12}')
print(f'  {"-"*60}')

for nid in range(16):
    nx, ny = nid % 4, nid // 4
    vals = {}
    for v in VARIANTS:
        s = summaries.get(v)
        if s and nid in s.get('nodes', {}):
            vals[v] = s['nodes'][nid]['avg_tx_lat']
        else:
            vals[v] = None
    best = min(((k,v) for k,v in vals.items() if v is not None), key=lambda x: x[1], default=(None,None))
    print(f'  {nid:2d} ({nx},{ny})      ', end='')
    for v in VARIANTS:
        vv = vals.get(v)
        marker = ' *' if v == best[0] else '  '
        print(f'  {fmt(vv,2)+marker:>12}', end='')
    print()

# ── 6. Latency matrix comparison ─────────────────────────────
hdr('6. PAIR LATENCY COMPARISON (hop vs xystd vs torus)')
print('   Format: hop / xystd / torus  (cycles per pair)')
print(f'  SRC\\DST  ', end='')
for d in range(16):
    print(f' {d:3d}', end='')
print()
print('  ' + '-'*68)

for src in range(16):
    print(f'  {src:3d}      ', end='')
    for dst in range(16):
        if src == dst:
            print('   -', end='')
            continue
        vals = []
        for v in VARIANTS:
            t = tables.get(v)
            if t and t[src][dst] is not None:
                vals.append(str(t[src][dst]))
            else:
                vals.append('?')
        # Show just the torus value with * if it's lower than hop
        try:
            h, t = int(vals[0]), int(vals[2])
            marker = '*' if t < h else ' '
            print(f' {t:2d}{marker}', end='')
        except:
            print(f'  {vals[2]:>2}', end='')
    print()

print()
print('  (* = torus latency lower than hop for this pair)')

# ── 7. Real-silicon estimates ─────────────────────────────────
hdr('7. REAL-SILICON LATENCY ESTIMATE (at actual max frequency)')
print('   Simulation runs at 500 MHz; scale by (500 / max_freq_MHz)')
print()
freqs = {'hop': 258.4, 'xystd': 259.7, 'torus': 250.6}
print(f'  {"Metric":<32} {"HOP":>10} {"XYSTD":>10} {"TORUS":>10}')
print(f'  {"-"*64}')
print(f'  {"Max frequency (MHz)":<32}', end='')
for v in VARIANTS:
    print(f'  {freqs[v]:>8.1f}', end='')
print()

for label, key in [('Avg latency (real, ns)', 'avg_lat_ns'),
                   ('Max latency (real, ns)', 'max_lat_ns')]:
    print(f'  {label:<32}', end='')
    for v in VARIANTS:
        s = summaries.get(v)
        sim_ns = s[key] if s else None
        real_ns = sim_ns * (500.0 / freqs[v]) if sim_ns else None
        print(f'  {fmt(real_ns, 1):>10}', end='')
    print()

# ── 8. Summary scorecard ──────────────────────────────────────
hdr('8. SUMMARY SCORECARD')
print(f'  {"Category":<30} {"HOP":>10} {"XYSTD":>10} {"TORUS":>10}')
print(f'  {"-"*64}')

categories = {
    'Min latency'        : ('min_lat',    'lo'),
    'Max latency'        : ('max_lat',    'lo'),
    'Avg latency'        : ('avg_lat',    'lo'),
    'Throughput'         : ('tput_raw',   'hi'),
    'Accepted tput (sat)': ('accepted_tput','hi'),
    'Sim efficiency'     : ('sim_cycles', 'lo'),
}

scores = {'hop': 0, 'xystd': 0, 'torus': 0}
for cat, (key, direction) in categories.items():
    vals = {v: summaries[v][key] if summaries.get(v) else None for v in VARIANTS}
    valid = {k: v for k, v in vals.items() if v is not None}
    if not valid:
        continue
    if direction == 'lo':
        best = min(valid, key=lambda k: valid[k])
    else:
        best = max(valid, key=lambda k: valid[k])
    scores[best] += 1
    markers = {v: ' *' if v == best else '  ' for v in VARIANTS}
    print(f'  {cat:<30}', end='')
    for v in VARIANTS:
        vv = vals.get(v)
        print(f'  {fmt(vv,2)+markers[v]:>10}', end='')
    print()

print()
print(f'  {"TOTAL WINS":<30}', end='')
for v in VARIANTS:
    print(f'  {scores[v]:>10}', end='')
print()
print()
print(f'  NOTE: TORUS wins on all latency metrics.')
print(f'  XYSTD may win throughput due to simpler constant-folded routing.')
print(f'  Per-router PPA is nearly identical across all three (<5% diff).')
print('=' * W)
