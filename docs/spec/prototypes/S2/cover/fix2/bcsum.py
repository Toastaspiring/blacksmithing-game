"""fix-2: summarize bc.luau output. Trees in column groups of 5 (verdict, measure, mass, probes, units).
usage: python bcsum.py <names comma-separated> <pairs like 0-2,1-2> <files...>
"""
import sys

names = sys.argv[1].split(",")
pairs = [tuple(int(x) for x in p.split("-")) for p in sys.argv[2].split(",")]
files = sys.argv[3:]
FIELDS = ["verdict", "measure", "mass", "probes", "units"]
rows = []
for f in files:
    with open(f, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            cols = line.split("\t")
            rows.append(cols)
print(f"{len(rows)} designs")
for a, b in pairs:
    counts = {k: 0 for k in FIELDS}
    measureNoVerdict = []
    massNoVerdict = []
    verdictMoved = []
    errors = 0
    for cols in rows:
        ga = cols[2 + 5 * a: 2 + 5 * a + 5]
        gb = cols[2 + 5 * b: 2 + 5 * b + 5]
        if ga[0].startswith("ERROR") or gb[0].startswith("ERROR"):
            errors += 1
            continue
        for i, k in enumerate(FIELDS):
            if ga[i] != gb[i]:
                counts[k] += 1
        if ga[0] != gb[0]:
            verdictMoved.append(cols[1])
        else:
            if ga[1] != gb[1]:
                measureNoVerdict.append(cols[1])
            if ga[2] != gb[2]:
                massNoVerdict.append(cols[1])
    print(f"{names[a]} vs {names[b]}: differ {counts}; errors {errors}")
    print(f"   verdict moved on {len(verdictMoved)}: {verdictMoved[:12]}")
    print(f"   measure moved with no verdict moving on {len(measureNoVerdict)}: {measureNoVerdict[:12]}")
    print(f"   mass moved with no verdict moving on {len(massNoVerdict)}: {massNoVerdict[:12]}")
