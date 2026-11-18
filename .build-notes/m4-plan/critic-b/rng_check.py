# M4 plan critic B: (1) the plan's [3.2] Rng formulas, written in IEEE doubles exactly as Luau would run them
# (mod(x, m) = x - floor(x / m) * m, no % or //), checked against exact integer arithmetic; (2) every T-RNG-01 vector
# the plan lists; (3) the fixed-seed outcomes of T-RNG-04/05/06 as the plan specifies them; (4) the null distribution
# of a lag-1 2-D chi-square computed on OVERLAPPING pairs.
import math, random, sys
import numpy as np

F32 = 4294967296.0

def fmod_(x, m):           # plan [3.2]: mod(x, m) = x - floor(x / m) * m, all in doubles
    return x - math.floor(x / m) * m

def band(a, b): return float(int(a) & int(b))
def bxor(a, b): return float(int(a) ^ int(b))
def rshift(a, n): return float(int(a) >> n)
def lshift(a, n): return float((int(a) << n) & 0xFFFFFFFF)
def lrot(a, n):
    a = int(a); return float(((a << n) | (a >> (32 - n))) & 0xFFFFFFFF)

def assert_bit32_arg(x):
    assert 0 <= x < F32 and x == math.floor(x), x

def mul32_f(a, b):         # plan: ah = rshift(a,16), al = band(a,0xFFFF); hi = mod(ah*b, 65536); mod(hi*65536 + al*b, 2^32)
    assert_bit32_arg(a); assert_bit32_arg(b)
    ah = rshift(a, 16); al = band(a, 0xFFFF)
    p1 = ah * b
    assert p1 < 2.0**53
    hi = fmod_(p1, 65536.0)
    s = hi * 65536.0 + al * b
    assert s < 2.0**53
    return fmod_(s, F32)

def fnv_f(s):
    h = 2166136261.0
    for ch in s.encode():
        h = mul32_f(bxor(h, ch), 16777619.0)
    return h

def fmix_f(z):
    z = mul32_f(bxor(z, rshift(z, 16)), float(0x85EBCA6B))
    z = mul32_f(bxor(z, rshift(z, 13)), float(0xC2B2AE35))
    return bxor(z, rshift(z, 16))

class RngF:
    def __init__(self, seed, tag=""):
        assert seed == math.floor(seed) and 0 <= seed < F32
        x = bxor(float(seed), fnv_f(tag))
        s = []
        for _ in range(4):
            x = fmod_(x + float(0x9E3779B9), F32)
            s.append(fmix_f(x))
        self.s = s
    @staticmethod
    def from_state(a, b, c, d):
        r = RngF.__new__(RngF); r.s = [float(a), float(b), float(c), float(d)]; return r
    def u32(self):
        s0, s1, s2, s3 = self.s
        p = s1 * 5.0; assert p < 2.0**53
        r = lrot(fmod_(p, F32), 7) * 9.0
        result = fmod_(r, F32)
        t = lshift(s1, 9)
        s2 = bxor(s2, s0); s3 = bxor(s3, s1); s1 = bxor(s1, s2); s0 = bxor(s0, s3); s2 = bxor(s2, t); s3 = lrot(s3, 11)
        self.s = [s0, s1, s2, s3]
        return result
    def f(self): return self.u32() / F32

# exact integer reference (independent)
M = 0xFFFFFFFF
def mul32_i(a, b): return (a * b) & M
def fnv_i(s):
    h = 0x811C9DC5
    for ch in s.encode(): h = ((h ^ ch) * 0x01000193) & M
    return h
def fmix_i(z):
    z ^= z >> 16; z = (z * 0x85EBCA6B) & M; z ^= z >> 13; z = (z * 0xC2B2AE35) & M; z ^= z >> 16; return z
