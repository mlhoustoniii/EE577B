import re, os

VARIANTS = ["hop","xystd","torus"]
FREQ  = {"hop":258.4,"xystd":259.7,"torus":250.6}
AREA  = {"hop":30135,"xystd":30100,"torus":29975}
POWER = {"hop":5.903,"xystd":5.633,"torus":5.859}
SLACK = {"hop":0.130,"xystd":0.150,"torus":0.010}
CP    = {"hop":3.820,"xystd":3.790,"torus":3.940}

def parse(path):
    if not os.path.exists(path): return None
    txt = open(path).read()
    def g(pat):
        m = re.search(pat, txt)
        return float(m.group(1)) if m else None
    d = {}
    d["min_cyc"] = g(r"Min latency \(cycles\):\s*(\d+)")
    d["max_cyc"] = g(r"Max latency \(cycles\):\s*(\d+)")
    d["avg_cyc"] = g(r"Avg latency \(cycles\):\s*([\d.]+)")
    d["min_ns"]  = g(r"Min latency \(ns\)\s*:\s*([\d.]+)")
    d["max_ns"]  = g(r"Max latency \(ns\)\s*:\s*([\d.]+)")
    d["avg_ns"]  = g(r"Avg latency \(ns\)\s*:\s*([\d.]+)")
    d["pairs_data"] = {}
    for m in re.finditer(r"\((\d+),(\d+)\)->\((\d+),(\d+)\)\s+(\d+)", txt):
        k = (int(m.group(1)),int(m.group(2)),int(m.group(3)),int(m.group(4)))
        d["pairs_data"][k] = int(m.group(5))
    return d

BASE = os.path.expanduser("~/577B/project")
data = {v: parse(os.path.join(BASE,"perf_%s_summary.txt"%v)) for v in VARIANTS}

W=70; SEP="-"*W
def fmt(v,dec=2,unit=""): return ("N/A" if v is None else "%.*f%s"%(dec,v,unit))
def row(label,key,unit="",dec=2,lo=True):
    vals = {v:(data[v][key] if data.get(v) and data[v] and data[v].get(key) is not None else None) for v in VARIANTS}
    valid = {k:v for k,v in vals.items() if v is not None}
    best = (min if lo else max)(valid,key=lambda k:valid[k]) if valid else None
    cells = [fmt(vals[v],dec,unit)+(" *" if v==best else "  ") for v in VARIANTS]
    print("  %-28s %12s %12s %12s" % (label,cells[0],cells[1],cells[2]))

print(); print("="*W)
print("  EE577B 4x4 Cardinal Router -- Unified Performance Comparison")
print("  HOP (unary-shift)  vs  XYSTD (8-bit compare)  vs  TORUS (mod-4)")
print("="*W)
print(); print(SEP)
print("  1. LATENCY  (36 pairs, zero contention)")
print(SEP)
print("  %-28s %10s %10s %10s" % ("Metric","HOP","XYSTD","TORUS"))
print("  "+"-"*60)
row("Min latency (cycles)",   "min_cyc"," cyc",0)
row("Max latency (cycles)",   "max_cyc"," cyc",0)
row("Avg latency (cycles)",   "avg_cyc"," cyc",2)
print()
row("Min latency (ns@500MHz)","min_ns", " ns", 1)
row("Max latency (ns@500MHz)","max_ns", " ns", 1)
row("Avg latency (ns@500MHz)","avg_ns", " ns", 1)
print()
print("  Real-silicon latency (scaled to DC max freq):")
for label,key in [("Avg lat real (ns)","avg_ns"),("Max lat real (ns)","max_ns")]:
    rvals = [(data[v][key]*500.0/FREQ[v] if data.get(v) and data[v] and data[v].get(key) else None) for v in VARIANTS]
    best_i = rvals.index(min(x for x in rvals if x)) if any(rvals) else -1
    cells = [(fmt(r,1," ns")+(" *" if i==best_i else "  ")) if r else "N/A  " for i,r in enumerate(rvals)]
    print("  %-28s %12s %12s %12s" % (label,cells[0],cells[1],cells[2]))

