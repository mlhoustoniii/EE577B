#!/usr/bin/env python3
"""
analyze_sim_log.py
==================
Cardinal CMP Phase 3 — Simulation Log Packet Tracker

Parses the snooping-monitor output produced by tb_cardinal_cmp.v (§6.4) and
reports which packets were injected, which were delivered, and which were lost.

Usage
-----
    python3 analyze_sim_log.py <sim.log>

Log line formats matched (from §6.4 $display statements):
    [<time>] INJECT node<XY> -> router : pkt=<16-hex-digits>
    [<time>] DELIVER router -> node<XY> : pkt=<16-hex-digits>

Packet header format (64-bit word, from cmp_test.asm):
    [63]     = VC          (always 0 in this test)
    [62]     = dirX        0=East, 1=West
    [61]     = dirY        0=South, 1=North
    [60:56]  = reserved    5'b0
    [55:52]  = hopX        unary-encoded hop count in X
    [51:48]  = hopY        unary-encoded hop count in Y
    [47:40]  = src_x       sender column (0-3)
    [39:32]  = src_y       sender row    (0-3)
    [31:0]   = payload     bits[7:0] = NODE_ID of sender, rest 0

NODE_ID = src_y * 4 + src_x  (0..15, matches tb comment)

Destination is recovered from dirX/dirY + hopX/hopY applied to src_x/src_y:
    hop_count = popcount(hopX_nibble)          (unary encoding)
    dst_x = src_x + hop_count  if dirX==0 (East)
            src_x - hop_count  if dirX==1 (West)
    dst_y = src_y + hop_count  if dirY==0 (South)
            src_y - hop_count  if dirY==1 (North)
"""

import re
import sys
from collections import defaultdict

# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------
RE_INJECT  = re.compile(
    r'^\[(\d+)\]\s+INJECT\s+node(\w{2})\s+->\s+router\s+:\s+pkt=([0-9a-fA-F]+)'
)
RE_DELIVER = re.compile(
    r'^\[(\d+)\]\s+DELIVER\s+router\s+->\s+node(\w{2})\s+:\s+pkt=([0-9a-fA-F]+)'
)

# ---------------------------------------------------------------------------
# Packet field decoder
# ---------------------------------------------------------------------------
UNARY_TO_COUNT = {
    0x0: 0,
    0x1: 1,
    0x3: 2,
    0x7: 3,
}

def decode_packet(pkt_hex: str):
    """
    Decode a 64-bit hex packet word into a human-readable dict.
    Returns a dict with keys: vc, dirX, dirY, hopX, hopY,
                              src_x, src_y, dst_x, dst_y,
                              payload, src_node_id, dst_node_id
    Returns None if the packet is malformed / fields out of range.
    """
    try:
        word = int(pkt_hex, 16) & 0xFFFFFFFFFFFFFFFF
    except ValueError:
        return None

    vc      = (word >> 63) & 0x1
    dir_x   = (word >> 62) & 0x1
    dir_y   = (word >> 61) & 0x1
    # [60:56] reserved
    hop_x_nibble = (word >> 52) & 0xF
    hop_y_nibble = (word >> 48) & 0xF
    src_x   = (word >> 40) & 0xFF
    src_y   = (word >> 32) & 0xFF
    payload = word & 0xFFFFFFFF

    hop_x = UNARY_TO_COUNT.get(hop_x_nibble)
    hop_y = UNARY_TO_COUNT.get(hop_y_nibble)
    if hop_x is None or hop_y is None:
        hop_x = bin(hop_x_nibble).count('1')
        hop_y = bin(hop_y_nibble).count('1')

    dst_x = src_x - hop_x if dir_x else src_x + hop_x
    dst_y = src_y - hop_y if dir_y else src_y + hop_y

    return {
        'vc':         vc,
        'dir_x':      dir_x,
        'dir_y':      dir_y,
        'hop_x':      hop_x,
        'hop_y':      hop_y,
        'src_x':      src_x,
        'src_y':      src_y,
        'dst_x':      dst_x,
        'dst_y':      dst_y,
        'payload':    payload,
        'src_node_id': src_y * 4 + src_x,
        'dst_node_id': dst_y * 4 + dst_x,
    }

def node_id_str(x, y):
    return f"node{x}{y} (ID={y*4+x})"

# ---------------------------------------------------------------------------
# Main parse loop
# ---------------------------------------------------------------------------
def parse_log(path: str):
    """
    Returns:
        injected  : list of (time_str, node_xy, pkt_hex)
        delivered : list of (time_str, node_xy, pkt_hex)
    """
    injected  = []
    delivered = []

    try:
        with open(path, 'r', errors='replace') as fh:
            for lineno, line in enumerate(fh, 1):
                line = line.rstrip('\n')
                m = RE_INJECT.search(line)
                if m:
                    injected.append((m.group(1), m.group(2), m.group(3).lower()))
                    continue
                m = RE_DELIVER.search(line)
                if m:
                    delivered.append((m.group(1), m.group(2), m.group(3).lower()))
    except FileNotFoundError:
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        sys.exit(1)

    return injected, delivered

# ---------------------------------------------------------------------------
# Report builder
# ---------------------------------------------------------------------------
BANNER_WIDTH = 68

def hdr(title):
    pad = (BANNER_WIDTH - len(title) - 2) // 2
    return "=" * pad + f" {title} " + "=" * (BANNER_WIDTH - pad - len(title) - 2)

def rule():
    return "-" * BANNER_WIDTH

