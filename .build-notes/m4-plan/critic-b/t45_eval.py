# M4 plan critic B: evaluate the plan's T-MG-04 / T-MG-05 assertions on the prototype's fixed-seed runs (plan names).
import re, sys, math
dist = open(sys.argv[1], encoding="utf-8").read()
ref = {}
for m in re.finditer(r'family = "(\w+)", tier = "(\w+)", material = "(\w+)", profile = "(\w+)".*?scores = \{([^}]*)\}', dist, re.S):
    xs = [float(v) for v in m.group(5).replace("\n", " ").split(",") if v.strip()]
    mu = sum(xs) / len(xs); sd = math.sqrt(sum((x - mu) ** 2 for x in xs) / (len(xs) - 1))
    ref[m.groups()[:4]] = (math.floor(mu * 1000 + 0.5) / 1000, math.floor(sd * 1000 + 0.5) / 1000)
got = {}
for line in open(sys.argv[2]):
    if line.startswith("CELL"):
        p = line.split()
        got[tuple(p[1:5])] = dict(mean=float(p[6]), fails=int(p[8]), n=int(p[10]), flagged=int(p[12]))
bands = {("Average", "Normal"): (0.03, 0.15), ("Average", "Hard"): (0.15, 0.40), ("Good", "Normal"): (None, 0.05), ("Good", "Hard"): (None, 0.15)}
fails = []; worstz = 0; minband = 1
for k, g in got.items():
    m0, s0 = ref[k]
    half = 4 * s0 / 20 + 0.0005
    z = abs(g["mean"] - m0) / half
    worstz = max(worstz, z)
    if z > 1: fails.append(("T-MG-04 mean", k, g["mean"], m0, half))
    if g["flagged"]: fails.append(("T-MG-04 flagged", k, g["flagged"]))
    fam, tier, mat, prof = k
    if (prof, tier) in bands:
        lo, hi = bands[(prof, tier)]; r = g["fails"] / g["n"]
        d = min(r - lo if lo is not None else 1, hi - r)
        minband = min(minband, d)
        if d < 0: fails.append(("T-MG-04 Q8", k, r, lo, hi))
        if d < 0.02: print("  close Q8:", "/".join(k), "rate %.3f band %s..%s" % (r, lo, hi))
print("T-MG-04: worst |mean - E-S3.2| as a fraction of the band: %.2f; smallest Q8 margin %.3f" % (worstz, minband))
for fam in ("HoldZone", "TimingStrike", "PrecisionTrace"):
    for mat in ("Iron", "Steel"):
        for tier in ("Normal", "Hard"):
            ms = [got[(fam, tier, mat, p)]["mean"] for p in ("Elite", "Good", "Average", "Poor")]
            if not (ms[0] > ms[1] > ms[2] > ms[3]): fails.append(("T-MG-05 order", fam, tier, mat, ms))
        for prof in ("Elite", "Good", "Average", "Poor"):
            d = got[(fam, "Normal", mat, prof)]["mean"] - got[(fam, "Hard", mat, prof)]["mean"]
            thr = 0.05 if prof == "Average" else 0.0
            if prof == "Average" or d < 0.02: print("  T-MG-05 drop %-14s %-5s %-7s %.4f (need %s %.2f)" % (fam, mat, prof, d, ">=" if thr else ">", thr))
            if (thr and d < thr) or (not thr and d <= 0): fails.append(("T-MG-05 drop", fam, mat, prof, d))
print("FAILURES:", fails if fails else "none")
