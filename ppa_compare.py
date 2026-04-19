#!/usr/bin/env python3
# ==============================================================
# ppa_compare.py
# EE577B Cardinal Router -- PPA Comparison Script
# Hop-based (gold_router) vs Standard XY (gold_router_xystd)
#
# Run from ~/577B/project/:
#   python3 ppa_compare.py
# ==============================================================

import os
import re

# ---- Paths to report files ----
BASE_HOP   = os.path.expanduser("~/577B/project/EE577B/report")
BASE_XYSTD = os.path.expanduser("~/577B/project/v2/report")

def read_file(path):
    try:
        with open(path, 'r') as f:
            return f.read()
    except:
        return None

def extract_area(content):
    """Extract total cell area from DC area report."""
    if not content: return None
    m = re.search(r'Total cell area:\s+([\d.]+)', content)
    return float(m.group(1)) if m else None

def extract_timing(content):
    """Extract critical path delay and slack from DC timing report."""
    if not content: return None, None
    # Look for the last (worst) slack entry
    slacks   = re.findall(r'slack \((\w+)\)\s+([\d.]+)', content)
    arrivals = re.findall(r'data arrival time\s+([\d.]+)', content)
    if not slacks or not arrivals:
        return None, None
    # First occurrence is the critical path (most timing)
    status = slacks[0][0]   # MET or VIOLATED
    slack  = float(slacks[0][1])
    if status == 'VIOLATED':
        slack = -slack
    arrival = float(arrivals[0])
    return arrival, slack

def extract_power(content):
    """Extract dynamic and leakage power from DC power report."""
    if not content: return None, None, None
    dyn   = re.search(r'Total Dynamic Power\s+=\s+([\d.]+)\s+(\w+)', content)
    leak  = re.search(r'Cell Leakage Power\s+=\s+([\d.]+)\s+(\w+)', content)
    total = re.search(r'Total\s+[\d.]+\s+\w+\s+[\d.]+\s+\w+\s+[\S]+\s+\w+\s+([\d.]+)\s+(\w+)', content)

    def to_mw(val, unit):
        val = float(val)
        unit = unit.lower()
        if unit == 'mw':  return val
        if unit == 'uw':  return val / 1e3
        if unit == 'nw':  return val / 1e6
        if unit == 'w':   return val * 1e3
        return val

    dyn_mw  = to_mw(dyn.group(1), dyn.group(2))   if dyn   else None
    leak_uw = float(leak.group(1)) if leak else None
    if leak and leak.group(2).lower() == 'mw':
        leak_uw = float(leak.group(1)) * 1e3

    total_mw = dyn_mw + (leak_uw/1e3) if (dyn_mw and leak_uw) else None
    return dyn_mw, leak_uw, total_mw

# ---- Load reports ----
hop_area_txt    = read_file(f"{BASE_HOP}/gold_router.area")
hop_timing_txt  = read_file(f"{BASE_HOP}/gold_router.timing")
hop_power_txt   = read_file(f"{BASE_HOP}/gold_router.power")

xy_area_txt     = read_file(f"{BASE_XYSTD}/gold_router_xystd.area")
xy_timing_txt   = read_file(f"{BASE_XYSTD}/gold_router_xystd.timing")
xy_power_txt    = read_file(f"{BASE_XYSTD}/gold_router_xystd.power")

# ---- Extract numbers ----
hop_area                    = extract_area(hop_area_txt)
xy_area                     = extract_area(xy_area_txt)

hop_arrival, hop_slack      = extract_timing(hop_timing_txt)
xy_arrival,  xy_slack       = extract_timing(xy_timing_txt)

hop_dyn, hop_leak, hop_tot  = extract_power(hop_power_txt)
xy_dyn,  xy_leak,  xy_tot   = extract_power(xy_power_txt)

CLOCK_PERIOD = 4.0  # ns

def max_freq(arrival, slack):
    if arrival is None: return None
    eff_period = CLOCK_PERIOD - slack if slack else arrival
    return 1000.0 / eff_period  # MHz

hop_freq = max_freq(hop_arrival, hop_slack)
xy_freq  = max_freq(xy_arrival,  xy_slack)

# ---- Delta calculations ----
def delta(a, b, label="%"):
    if a is None or b is None: return "N/A"
    d = (b - a) / a * 100
    sign = "+" if d >= 0 else ""
    return f"{sign}{d:.1f}%"

def better(a, b, lower_is_better=True):
    if a is None or b is None: return ""
    if lower_is_better:
        return "HOP BETTER" if a < b else ("XYSTD BETTER" if b < a else "TIED")
    else:
        return "HOP BETTER" if a > b else ("XYSTD BETTER" if b > a else "TIED")

# ---- Print Report ----
W = 60
print("=" * W)
print("  EE577B Cardinal Router -- PPA Comparison")
print("  Hop-Based (gold_router)  vs  Standard XY (gold_router_xystd)")
print("  Technology: NCSU FreePDK 45nm | Clock: 250 MHz (4.0 ns)")
print("=" * W)

