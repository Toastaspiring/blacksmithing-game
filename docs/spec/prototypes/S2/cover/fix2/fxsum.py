"""fix-2: summarize fxc.luau output: per tree k > 0, the parts whose verdict differs from tree 0's, by the truth's band."""
import sys
names = sys.argv[1].split(",")
files = sys.argv[2:]
rows = []
for f in files:
    for line in open(f, encoding="utf-8"):
        line = line.rstrip("\n")
        if line:
            rows.append(line.split("\t"))
nt = len(names)
print(f"{len(rows)} designs")
BANDS = [0.02, 0.025, 0.03, 0.04, 0.05]
for k in range(1, nt):
    moved = []  # (truth, design, part, shape, dir)
    caps = 0
    capNames = []
    designs = set()
    for r in rows:
        kp, ku = r[3], r[4]
        kk, kku = r[3 + 2 * k], r[4 + 2 * k]
        if kk.endswith("/CAP") and not kp.endswith("/CAP"):
            caps += 1
            capNames.append(r[1])
        flips = r[3 + 2 * nt] if len(r) > 3 + 2 * nt else ""
        for fl in filter(None, flips.split(",")):
            i, shape, truth, v = fl.split(":")
            if v[0] != v[k]:
                moved.append((float(truth), r[1], int(i), shape, v[0] + ">" + v[k]))
                designs.add(r[1])
    cleaned = [m for m in moved if m[4] == "1>0"]
    kept = [m for m in moved if m[4] == "0>1"]
    print(f"{names[k]} vs {names[0]}: {len(moved)} verdicts move on {len(designs)} designs ({len(cleaned)} cleaned, {len(kept)} kept); newly capped {caps} {capNames[:5]}")
    hidden = [m for m in cleaned if m[0] < 0.02]
    print(f"   cleaned that truly show under 2 %: {len(hidden)} (closed false kept)")
    for lo, hi in zip(BANDS, BANDS[1:] + [9]):
        b = [m for m in cleaned if lo <= m[0] < hi]
        print(f"   false Enclosed at a true share in [{lo*100:.1f}, {hi*100:.1f}) %: {len(b)}" + (f"  shapes {sorted(set(x[3] for x in b))}" if b else ""))
    worst = sorted(cleaned, reverse=True)[:8]
    for w in worst:
        print(f"      {w[0]*100:.3f} % {w[3]} part {w[2]} of {w[1]}")