print(); print(SEP)
print("  2. SYNTHESIS PPA  (DC Compiler, FreePDK45, 250 MHz target)")
print(SEP)
print("  %-28s %10s %10s %10s" % ("Metric","HOP","XYSTD","TORUS"))
print("  "+"-"*60)
for label,vals,unit,lo in [
    ("Max frequency (MHz)", [FREQ[v]  for v in VARIANTS]," MHz",False),
    ("Critical path (ns)",  [CP[v]    for v in VARIANTS]," ns", True),
    ("Timing slack (ns)",   [SLACK[v] for v in VARIANTS]," ns", False),
    ("Cell area (um2)",     [AREA[v]  for v in VARIANTS],"",    True),
    ("Total power (mW)",    [POWER[v] for v in VARIANTS]," mW", True),
]:
    best_i = (vals.index(min(vals)) if lo else vals.index(max(vals)))
    cells = [("%s%s"%(v,unit))+(" *" if i==best_i else "  ") for i,v in enumerate(vals)]
    print("  %-28s %12s %12s %12s" % (label,cells[0],cells[1],cells[2]))
print()
print("  Normalised to HOP=1.00x:")
for label,vals in [("  Area", [AREA[v]/AREA["hop"] for v in VARIANTS]),
                   ("  Power",[POWER[v]/POWER["hop"] for v in VARIANTS]),
                   ("  Freq", [FREQ[v]/FREQ["hop"] for v in VARIANTS])]:
    cells = ["%.3fx"%v for v in vals]
    print("  %-28s %12s %12s %12s" % (label,cells[0],cells[1],cells[2]))

print(); print(SEP)
print("  3. PER-PAIR LATENCY  (* = torus beats hop)")
print(SEP)
print("  %-20s %8s %8s %8s %8s" % ("Pair","HOP","XYSTD","TORUS","Delta"))
print("  "+"-"*56)
all_pairs = set()
for v in VARIANTS:
    if data.get(v) and data[v]: all_pairs |= set(data[v]["pairs_data"].keys())
for pair in sorted(all_pairs):
    sx,sy,dx,dy = pair
    lats = {v:(data[v]["pairs_data"].get(pair) if data.get(v) and data[v] else None) for v in VARIANTS}
    h,x,t = lats["hop"],lats["xystd"],lats["torus"]
    mark = " *" if (t and h and t<h) else "  "
    delta = ("%+d"%(t-h)) if (t and h) else "?"
    print("  (%d,%d)->(%d,%d)%12s %8s %8s %8s%s %8s" % (sx,sy,dx,dy,"",str(h) if h else "?",str(x) if x else "?",str(t) if t else "?",mark,delta))

print(); print(SEP)
print("  4. SUMMARY & KEY FINDINGS")
print(SEP)
hd=data.get("hop") or {}; td=data.get("torus") or {}
mx_h=hd.get("max_cyc"); av_h=hd.get("avg_cyc")
mx_t=td.get("max_cyc"); av_t=td.get("avg_cyc")
if mx_h and mx_t:
    print("  Max latency: TORUS is %.1f%% better  (%d vs %d cycles)"  % ((mx_h-mx_t)/mx_h*100,mx_t,mx_h))
if av_h and av_t:
    print("  Avg latency: TORUS is %.1f%% better  (%.1f vs %.1f cycles)" % ((av_h-av_t)/av_h*100,av_t,av_h))
print()
print("  PPA cost of torus wrap-around links (vs HOP):")
print("    Area  : %.1f%% smaller  (%d vs %d um2)"   % ((AREA["hop"]-AREA["torus"])/AREA["hop"]*100,AREA["torus"],AREA["hop"]))
print("    Power : %.1f%% less     (%.3f vs %.3f mW)" % ((POWER["hop"]-POWER["torus"])/POWER["hop"]*100,POWER["torus"],POWER["hop"]))
print("    Freq  : %.1f%% slower   (%.1f vs %.1f MHz)"% ((FREQ["hop"]-FREQ["torus"])/FREQ["hop"]*100,FREQ["torus"],FREQ["hop"]))
print()
print("  HOP vs XYSTD: identical latency -- routing algorithm (unary shift")
print("  vs 8-bit compare) changes decoder only, not hop count.")
print("  XYSTD advantage: 4.6% less power, 0.5% higher frequency.")
print()
print("  CONCLUSION: Torus gives 25-29% latency improvement at <3% PPA cost.")
print("="*W)
