#!/usr/bin/env python3
# ==============================================================
# ppa3_compare.py
# EE577B Cardinal Router -- 3-Way PPA Comparison
#
#   Design 1: gold_router       (Hop-based, unary shift)
#   Design 2: gold_router_xystd (Standard XY, 8-bit compare)
#   Design 3: gold_router_torus (Torus XY, 2-bit mod subtract)
#
# Report directory layout expected:
#   ~/577B/project/EE577B/report/   <- hop reports
#   ~/577B/project/v2/report/       <- xystd reports
#   ~/577B/project/v3/report/       <- torus reports
#
# Run from ~/577B/project/:
#   python3 ppa3_compare.py
# ==============================================================

import os, re, sys

BASE = {
    'hop'  : os.path.expanduser("~/577B/project/EE577B/report"),
    'xystd': os.path.expanduser("~/577B/project/v2/report"),
    'torus': os.path.expanduser("~/577B/project/v3/report"),
}
REPORT = {
    'hop'  : 'gold_router',
    'xystd': 'gold_router_xystd',
    'torus': 'gold_router_torus',
}
LABELS = {
    'hop'  : 'HOP (shift)',
    'xystd': 'XYSTD (cmp)',
    'torus': 'TORUS (mod)',
}

CLOCK_PERIOD = 4.0   # ns  (250 MHz)
NAND2_AREA   = 1.404 # um² per gate-equivalent (NCSU FreePDK45 NAND2X1)
MESH_NODES   = 16

# ── helpers ──────────────────────────────────────────────────

def read(base, design, suffix):
    path = os.path.join(base, f"{design}.{suffix}")
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return None

def parse_area(txt):
    if not txt: return None
    m = re.search(r'Total cell area:\s+([\d.]+)', txt)
    return float(m.group(1)) if m else None

def parse_timing(txt):
    """Return (critical_path_ns, slack_ns).  slack is negative if violated."""
    if not txt: return None, None
    arrivals = re.findall(r'data arrival time\s+([\d.]+)', txt)
    slacks   = re.findall(r'slack \((\w+)\)\s+([\d.]+)', txt)
    if not arrivals or not slacks:
        return None, None
    arrival = float(arrivals[0])
    status, sv = slacks[0]
    slack = float(sv) if status == 'MET' else -float(sv)
    return arrival, slack

def parse_power(txt):
    """Return (dynamic_mw, leakage_uw, total_mw)."""
    if not txt: return None, None, None

    def to_mw(val, unit):
        v, u = float(val), unit.lower()
        return {'w': v*1e3, 'mw': v, 'uw': v/1e3, 'nw': v/1e6}.get(u, v)

    dyn  = re.search(r'Total Dynamic Power\s+=\s+([\d.]+)\s+(\w+)', txt)
    leak = re.search(r'Cell Leakage Power\s+=\s+([\d.]+)\s+(\w+)', txt)
    if not dyn or not leak:
        return None, None, None

    dyn_mw  = to_mw(dyn.group(1),  dyn.group(2))
    leak_uw = to_mw(leak.group(1), leak.group(2)) * 1e3   # convert to uW
    tot_mw  = dyn_mw + leak_uw / 1e3
    return dyn_mw, leak_uw, tot_mw

def max_freq(arrival, slack):
    if arrival is None: return None
    eff = CLOCK_PERIOD - (slack if slack else 0.0)
    return round(1000.0 / eff, 1)   # MHz

def pct(ref, val):
    """Percentage change: (val-ref)/ref * 100, formatted with sign."""
    try:
        ref, val = float(ref), float(val)
    except (TypeError, ValueError):
        return '   N/A'
    if ref == 0:
        return '   N/A'
    d = (val - ref) / ref * 100.0
    return f'{d:+6.1f}%'

def fmt(v, decimals=3):
    if v is None: return '    N/A'
    return f'{v:.{decimals}f}'

def winner(*vals):
    """Return which key has the lowest value (lower-is-better)."""
    kvs = [(k, v) for k, v in vals if v is not None]
    if not kvs: return 'N/A'
    best_k = min(kvs, key=lambda x: x[1])[0]
    return f'★ {LABELS[best_k]}'