class RngI:
    __slots__ = ("s0", "s1", "s2", "s3")
    def __init__(self, seed, tag=""):
        x = seed ^ fnv_i(tag); st = []
        for _ in range(4):
            x = (x + 0x9E3779B9) & M; st.append(fmix_i(x))
        self.s0, self.s1, self.s2, self.s3 = st
    def u32(self):
        s0, s1, s2, s3 = self.s0, self.s1, self.s2, self.s3
        x = (s1 * 5) & M
        result = ((((x << 7) | (x >> 25)) & M) * 9) & M
        t = (s1 << 9) & M
        s2 ^= s0; s3 ^= s1; s1 ^= s2; s0 ^= s3; s2 ^= t; s3 = ((s3 << 11) | (s3 >> 21)) & M
        self.s0, self.s1, self.s2, self.s3 = s0, s1, s2, s3
        return result

out = []
def P(*a):
    line = " ".join(str(x) for x in a); print(line); out.append(line)

# (1) exactness of the double-arithmetic formulas
rnd = random.Random(12345)
edge = [0, 1, 2, 0xFFFF, 0x10000, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFE, 0xFFFFFFFF, 0x01000193, 0x811C9DC5, 0x85EBCA6B, 0xC2B2AE35]
bad = 0; n = 0
for a in edge:
    for b in edge:
        n += 1; bad += int(mul32_f(float(a), float(b))) != mul32_i(a, b)
for _ in range(300000):
    a, b = rnd.getrandbits(32), rnd.getrandbits(32); n += 1
    bad += int(mul32_f(float(a), float(b))) != mul32_i(a, b)
P("mul32 double formula vs exact integer product mod 2^32:", n, "pairs,", bad, "mismatches")
bad = 0
for _ in range(20000):
    z = rnd.getrandbits(32); bad += int(fmix_f(float(z))) != fmix_i(z)
P("fmix32 double vs integer: 20000 values,", bad, "mismatches")
bad = 0
for k in range(2000):
    seed = rnd.getrandbits(32); tag = rnd.choice(["", "HoldZone.Target", "TimingStrike.Tempo", "TimingStrike.Offsets", "PrecisionTrace.Perturb", "T-RNG-05/%d" % k])
    rf, ri = RngF(seed, tag), RngI(seed, tag)
    for _ in range(50):
        bad += int(rf.u32()) != ri.u32()
P("Rng.new + 50 nextU32, double formulas vs integer:", 2000, "streams,", bad, "mismatches")

# (2) the plan's T-RNG-01 vectors
def check(name, got, exp):
    ok = got == exp
    P(("OK  " if ok else "BAD ") + name, "" if ok else ("got %r expected %r" % (got, exp)))
    return ok
allok = True
for s, h in (("", 0x811C9DC5), ("a", 0xE40C292C), ("foobar", 0xBF9CF968), ("TimingStrike.Offsets", 0xBDE3CD3F),
             ("HoldZone.Target", 0x364C5DC9), ("TimingStrike.Tempo", 0x6AE6E414), ("PrecisionTrace.Perturb", 0xCE7A16CE)):
    allok &= check("fnv1a32 %r" % s, int(fnv_f(s)), h)
for a, b, r in ((0xFFFFFFFF, 0xFFFFFFFF, 1), (0x80000000, 2, 0), (0x01000193, 0x811C9DC5, 84696351), (123456789, 987654321, 4227814277), (0, 0xFFFFFFFF, 0)):
    allok &= check("mul32(%#x,%#x)" % (a, b), int(mul32_f(float(a), float(b))), r)
def hashU32_f(h, v):
    for _ in range(4):
        h = mul32_f(bxor(h, band(v, 0xFF)), 16777619.0); v = rshift(v, 8)
    return h
