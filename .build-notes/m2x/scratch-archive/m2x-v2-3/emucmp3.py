"""V2 round 3: emu3.luau's table, column against column: every step's D, exact and at the printed 4 decimals, and tiers.
   python emucmp3.py <emu3.tsv> <colA> <colB>"""
import sys, re

path, ca, cb = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path, encoding="utf-8").read().splitlines()
head = lines[0].split("\t")
ia, ib = head.index(ca), head.index(cb)


def steps(cell):
    out = {}
    for m in re.finditer(r"(\w\w) ([-0-9.e+]+) (\w+)/(\w+)", cell):
        out[m.group(1)] = (float(m.group(2)), m.group(3), m.group(4))
    return out


exact = printed = tier = 0
rows = []
for line in lines[1:]:
    c = line.split("\t")
    name, A, B = c[0], c[ia], c[ib]
    if A.startswith("no steps") or B.startswith("no steps"):
        if A != B:
            rows.append(f"  {name}: {A} | {B}")
        continue
    sa, sb = steps(A), steps(B)
    diffs = []
    for k in sa:
        da, db = sa[k][0], sb[k][0]
        if da != db:
            exact += 1
            d = abs(da - db)
            flag = ""
            if round(da, 4) != round(db, 4):
                printed += 1
                flag = " PRINTED"
            if sa[k][1] != sb[k][1]:
                tier += 1
                flag += " TIER"
            diffs.append(f"{k} {da:.6f}->{db:.6f} (|d| {d:.2e}){flag}")
    if diffs:
        rows.append(f"  {name}: " + "; ".join(diffs))
print(f"{len(lines) - 1} designs, {ca} vs {cb}: steps differing exactly {exact}, at 4 decimals {printed}, tiers {tier}")
print("\n".join(rows))
