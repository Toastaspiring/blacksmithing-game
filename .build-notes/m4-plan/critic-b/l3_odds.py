# M4 plan critic B: predictive false-failure odds of the plan's L3 assertions, from the shipped 2,000-run cells.
# "Predictive" = the build's fresh-seed sample (the plan's configSalt seeds are new seeds) AND the uncertainty of the
# 2,000-run estimate the thresholds are compared with. The planner's figures treat the 2,000-run value as the truth.
import re, sys, math
from math import lgamma, exp, log, sqrt, erf

src = open(sys.argv[1], encoding="utf-8").read()
cells = {}
for m in re.finditer(r'family = "(\w+)", tier = "(\w+)", material = "(\w+)", profile = "(\w+)".*?scores = \{([^}]*)\}', src, re.S):
    fam, tier, mat, prof, body = m.groups()
    cells[(fam, tier, mat, prof)] = [float(v) for v in body.replace("\n", " ").split(",") if v.strip()]
assert len(cells) == 48 and all(len(v) == 2000 for v in cells.values())
def mean(a): return sum(a) / len(a)
def sd(a):
    m = mean(a); return sqrt(sum((x - m) ** 2 for x in a) / (len(a) - 1))
def Phi(z): return 0.5 * (1 + erf(z / sqrt(2)))
FAMS = ["HoldZone", "TimingStrike", "PrecisionTrace"]; TIERS = ["Normal", "Hard"]; MATS = ["Iron", "Steel"]
PROFS = ["Elite", "Good", "Average", "Poor"]
out = []
def P(*a):
    s = " ".join(str(x) for x in a); print(s); out.append(s)

# E-S3.2's printed values (3 decimals), which the plan's T-MG-04 compares against
def r3(x): return math.floor(x * 1000 + 0.5) / 1000

P("== T-MG-04 cell means: |mean_400 - E-S3.2 mean| <= 4*sd/sqrt(400) + 0.0005, fresh seeds")
tot = 0; worst = []
for k, xs in cells.items():
    m, s = mean(xs), sd(xs)
    mp, sp = r3(m), r3(s)
    half = 4 * sp / 20 + 0.0005
    sdp = s * sqrt(1 / 400 + 1 / 2000)            # predictive SD of the build's 400-run mean
    p = Phi((mp - half - m) / sdp) + 1 - Phi((mp + half - m) / sdp)
    tot += p; worst.append((p, k))
worst.sort(reverse=True)
P("  sum over 48 cells %.4f (plan: ~3e-3); worst cells:" % tot, [("%.1e" % p, "/".join(k)) for p, k in worst[:4]])

P("\n== T-MG-04 Q8 fail rates on BOT_RUNS_FAIL = 1000 fresh runs (beta-binomial predictive, Jeffreys prior)")
def betabinom_pmf(k, n, a, b):
    return exp(lgamma(n + 1) - lgamma(k + 1) - lgamma(n - k + 1) + lgamma(k + a) + lgamma(n - k + b) - lgamma(n + a + b)
               + lgamma(a + b) - lgamma(a) - lgamma(b))
def p_out(xs, n, lo, hi):
    k0 = sum(1 for x in xs if x < 0.5); a, b = k0 + 0.5, len(xs) - k0 + 0.5
    po = 0.0
    for k in range(n + 1):
        r = k / n
        if (lo is not None and r < lo) or r > hi:
            po += betabinom_pmf(k, n, a, b)
    # the planner's way: binomial at the 2,000-run rate, normal approximation
    p0 = k0 / len(xs); se = sqrt(max(p0 * (1 - p0), 1e-12) / n)
    naive = (Phi((lo - p0) / se) if lo is not None else 0) + 1 - Phi((hi - p0) / se)
    return k0 / len(xs), po, naive