allok &= check("hashU32(basis,0)", int(hashU32_f(2166136261.0, 0.0)), 0x4B95F515)
allok &= check("hashU32(basis,0xDEADBEEF)", int(hashU32_f(2166136261.0, float(0xDEADBEEF))), 0x90879FCB)
r = RngF.from_state(1, 2, 3, 4)
allok &= check("raw (1,2,3,4) x10", [int(r.u32()) for _ in range(10)], [11520, 0, 5927040, 70819200, 2031721883, 1637235492, 1287239034, 3734860849, 3729100597, 4258142804])
vec = [
  (1, "", [0x283F5546, 0xD3E69993, 0xE0DFBA52, 0xF9D93A6F], [3296685081, 292216795, 3203276040, 3343330025, 3022133357, 443753119], [0.7009810614399612, 0.34134213626384735]),
  (3735928559, "", [0x8D72B72A, 0x53A3D0FD, 0xD068308F, 0x22AE1FC7], [3856547673, 1244478788, 63559405, 3329023417, 1418849053, 466841299], [0.8987551447935402, 0.7545752725563943]),
  (1, "TimingStrike.Offsets", [0xC4A92F6A, 0xFC1C82C9, 0x630FE6FF, 0xA1A56D9E], [2172563110, 3751778701, 3705501078, 924797711, 2910597952, 64598121], [0.44087175047025084, 0.931851631263271]),
  (3735928559, "TimingStrike.Offsets", [0x20BDFADC, 0x84BE86B5, 0x7D60DDAC, 0x97CC1BD1], [3201755939, 1102565783, 4063799498, 528979833, 2160534696, 2194535758], [0.6990435346961021, 0.9730237319599837]),
]
for seed, tag, st, u, fl in vec:
    r = RngF(seed, tag)
    allok &= check("state %d %r" % (seed, tag), [int(x) for x in r.s], st)
    allok &= check("u32x6 %d %r" % (seed, tag), [int(r.u32()) for _ in range(6)], u)
    allok &= check("floats %d %r" % (seed, tag), [r.f(), r.f()], fl)
for seed, st, u in ((0, [0x09CEF78C, 0x79661DE2, 0xEA0EB7EE, 0xE8B2C241], [2040553127, 2671230994, 3535833209, 446703493]),
                    (4294967295, [0xE7469B4A, 0x67ECDB64, 0x47A974D7, 0xAAEBFA63], [1363692059, 3358058105, 1851661954, 1516388948])):
    r = RngF(seed, "")
    allok &= check("state %d ''" % seed, [int(x) for x in r.s], st)
    allok &= check("u32x4 %d ''" % seed, [int(r.u32()) for _ in range(4)], u)
P("ALL T-RNG-01 vectors of the plan reproduced from the plan's own text:", allok)

# (3) fixed-seed outcomes of the planned chi-square cases
CRIT = 37.70
TAGS = ["", "HoldZone.Target", "TimingStrike.Tempo", "TimingStrike.Offsets", "PrecisionTrace.Perturb"]
GAME = TAGS[1:]
def chi2(counts, n):
    e = n / len(counts); return sum((c - e) ** 2 / e for c in counts)
def draws(seed, tag, n):
    r = RngI(seed, tag); return [r.u32() for _ in range(n)]
N = 160000
P("\nT-RNG-04: top 4 bits, n = %d, crit %.2f" % (N, CRIT))
worst = (0, None)
fails = []
for seed in (1, 2, 3, 0xC0FFEE):
    for tag in TAGS:
        xs = draws(seed, tag, N)
        c = [0] * 16
        for x in xs: c[x >> 28] += 1
        v = chi2(c, N)
        if v > worst[0]: worst = (v, (seed, tag))
        if v >= CRIT: fails.append((seed, tag, v))
P("  20 streams: max chi2 %.2f at %r; failures: %r" % (worst[0], worst[1], fails))
for tag in TAGS:
    r = RngI(1, tag); c = [0] * 16
    for _ in range(N):
        u = r.u32() / F32
        c[1 + math.floor(u * 16) - 1] += 1
    P("  int(1,16) seed 1 tag %-24r chi2 %.2f" % (tag, chi2(c, N)))
