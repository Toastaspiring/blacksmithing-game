import json, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
cands = json.load(open(os.path.join(ROOT, "results/cands.json")))
rows = []
for line in open(os.path.join(ROOT, "results/cost_final.txt"), encoding="utf-8"):
    m = re.match(r"cands\.json#(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)", line)
    if m:
        i = int(m[1])
        rows.append(dict(i=i, verdict=float(m[2]), m2=float(m[3]), m3=float(m[4]), total=float(m[5]), studio=float(m[6]), gap=float(m[7]), frm=cands[i - 1]["from"]))
byTotal = sorted(rows, key=lambda r: -r["total"])
byVerdict = sorted(rows, key=lambda r: -r["verdict"])
pick = []
for r in byTotal[:8] + byVerdict[:3] + [r for r in byTotal if r["frm"].startswith("clampedP")][:1]:
    if r not in pick:
        pick.append(r)
for r in pick:
    print(r["frm"], r["verdict"], r["m2"], r["m3"], r["total"], r["studio"], r["gap"])
out = []
for r in sorted(pick, key=lambda r: -r["total"]):
    out.append({"from": r["frm"], "lune_ms": {"verdict": r["verdict"], "m2": r["m2"], "m3": r["m3"], "total": r["total"]}, "parts": cands[r["i"] - 1]["parts"]})
path = r"C:\Users\louis\Documents\RANDOM\ROBLOX\Blacksmithing Game\docs\spec\prototypes\S2\verdict\worst_P.json"
with open(path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(out, f, separators=(",", ":"))
    f.write("\n")
print(len(out), "designs,", os.path.getsize(path), "bytes")
shapes = {}
for r in pick:
    k = {}
    for p in cands[r["i"] - 1]["parts"]:
        k[p["shape"]] = k.get(p["shape"], 0) + 1
    print(r["frm"], k, len(cands[r["i"] - 1]["parts"]))
