"""m2x-fix-5: the truth for rim_acc.luau's circles at 50 digits (mpmath), and each candidate's error.
   python rim_acc.py out/rim_acc.tsv
The circle: centre d, radius r, in the plane square to n (both as given, n made a unit in mp); its farthest point from the
line through the origin along u (made a unit): the largest of 8,192 samples, each of the 4 best local maxima refined by 200
golden sections. Errors as reading − truth, by tilt class."""
import sys
import mpmath as mp

sys.stdout.reconfigure(encoding="utf-8")
mp.mp.dps = 50

COLS = ["v1", "s6", "s8", "p8", "p10", "above", "below", "old", "rms"]


def truth(d, r, n, u):
    n = [mp.mpf(x) for x in n]
    nl = mp.sqrt(sum(x * x for x in n))
    n = [x / nl for x in n]
    u = [mp.mpf(x) for x in u]
    ul = mp.sqrt(sum(x * x for x in u))
    u = [x / ul for x in u]
    d = [mp.mpf(x) for x in d]
    r = mp.mpf(r)
    # a frame of the plane
    t = [1, 0, 0] if abs(n[0]) < 0.6 else [0, 1, 0]
    a = [n[1] * t[2] - n[2] * t[1], n[2] * t[0] - n[0] * t[2], n[0] * t[1] - n[1] * t[0]]
    al = mp.sqrt(sum(x * x for x in a))
    a = [x / al for x in a]
    b = [n[1] * a[2] - n[2] * a[1], n[2] * a[0] - n[0] * a[2], n[0] * a[1] - n[1] * a[0]]

    def D(phi):
        c, s = mp.cos(phi), mp.sin(phi)
        x = [d[i] + r * (c * a[i] + s * b[i]) for i in range(3)]
        p = sum(x[i] * u[i] for i in range(3))
        return mp.sqrt(sum((x[i] - p * u[i]) ** 2 for i in range(3)))

    N = 1024
    vals = [D(2 * mp.pi * k / N) for k in range(N)]
    peaks = sorted([k for k in range(N) if vals[k] >= vals[k - 1] and vals[k] >= vals[(k + 1) % N]], key=lambda k: -vals[k])[:4]
    best = max(vals)
    g = (mp.sqrt(5) - 1) / 2
    for k in peaks:
        lo, hi = 2 * mp.pi * (k - 1) / N, 2 * mp.pi * (k + 1) / N
        for _ in range(170):
            t1, t2 = hi - g * (hi - lo), lo + g * (hi - lo)
            if D(t1) >= D(t2):
                hi = t2
            else:
                lo = t1
        best = max(best, D((lo + hi) / 2))
    return best


def tclass(th):
    th = float(th)
    if th == 0:
        return "0"
    if th < 1e-6 * 0.999:
        return "<1e-6"
    if th < 1.1e-6:
        return "~1e-6"
    if th < 1e-3:
        return "1e-6..1e-3"
    return ">=1e-3"


worst = {}
bad = []
n = 0
for line in open(sys.argv[1], encoding="utf-8"):
    c = line.rstrip("\n").split("\t")
    if len(c) < 21:
        continue
    k, th = int(c[0]), c[1]
    v = [float(x) for x in c[2:]]
    d, r, nn, u = v[0:3], v[3], v[4:7], v[7:10]
    res = dict(zip(COLS, v[10:19]))
    T = truth(d, r, nn, u)
    n += 1
    cl = tclass(th)
    for col in COLS:
        e = float(res[col] - T) if not isinstance(res[col], mp.mpf) else float(res[col] - T)
        e = float(mp.mpf(res[col]) - T)
        key = (cl, col)
        lo, hi = worst.get(key, (0.0, 0.0))
        worst[key] = (min(lo, e), max(hi, e))
        if col == "above" and e < -1e-15:
            bad.append((k, col, e))
        if col == "below" and e > 1e-15:
            bad.append((k, col, e))
print(f"{n} circles")
for cl in ["0", "<1e-6", "~1e-6", "1e-6..1e-3", ">=1e-3"]:
    print(f"tilt {cl}:")
    for col in COLS:
        if (cl, col) in worst:
            lo, hi = worst[(cl, col)]
            print(f"   {col:6s} reading − truth in [{lo:.3g}, {hi:.3g}]")
print(f"bounds on the wrong side by more than 1e-15: {len(bad)}")
for b in bad[:20]:
    print("  ", b)