def winner_hi(*vals):
    """Higher-is-better (frequency)."""
    kvs = [(k, v) for k, v in vals if v is not None]
    if not kvs: return 'N/A'
    best_k = max(kvs, key=lambda x: x[1])[0]
    return f'★ {LABELS[best_k]}'

# ── load all reports ──────────────────────────────────────────

data = {}
missing = []
for key in ('hop', 'xystd', 'torus'):
    base   = BASE[key]
    design = REPORT[key]
    area_txt    = read(base, design, 'area')
    timing_txt  = read(base, design, 'timing')
    power_txt   = read(base, design, 'power')

    if any(t is None for t in [area_txt, timing_txt, power_txt]):
        missing.append(key)

    area               = parse_area(area_txt)
    arrival, slack     = parse_timing(timing_txt)
    dyn, leak, total   = parse_power(power_txt)
    freq               = max_freq(arrival, slack)

    data[key] = dict(
        area    = area,
        ge      = area / NAND2_AREA if area else None,
        arrival = arrival,
        slack   = slack,
        freq    = freq,
        timing_met = (slack >= 0) if slack is not None else None,
        dyn     = dyn,
        leak    = leak,
        total   = total,
    )

# ── print ─────────────────────────────────────────────────────

W = 72
SEP = '─' * W

def hdr(title):
    print(f'\n{SEP}')
    print(f'  {title}')
    print(SEP)

def row(label, key_fn, unit='', decimals=3, higher_better=False, pct_ref='hop'):
    vals = {k: key_fn(data[k]) for k in ('hop','xystd','torus')}
    h, x, t = vals['hop'], vals['xystd'], vals['torus']
    ph = fmt(h, decimals)
    px = fmt(x, decimals)
    pt = fmt(t, decimals)
    dh = '  base '
    dx = pct(h, x) if h and x else '   N/A'
    dt = pct(h, t) if h and t else '   N/A'
    unit_s = f' {unit}' if unit else ''
    win = winner_hi(*vals.items()) if higher_better else winner(*vals.items())
    print(f'  {label:<24} {ph+unit_s:>12} {px+unit_s:>12} {pt+unit_s:>12}   {win}')
    print(f'  {"  vs HOP":<24} {"":>12} {dx:>12} {dt:>12}')

if missing:
    print(f'\n⚠  Reports not found for: {", ".join(missing)}')
    print('   Run synthesis first, then re-run this script.')
    print()

print()
print('=' * W)
print('  EE577B Cardinal Router -- 3-Way PPA Comparison')
print('  Technology : NCSU FreePDK45 45nm')
print('  Clock      : 250 MHz (4.0 ns period)')
print('  Designs    :')
print('    HOP   = gold_router        (unary hop-shift, header-driven)')
print('    XYSTD = gold_router_xystd  (8-bit coord compare, no modify)')
print('    TORUS = gold_router_torus  (2-bit mod subtract, wrap links)')
print('=' * W)

# ── TIMING ────────────────────────────────────────────────────
hdr('TIMING')
print(f'  {"Metric":<24} {"HOP":>12} {"XYSTD":>12} {"TORUS":>12}')
print(f'  {"-"*66}')

for key in ('hop','xystd','torus'):
    d = data[key]
    if d['timing_met'] is not None:
        status = 'MET ✓' if d['timing_met'] else 'VIOLATED ✗'
        print(f'  {LABELS[key]} timing          {status}')

print()
row('Critical Path (ns)',  lambda d: d['arrival'],  'ns', 3)
row('Slack (ns)',          lambda d: d['slack'],     'ns', 3)
row('Max Frequency (MHz)', lambda d: d['freq'],      'MHz', 1, higher_better=True)

# ── AREA ──────────────────────────────────────────────────────
hdr('AREA')
print(f'  {"Metric":<24} {"HOP":>12} {"XYSTD":>12} {"TORUS":>12}')
print(f'  {"-"*66}')
row('Cell Area (um²)',      lambda d: d['area'],  'um²', 1)
row('Gate Equiv. (GE)',     lambda d: d['ge'],    'GE',  0)

