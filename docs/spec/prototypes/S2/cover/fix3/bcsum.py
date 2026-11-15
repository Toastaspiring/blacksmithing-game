"""fix-3: compare two trees' columns in bc.luau's output (after V2's bccmp3.py), per design and per part.
   python bcsum.py <a> <b> <names a,b> <file.tsv>...   (a, b: 0-based tree index in the files)
Counts what moved (verdict, the measure's head, exposedKept, contact, mass, owned volumes, volume probes, units, the measure's
order); lists every design whose verdict moved (with the parts) and every design where anything but the units moved while no
verdict did, and the units' largest moves."""
import sys
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")

FIELDS = ["verdict", "head", "exposed", "contact", "mass", "owned", "probes", "probeN", "units", "ord"]
a, b = int(sys.argv[1]), int(sys.argv[2])
na, nb = sys.argv[3].split(",")
rows = []
for f in sys.argv[4:]:
    for line in open(f, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        c = line.split("\t")
        idx, name, n = int(c[0]), c[1], int(c[2])
        trees = []
        for t in range((len(c) - 3) // 10):
            trees.append(dict(zip(FIELDS, c[3 + 10 * t: 13 + 10 * t])))
        rows.append((idx, name, n, trees))
rows.sort()
print(f"{len(rows)} designs, {na} vs {nb}")
cnt = Counter()
vmoved, quiet, units = [], [], []
for idx, name, n, trees in rows:
    A, B = trees[a], trees[b]
    if A["verdict"].startswith("ERROR") or B["verdict"].startswith("ERROR"):
        cnt["error"] += 1
        print("ERROR", name, A["verdict"][:120], B["verdict"][:120])
        continue
    moved = {f: A[f] != B[f] for f in FIELDS}
    for f in FIELDS:
        if moved[f]:
            cnt[f] += 1
    if moved["units"]:
        ua, ub = float(A["units"]), float(B["units"])
        units.append((ub - ua, ua, ub, name))
    if moved["verdict"]:
        va, vb = A["verdict"].split("/")[0], B["verdict"].split("/")[0]
        parts = [i + 1 for i in range(min(len(va), len(vb))) if va[i] != vb[i]]
        vmoved.append((name, A["verdict"], B["verdict"], parts))
        continue
    other = [f for f in ("head", "exposed", "contact", "mass", "owned", "probes", "probeN", "ord") if moved[f]]
    if other:
        quiet.append((name, other))
print("moved:", dict(cnt))
print(f"\nverdict moved on {len(vmoved)}:")
for name, va, vb, parts in vmoved:
    print(f"  {name}: {va} -> {vb} parts {parts}")
print(f"\nanything but the units moved with no verdict moving on {len(quiet)}:")
for name, other in quiet[:40]:
    print(f"  {name}: {', '.join(other)}")
if units:
    units.sort()
    up = [u for u in units if u[0] > 0]
    down = [u for u in units if u[0] < 0]
    print(f"\nunits moved on {len(units)} ({len(up)} up, {len(down)} down)")
    for d, ua, ub, name in units[:5] + units[-5:]:
        print(f"  {name}: {ua:.3f} -> {ub:.3f} ({d:+.3f}, {100 * d / ua:+.2f} %)")
    hi = max(float(t[b]["units"]) for _, _, _, t in rows if not t[b]["verdict"].startswith("ERROR") and "CAPPED" not in t[b]["verdict"])
    hia = max(float(t[a]["units"]) for _, _, _, t in rows if not t[a]["verdict"].startswith("ERROR") and "CAPPED" not in t[a]["verdict"])
    print(f"  the heaviest valid: {na} {hia:.3f}, {nb} {hi:.3f}")