bands = {("Average", "Normal"): (0.03, 0.15), ("Average", "Hard"): (0.15, 0.40), ("Good", "Normal"): (None, 0.05), ("Good", "Hard"): (None, 0.15)}
tq = 0; tq400 = 0
for f in FAMS:
    for t in TIERS:
        for mt in MATS:
            for pr in ("Average", "Good"):
                lo, hi = bands[(pr, t)]
                rate, po, naive = p_out(cells[(f, t, mt, pr)], 1000, lo, hi)
                _, po400, _ = p_out(cells[(f, t, mt, pr)], 400, lo, hi)
                tq += po; tq400 += po400
                if po > 1e-4:
                    P("  %-14s %-6s %-5s %-7s rate %.3f  P(out) at 1000: %.4f (planner-style %.1e); at 400: %.4f" % (f, t, mt, pr, rate, po, naive, po400))
P("  sum over 24 band checks: %.4f at 1000 runs (plan: ~1.5e-3); %.4f at 400 runs" % (tq, tq400))

P("\n== T-MG-05 Normal -> Hard drop on T-MG-04's runs (plan: salts per tier, so UNPAIRED 400 vs 400)")
t5 = 0
for f in FAMS:
    for mt in MATS:
        for pr in PROFS:
            a = cells[(f, "Normal", mt, pr)]; b = cells[(f, "Hard", mt, pr)]
            D = mean(a) - mean(b)
            dpair = [x - y for x, y in zip(a, b)]; vD = sd(dpair) ** 2 / 2000      # 2,000-run estimate's own variance
            sun = sqrt((sd(a) ** 2 + sd(b) ** 2) / 400 + vD)                         # unpaired fresh 400 + estimate
            spa = sqrt(sd(dpair) ** 2 / 400 + vD)                                    # if T-MG-04 paired the tiers
            thr = 0.05 if pr == "Average" else 0.0
            pu, pp = Phi((thr - D) / sun), Phi((thr - D) / spa)
            t5 += pu
            if pu > 1e-5:
                P("  %-14s %-5s %-7s drop %.4f  P(fail) unpaired %.4f | paired %.4f (plan: ~3e-4)" % (f, mt, pr, D, pu, pp))
P("  sum %.4f" % t5)

P("\n== T-MG-06 Iron - Steel, Average Normal, paired, STEEL_DROP_RUNS fresh seeds")
for f, n in (("HoldZone", 4000), ("TimingStrike", 20000), ("PrecisionTrace", 4000)):
    a = cells[(f, "Normal", "Iron", "Average")]; b = cells[(f, "Normal", "Steel", "Average")]
    d = [x - y for x, y in zip(a, b)]; D, S = mean(d), sd(d)
    for nn in (400, n):
        sp = sqrt(S * S / nn + S * S / 2000); sn = S / sqrt(nn)
        P("  %-14s drop %.4f sd_d %.4f n %5d: P(<0.01) %.3f (naive %.3f)  P(<0.005) %.3f (naive %.3f)  P(<0.002) %.4f  P(>0.08) %.1e"
          % (f, D, S, nn, Phi((0.01 - D) / sp), Phi((0.01 - D) / sn), Phi((0.005 - D) / sp), Phi((0.005 - D) / sn), Phi((0.002 - D) / sp), 1 - Phi((0.08 - D) / sp)))
    P("     the 2,000-run estimate alone: drop %.4f +- %.4f; P(true drop < 0.005) = %.3f" % (D, S / sqrt(2000), Phi((0.005 - D) / (S / sqrt(2000)))))

P("\n== T-MG-12 fairness bound: per-pattern-mean SD <= total SD of the cell (Average, Iron)")
for f in FAMS:
    for t in TIERS:
        xs = cells[(f, t, "Iron", "Average")]
        P("  %-14s %-6s total SD %.4f  (FAIRNESS_MAX_SD 0.08: %s)" % (f, t, sd(xs), "cannot fail" if sd(xs) < 0.075 else "can fail if patterns carry most of the variance"))
open(sys.argv[2], "w").write("\n".join(out) + "\n")