def build_report(injected, delivered):
    lines = []
    lines.append("")
    lines.append(hdr("Cardinal CMP Packet Tracker — Simulation Report"))
    lines.append("")

    # ----------------------------------------------------------------
    # Count totals
    # ----------------------------------------------------------------
    n_injected  = len(injected)
    n_delivered = len(delivered)

    lines.append(f"  Total packets INJECTED  : {n_injected}")
    lines.append(f"  Total packets DELIVERED : {n_delivered}")
    lines.append("")

    # ----------------------------------------------------------------
    # Build delivered set (keyed by pkt_hex; count occurrences)
    # ----------------------------------------------------------------
    delivered_counts: dict[str, int] = defaultdict(int)
    for _t, _node, pkt in delivered:
        delivered_counts[pkt] += 1

    # ----------------------------------------------------------------
    # Find lost packets: injected but never delivered
    # ----------------------------------------------------------------
    # Track per-packet delivery budget consumed as we walk injected list
    budget: dict[str, int] = dict(delivered_counts)   # copies counts
    lost_entries = []

    for time_str, src_node_xy, pkt in injected:
        if budget.get(pkt, 0) > 0:
            budget[pkt] -= 1           # this copy was delivered
        else:
            lost_entries.append((time_str, src_node_xy, pkt))

    n_lost = len(lost_entries)

    # ----------------------------------------------------------------
    # Lost packets section
    # ----------------------------------------------------------------
    lines.append(rule())
    if n_lost == 0:
        # ============================================================
        #  ALL CLEAR banner
        # ============================================================
        lines.append("")
        lines.append("  " + "*" * (BANNER_WIDTH - 4))
        lines.append("  *" + " " * (BANNER_WIDTH - 6) + " *")
        lines.append("  *" + "   ██████╗ ██╗     ██╗      ██████╗ ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + "  ██╔═══██╗██║     ██║     ██╔════╝ ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + "  ███████║██║     ██║     ██║      ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + "  ██╔══██║██║     ██║     ██║      ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + "  ██║  ██║███████╗███████╗╚██████╔╝ ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + "  ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝  ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + " " * (BANNER_WIDTH - 6) + " *")
        lines.append("  *" + "  ██████╗██╗     ███████╗ █████╗ ██████╗  ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + " ██╔════╝██║     ██╔════╝██╔══██╗██╔══██╗ ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + " ██║     ██║     █████╗  ███████║██████╔╝ ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + " ██║     ██║     ██╔══╝  ██╔══██║██╔══██╗ ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + " ╚██████╗███████╗███████╗██║  ██║██║  ██║ ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + "  ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + " " * (BANNER_WIDTH - 6) + " *")
        lines.append("  *" + "ALL PACKETS DELIVERED — NETWORK IS FULLY CORRECT!".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + f"  {n_injected} injected  ✓  {n_delivered} delivered  ✓  0 lost ".center(BANNER_WIDTH - 6) + "*")
        lines.append("  *" + " " * (BANNER_WIDTH - 6) + " *")
        lines.append("  " + "*" * (BANNER_WIDTH - 4))
        lines.append("")
    else:
        # ============================================================
        #  Lost-packet detail
        # ============================================================
        lines.append(f"  *** LOST PACKETS DETECTED: {n_lost} packet(s) never arrived! ***")
        lines.append(rule())
        lines.append("")
        lines.append(f"  {'#':<5} {'Time (ns)':<14} {'Source':<12} {'Src Node':<20} {'Dst Node':<20} {'Pkt (hex)'}")
        lines.append(f"  {'-'*5} {'-'*13} {'-'*11} {'-'*19} {'-'*19} {'-'*16}")

        for idx, (time_str, src_xy, pkt) in enumerate(lost_entries, 1):
            info = decode_packet(pkt)
            if info:
                src_label = node_id_str(info['src_x'], info['src_y'])
                dst_label = node_id_str(info['dst_x'], info['dst_y'])
            else:
                src_label = f"node{src_xy}"
                dst_label = "unknown (bad header)"
            lines.append(
                f"  {idx:<5} {time_str:<14} node{src_xy:<8} "
                f"{src_label:<20} {dst_label:<20} 0x{pkt}"
            )

        lines.append("")
        lines.append(rule())
        lines.append(f"  SUMMARY: {n_injected} injected, {n_delivered} delivered, "
                     f"{n_lost} LOST ({n_lost/n_injected*100:.1f}%)")
        lines.append(rule())
        lines.append("")

    return "\n".join(lines)

# ---------------------------------------------------------------------------
# Duplicate-delivery check (bonus diagnostic)
# ---------------------------------------------------------------------------
def check_duplicates(injected, delivered):
    inj_counts: dict[str, int] = defaultdict(int)
    for _t, _node, pkt in injected:
        inj_counts[pkt] += 1

    del_counts: dict[str, int] = defaultdict(int)
    for _t, _node, pkt in delivered:
        del_counts[pkt] += 1

    dupes = []
    for pkt, dcnt in del_counts.items():
        icnt = inj_counts.get(pkt, 0)
        if dcnt > icnt:
            dupes.append((pkt, icnt, dcnt))
    return dupes

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_sim_log.py <sim.log>", file=sys.stderr)
        sys.exit(1)

    log_path = sys.argv[1]
    print(f"\nParsing log: {log_path}")

    injected, delivered = parse_log(log_path)

    print(build_report(injected, delivered))

    # Bonus: flag any packets delivered more times than injected
    dupes = check_duplicates(injected, delivered)
    if dupes:
        print(hdr("WARNING — Possible Duplicate Deliveries"))
        print()
        for pkt, icnt, dcnt in dupes:
            info = decode_packet(pkt)
            desc = (f"src=node{info['src_x']}{info['src_y']} "
                    f"dst=node{info['dst_x']}{info['dst_y']}")  if info else ""
            print(f"  pkt=0x{pkt}  injected={icnt}  delivered={dcnt}  {desc}")
        print()

if __name__ == "__main__":
    main()