print("\n── TIMING ──────────────────────────────────────────────")
print(f"  {'Metric':<28} {'HOP':>10} {'XYSTD':>10} {'Delta':>8}")
print(f"  {'-'*58}")
fmt = lambda x, u: f"{x:.3f} {u}" if x is not None else "N/A"
print(f"  {'Critical Path (ns)':<28} {fmt(hop_arrival,'ns'):>10} {fmt(xy_arrival,'ns'):>10} {delta(hop_arrival,xy_arrival):>8}")
print(f"  {'Slack (ns)':<28} {fmt(hop_slack,'ns'):>10} {fmt(xy_slack,'ns'):>10}")
print(f"  {'Max Frequency (MHz)':<28} {fmt(hop_freq,'MHz'):>10} {fmt(xy_freq,'MHz'):>10} {delta(hop_freq,xy_freq,False):>8}")
print(f"  Winner: {better(hop_arrival, xy_arrival, lower_is_better=True)}")

print("\n── AREA ────────────────────────────────────────────────")
NAND2 = 1.404   # NAND2X1 area in NCSU45 (gate equivalent reference)
hop_ge  = hop_area / NAND2 if hop_area else None
xy_ge   = xy_area  / NAND2 if xy_area  else None
print(f"  {'Metric':<28} {'HOP':>10} {'XYSTD':>10} {'Delta':>8}")
print(f"  {'-'*58}")
print(f"  {'Total Cell Area (um^2)':<28} {fmt(hop_area,''):>10} {fmt(xy_area,''):>10} {delta(hop_area,xy_area):>8}")
print(f"  {'Gate Equivalents (GE)':<28} {fmt(hop_ge,''):>10} {fmt(xy_ge,''):>10} {delta(hop_ge,xy_ge):>8}")
if hop_area and xy_area:
    print(f"  Full mesh x16 HOP  : {hop_area*16:>10.1f} um^2  ({hop_ge*16:.0f} GE)")
    print(f"  Full mesh x16 XYSTD: {xy_area*16:>10.1f} um^2  ({xy_ge*16:.0f} GE)")
print(f"  Winner: {better(hop_area, xy_area, lower_is_better=True)}")

print("\n── POWER ───────────────────────────────────────────────")
print(f"  {'Metric':<28} {'HOP':>10} {'XYSTD':>10} {'Delta':>8}")
print(f"  {'-'*58}")
print(f"  {'Dynamic Power (mW)':<28} {fmt(hop_dyn,'mW'):>10} {fmt(xy_dyn,'mW'):>10} {delta(hop_dyn,xy_dyn):>8}")
print(f"  {'Leakage Power (uW)':<28} {fmt(hop_leak,'uW'):>10} {fmt(xy_leak,'uW'):>10} {delta(hop_leak,xy_leak):>8}")
print(f"  {'Total Power (mW)':<28} {fmt(hop_tot,'mW'):>10} {fmt(xy_tot,'mW'):>10} {delta(hop_tot,xy_tot):>8}")
if hop_tot and xy_tot:
    print(f"  Full mesh x16 HOP  : {hop_tot*16:>10.3f} mW  = {hop_tot*16/1000:.5f} W")
    print(f"  Full mesh x16 XYSTD: {xy_tot*16:>10.3f} mW  = {xy_tot*16/1000:.5f} W")
print(f"  Winner: {better(hop_tot, xy_tot, lower_is_better=True)}")

print("\n── SUMMARY ─────────────────────────────────────────────")
print(f"  Routing scheme         HOP (unary shift)  vs  XYSTD (8-bit compare)")
print(f"  Packet modification    YES (hop decrement)     NO (pass-through)")
print(f"  Header size            8-bit hopX+hopY         16-bit dst_x+dst_y")
print(f"  Routing logic per port ~4-bit shift            ~8-bit comparator x2")
print(f"  VC/arbiter/handshake   IDENTICAL               IDENTICAL")
if all(x is not None for x in [hop_area, xy_area, hop_tot, xy_tot, hop_freq, xy_freq]):
    print(f"\n  Area   delta: {delta(hop_area, xy_area)}  ({better(hop_area,xy_area)})")
    print(f"  Power  delta: {delta(hop_tot, xy_tot)}  ({better(hop_tot,xy_tot)})")
    print(f"  Timing delta: {delta(hop_arrival, xy_arrival)}  ({better(hop_arrival,xy_arrival)})")

print("\n  NOTE: cardinal_nic was NOT synthesized for v2 (xystd).")
print("  cardinal_nic is a PE-side adapter and does NOT implement")
print("  routing logic -- its PPA would be identical in both")
print("  variants. Omitting it does NOT affect this comparison.")
print("=" * W)
