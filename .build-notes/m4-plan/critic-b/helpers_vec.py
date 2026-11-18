# Extra T-RNG-01 vectors for the helpers (range/int/chance/sign), from the integer reference, printed %.17g.
import math, sys
sys.argv = [sys.argv[0], "/dev/null"]
M = 0xFFFFFFFF
def fnv(s):
    h = 0x811C9DC5
    for ch in s.encode(): h = ((h ^ ch) * 0x01000193) & M
    return h
def fmix(z):
    z ^= z >> 16; z = (z * 0x85EBCA6B) & M; z ^= z >> 13; z = (z * 0xC2B2AE35) & M; z ^= z >> 16; return z
class R:
    def __init__(s, seed, tag=""):
        x = seed ^ fnv(tag); st = []
        for _ in range(4):
            x = (x + 0x9E3779B9) & M; st.append(fmix(x))
        s.s = st
    def u32(s):
        s0, s1, s2, s3 = s.s
        x = (s1 * 5) & M; r = ((((x << 7) | (x >> 25)) & M) * 9) & M; t = (s1 << 9) & M
        s2 ^= s0; s3 ^= s1; s1 ^= s2; s0 ^= s3; s2 ^= t; s3 = ((s3 << 11) | (s3 >> 21)) & M
        s.s = [s0, s1, s2, s3]; return r
    def f(s): return s.u32() / 4294967296.0
    def range(s, lo, hi): return lo + (hi - lo) * s.f()
    def int(s, lo, hi): return lo + math.floor(s.f() * (hi - lo + 1))
    def chance(s, p): return s.f() < p
    def sign(s): return -1 if s.f() < 0.5 else 1
r = R(1, "HoldZone.Target")
print("Rng.new(1, 'HoldZone.Target'): range(0.3,0.7) %.17g; int(900,2200) %d; chance(0.25) %s; range(0.5,1.0) %.17g; sign() %d; int(1,16) %d"
      % (r.range(0.3, 0.7), r.int(900, 2200), r.chance(0.25), r.range(0.5, 1.0), r.sign(), r.int(1, 16)))