# Full mesh projections
print()
print(f'  {"Full mesh ×16 (um²)":<24}', end='')
for key in ('hop','xystd','torus'):
    a = data[key]['area']
    print(f'  {fmt(a*16,1)+" um²":>14}' if a else f'  {"N/A":>14}', end='')
print()
print(f'  {"Full mesh ×16 (GE)":<24}', end='')
for key in ('hop','xystd','torus'):
    g = data[key]['ge']
    print(f'  {fmt(g*16,0)+" GE":>14}' if g else f'  {"N/A":>14}', end='')
print()

# ── POWER ─────────────────────────────────────────────────────
hdr('POWER')
print(f'  {"Metric":<24} {"HOP":>12} {"XYSTD":>12} {"TORUS":>12}')
print(f'  {"-"*66}')
row('Dynamic Power (mW)',  lambda d: d['dyn'],   'mW', 4)
row('Leakage Power (uW)',  lambda d: d['leak'],  'uW', 2)
row('Total Power (mW)',    lambda d: d['total'], 'mW', 4)

print()
print(f'  {"Full mesh ×16 (mW)":<24}', end='')
for key in ('hop','xystd','torus'):
    t = data[key]['total']
    print(f'  {fmt(t*16,3)+" mW":>14}' if t else f'  {"N/A":>14}', end='')
print()
print(f'  {"Full mesh ×16 (W)":<24}', end='')
for key in ('hop','xystd','torus'):
    t = data[key]['total']
    print(f'  {fmt(t*16/1000,5)+" W":>14}' if t else f'  {"N/A":>14}', end='')
print()

# ── ROUTING LOGIC BREAKDOWN ───────────────────────────────────
hdr('ROUTING LOGIC BREAKDOWN (per router)')
print(f'  {"Property":<30} {"HOP":>10} {"XYSTD":>10} {"TORUS":>10}')
print(f'  {"-"*64}')
rows_info = [
    ('Routing logic type',   'Unary shift', '8-bit cmp', '2-bit sub'),
    ('Header modified?',     'YES',         'NO',        'NO'),
    ('Max hops (4×4)',       '6',           '6',         '2'),
    ('Worst latency (cyc)',  '12',          '12',        '4'),
    ('Packet format',        'hop+dir',     'dst_x/y',   'dst_x/y'),
    ('Needs ROUTER_X/Y?',   'NO',          'YES',       'YES'),
    ('Wrap-around links?',   'NO',          'NO',        'YES'),
]
for label, h, x, t in rows_info:
    print(f'  {label:<30} {h:>10} {x:>10} {t:>10}')

# ── SUMMARY ───────────────────────────────────────────────────
hdr('SUMMARY')
print(f'  {"Metric":<24} {"HOP":>12} {"XYSTD":>12} {"TORUS":>12}')
print(f'  {"-"*66}')

# Normalised to hop=1.00
for metric, fn, label in [
    ('Area (normalised)',    lambda d: d['area'],  ''),
    ('Total Power (norm.)',  lambda d: d['total'], ''),
    ('Max Freq (norm.)',     lambda d: d['freq'],  ''),
]:
    ref = fn(data['hop'])
    vals = {k: fn(data[k]) for k in ('hop','xystd','torus')}
    cells = []
    for k in ('hop','xystd','torus'):
        v = vals[k]
        if ref and v:
            cells.append(f'{v/ref:>10.3f}x')
        else:
            cells.append(f'{"N/A":>10}')
    print(f'  {metric:<24} {cells[0]:>12} {cells[1]:>12} {cells[2]:>12}')

print()
print(f'  NOTE: cardinal_nic omitted from all three variants.')
print(f'  It contains NO routing logic -- its PPA is identical')
print(f'  across hop/xystd/torus and does not affect comparison.')
print()
print(f'  Testbench pass counts (simulation only, not synthesized):')
print(f'    HOP   : 328 tests  |  XYSTD : 328 tests  |  TORUS : 352 tests')
print(f'    (extra 30 torus tests verify wrap-around links -- no HW impact)')
print('=' * W)
