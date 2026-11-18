# Throwaway: statistics of the shipped S3 score distributions (2000 runs per cell), to size M4's L3 assertions.
import re, sys, math, random
src = open(sys.argv[1], encoding="utf-8").read()
cells = {}
for m in re.finditer(r'family = "(\w+)", tier = "(\w+)", material = "(\w+)", profile = "(\w+)".*?scores = \{([^}]*)\}', src, re.S):
    fam, tier, mat, prof, body = m.groups()
    xs = [float(v) for v in body.replace("\n", " ").split(",") if v.strip()]
    cells[(fam, tier, mat, prof)] = xs
print("cells", len(cells), "runs", {k: len(v) for k, v in list(cells.items())[:1]})
def mean(a): return sum(a) / len(a)
def sd(a):
    m = mean(a); return math.sqrt(sum((x - m) ** 2 for x in a) / (len(a) - 1))
def phi(z): return 0.5 * (1 + math.erf(z / math.sqrt(2)))
N = 400
fams = ["HoldZone", "TimingStrike", "PrecisionTrace"]; tiers = ["Normal", "Hard"]; mats = ["Iron", "Steel"]; profs = ["Elite", "Good", "Average", "Poor"]
print("\n# fail rates (score < 0.5): full 2000 and first 400; P(400-run rate outside band) by binomial normal approx")
bands = {("Average", "Normal"): (0.03, 0.15), ("Average", "Hard"): (0.15, 0.40), ("Good", "Normal"): (0.0, 0.05), ("Good", "Hard"): (0.0, 0.15)}
for f in fams:
    for t in tiers:
        for mt in mats:
            for p in ("Good", "Average"):
                xs = cells[(f, t, mt, p)]
                fr = sum(1 for x in xs if x < 0.5) / len(xs); fr400 = sum(1 for x in xs[:N] if x < 0.5) / N
                lo, hi = bands[(p, t)]
                se = math.sqrt(max(fr * (1 - fr), 1e-9) / N)
                pout = phi((lo - fr) / se) + (1 - phi((hi - fr) / se)) if lo > 0 else (1 - phi((hi - fr) / se))
                print(f"{f:14s} {t:6s} {mt:5s} {p:7s} fail2000 {fr*100:5.1f}% first400 {fr400*100:5.1f}% band {lo*100:.0f}-{hi*100:.0f}% P(out)~{pout:.2e}")
print("\n# Iron - Steel mean drop, paired by run index (same pattern/bot seeds); SE for 400 paired runs; STEEL_MEAN_DROP [0.01, 0.08]")
for f in fams:
    for t in tiers:
        for p in profs:
            a = cells[(f, t, "Iron", p)]; b = cells[(f, t, "Steel", p)]
            d = [x - y for x, y in zip(a, b)]
            md, sdd = mean(d), sd(d); se = sdd / math.sqrt(N)
            d400 = mean(d[:N])
            plow = phi((0.01 - md) / se); phigh = 1 - phi((0.08 - md) / se)
            print(f"{f:14s} {t:6s} {p:7s} drop2000 {md:+.4f} sd_d {sdd:.4f} first400 {d400:+.4f} SE400 {se:.4f} P(<0.01) {plow:.3f} P(>0.08) {phigh:.1e}")
print("\n# Normal -> Hard mean drop per material/profile, paired by index; TIER_MIN_MEAN_DROP 0.05 for Average, >0 for others")
for f in fams:
    for mt in mats:
        for p in profs:
            a = cells[(f, "Normal", mt, p)]; b = cells[(f, "Hard", mt, p)]
            d = [x - y for x, y in zip(a, b)]
            md, sdd = mean(d), sd(d); se = sdd / math.sqrt(N)
            thr = 0.05 if p == "Average" else 0.0
            pf = phi((thr - md) / se)
            print(f"{f:14s} {mt:5s} {p:7s} drop2000 {md:+.4f} first400 {mean(d[:N]):+.4f} SE400 {se:.4f} P(<= {thr}) {pf:.2e}")
print("\n# cell means: 2000 vs first 400; SE400; deviation in SE")
worst = 0
for k, xs in cells.items():
    m, m4 = mean(xs), mean(xs[:N]); se = sd(xs) / math.sqrt(N)
    worst = max(worst, abs(m4 - m) / se)
    print(f"{k[0]:14s} {k[1]:6s} {k[2]:5s} {k[3]:7s} mean {m:.4f} sd {sd(xs):.4f} first400 {m4:.4f} SE400 {se:.4f} z {abs(m4-m)/se:.2f}")
print("max |z| first400 vs 2000:", round(worst, 2))
# profile order: Elite > Good > Average > Poor means per cell group
print("\n# profile order margins (mean differences, 2000 runs)")
for f in fams:
    for t in tiers:
        for mt in mats:
            ms = [mean(cells[(f, t, mt, p)]) for p in profs]
            print(f"{f:14s} {t:6s} {mt:5s} E-G {ms[0]-ms[1]:+.3f} G-A {ms[1]-ms[2]:+.3f} A-P {ms[2]-ms[3]:+.3f}")
