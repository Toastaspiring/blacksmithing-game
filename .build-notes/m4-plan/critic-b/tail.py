# M4 plan critic B: lower tail of the per-run mean deviation (Elite 30 fps / 360 px), and the chance that the minimum
# over the plan's 10,000 runs per half falls under 0.0024 u (3 x PT_PRECISE_MEAN_DEV).
import sys, math
import numpy as np
from scipy import stats
rows = {}
for line in open(sys.argv[1]):
    parts = line.split()
    rows[parts[0]] = np.array([float(x) for x in parts[1:]])
FLOOR = 0.0024
for tier, x in rows.items():
    x = np.sort(x); n = len(x)
    q = {p: np.quantile(x, p) for p in (0.0001, 0.001, 0.01, 0.05, 0.5)}
    print("%s n %d  min %.5f  q0.0001 %.5f q0.001 %.5f q0.01 %.5f q0.05 %.5f median %.5f  below 0.0032 (4x): %d  below 0.0028: %d"
          % (tier, n, x[0], q[0.0001], q[0.001], q[0.01], q[0.05], q[0.5], (x < 0.0032).sum(), (x < 0.0028).sum()))
    # (a) parametric: normal and skew-normal fits of log(meanDev), tail probability at the floor
    lx = np.log(x)
    mu, sd = lx.mean(), lx.std(ddof=1)
    p_norm = stats.norm.cdf((math.log(FLOOR) - mu) / sd)
    a, loc, sc = stats.skewnorm.fit(lx)
    p_skew = stats.skewnorm.cdf(math.log(FLOOR), a, loc, sc)
    # (b) GPD on the lowest 2 % (peaks over threshold on the reversed variable)
    k = int(0.02 * n); u = x[k]
    exc = u - x[:k]
    c, _, scale = stats.genpareto.fit(exc, floc=0)
    p_gpd = 0.02 * (stats.genpareto.sf(u - FLOOR, c, 0, scale) if u > FLOOR else 1.0)
    for name, p1 in (("lognormal", p_norm), ("skew-normal(log)", p_skew), ("GPD lowest 2%", p_gpd)):
        pmin = 1 - (1 - p1) ** 10000
        print("   %-17s P(one run < 0.0024) %.2e  -> P(min of 10,000 < 0.0024) %.3f" % (name, p1, pmin))