for seed, tag in ((1, ""), (2, ""), (1, "HoldZone.Target")):
    xs = draws(seed, tag, 16000); c = [0] * 16
    for x in xs: c[x >> 28] += 1
    P("  fast n=16000 (%d, %r) chi2 %.2f" % (seed, tag, chi2(c, 16000)))

P("\nT-RNG-05: 1000 derived tags + 4 game tags")
tags5 = ["T-RNG-05/%d" % i for i in range(1, 1001)] + GAME
hs = [fnv_i(t) for t in tags5]
P("  distinct fnv1a32:", len(set(hs)), "of", len(hs))
for seed in (0, 1, 0xFFFFFFFF):
    sts = set(); firsts = set()
    for t in tags5:
        r = RngI(seed, t); sts.add((r.s0, r.s1, r.s2, r.s3)); firsts.add(r.u32())
    P("  seed %#x: distinct states %d, distinct first outputs %d" % (seed, len(sts), len(firsts)))

P("\nT-RNG-06: 2-D chi2 on 4x4 (top 2 bits of paired draws), n = %d" % N)
def chi2_pairs(xa, xb):
    c = [0] * 16
    for a, b in zip(xa, xb): c[(a >> 30) * 4 + (b >> 30)] += 1
    return chi2(c, len(xa))
res6 = []
for seed in (1, 0xDEADBEEF):
    st = {t: draws(seed, t, N) for t in GAME}
    for i in range(4):
        for j in range(i + 1, 4):
            res6.append(("tags %s|%s seed %#x" % (GAME[i], GAME[j], seed), chi2_pairs(st[GAME[i]], st[GAME[j]])))
for s in (1, 1000, 0xFFFFFFFE):
    for t in TAGS:
        res6.append(("seeds %#x,%#x tag %r" % (s, s + 1, t), chi2_pairs(draws(s, t, N), draws(s + 1, t, N))))
for t in TAGS:
    xs = draws(1, t, 2 * N + 1)
    res6.append(("lag-1 NON-overlapping seed 1 tag %r" % t, chi2_pairs(xs[0:2 * N:2], xs[1:2 * N:2])))
    res6.append(("lag-1 OVERLAPPING seed 1 tag %r" % t, chi2_pairs(xs[0:N], xs[1:N + 1])))
mx = max(res6, key=lambda r: r[1])
P("  %d cases; max %.2f (%s); failures: %r" % (len(res6), mx[1], mx[0], [r for r in res6 if r[1] >= CRIT]))
for name, v in res6:
    if v > 25: P("   high: %.2f %s" % (v, name))

# (4) null distribution of the overlapping lag-1 statistic: asymptotic covariance of the 16 standardized pair counts
d = 4; K = d * d
cov = np.zeros((K, K))
p = 1.0 / K
for ab in range(K):
    a, b = divmod(ab, d)
    for cd in range(K):
        c_, d_ = divmod(cd, d)
        v = (p if ab == cd else 0) - p * p                       # same position
        # pair i = (a,b), pair i+1 = (c,d): needs b == c
        v += ((1.0 / d**3) if b == c_ else 0) - p * p
        # pair i+1 = (a,b) after pair i = (c,d): needs d == a
        v += ((1.0 / d**3) if d_ == a else 0) - p * p
        cov[ab, cd] = v / p                                     # standardized by expected n*p, per n
lam = np.sort(np.linalg.eigvalsh(cov))[::-1]
P("\noverlapping lag-1 statistic = sum lambda_k chi2_1, lambda =", np.round(lam, 4).tolist())
rng = np.random.default_rng(1)
sims = (rng.standard_normal((2_000_000, K)) ** 2) @ lam
P("  mean %.3f (chi2_15: 15), P(stat > 37.70) = %.5f (chi2_15: 0.00100)" % (sims.mean(), (sims > CRIT).mean()))
sims15 = rng.chisquare(15, 2_000_000)
P("  check: simulated chi2_15 tail at 37.70 = %.5f" % (sims15 > CRIT).mean())

open(sys.argv[1], "w").write("\n".join(out) + "\n")
