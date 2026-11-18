"""V2 round 3: compare two trees' columns in bc3.luau's output, per design and per part.
   python bccmp3.py <a> <b> <names a,b> <file.tsv>...   (a, b: 0-based tree index in the files)
For each design: verdict moved (per part), measure moved (head, exposedKept per part, contact rows), mass moved (report,
owned per part), probes moved, units, and whether the measure's rank order differs. Lists every design where something
other than units moved without a verdict moving, with the parts and the cause it can find."""
import sys
from collections import Counter

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
vmoved, quiet = [], []
for idx, name, n, trees in rows:
    A, B = trees[a], trees[b]
    if A["verdict"].startswith("ERROR") or B["verdict"].startswith("ERROR"):
        cnt["error"] += 1
        print("ERROR", name, A["verdict"][:80], B["verdict"][:80])
        continue
    moved = {f: A[f] != B[f] for f in FIELDS}
    for f in FIELDS:
        if moved[f]:
            cnt[f] += 1
    if moved["verdict"]:
        va, vb = A["verdict"].split("/")[0], B["verdict"].split("/")[0]
        parts = [i + 1 for i in range(min(len(va), len(vb))) if va[i] != vb[i]]
        vmoved.append((name, A["verdict"], B["verdict"], parts))
        continue
    other = [f for f in ("head", "exposed", "contact", "mass", "owned", "probes", "probeN") if moved[f]]
    if other:
        detail = []
        if moved["exposed"]:
            ea, eb = A["exposed"].split(" "), B["exposed"].split(" ")
            detail.append("exposedKept parts " + ",".join(str(i + 1) for i in range(len(ea)) if ea[i] != eb[i]))
        if moved["owned"]:
            oa, ob = A["owned"].split(" "), B["owned"].split(" ")
            detail.append("owned parts " + ",".join(str(i + 1) for i in range(len(oa)) if oa[i] != ob[i]))
        if moved["mass"]:
            ma, mb = A["mass"].split(" "), B["mass"].split(" ")
            names = ["mass", "volume", "comx", "comy", "comz", "balance", "bfh", "reach", "bladeL", "totalL", "offAxis",
                     "guardPos", "gpx", "gpy", "gpz", "gax", "gay", "hOverlap", "refined"]
            detail.append("mass fields " + ",".join(f"{names[i]} {ma[i]}->{mb[i]}" for i in range(len(ma)) if ma[i] != mb[i]))
        quiet.append((name, other, moved["ord"], "; ".join(detail)))
print("moved:", dict(cnt))
print(f"\nverdict moved on {len(vmoved)}:")
for name, va, vb, parts in vmoved:
    print(f"  {name}: {va} -> {vb} parts {parts}")
print(f"\nsomething but units moved with no verdict moving on {len(quiet)}:")
for name, other, ordmoved, detail in quiet:
    print(f"  {name}: {other} measure-order differs={ordmoved} | {detail[:400]}")
