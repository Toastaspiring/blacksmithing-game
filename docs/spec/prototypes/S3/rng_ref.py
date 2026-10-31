# Independent reference (Python big ints) for the S3 Rng: FNV-1a32, SplitMix32 (Weyl + fmix32), xoshiro128** 1.1
M = 0xFFFFFFFF

def fnv1a32(s: str) -> int:
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & M
    return h

def fmix32(z: int) -> int:
    z = ((z ^ (z >> 16)) * 0x85EBCA6B) & M
    z = ((z ^ (z >> 13)) * 0xC2B2AE35) & M
    return z ^ (z >> 16)

def rotl(x, k):
    return ((x << k) | (x >> (32 - k))) & M

class Xo:
    def __init__(self, s):
        self.s = list(s)
    def next(self):
        s = self.s
        result = (rotl((s[1] * 5) & M, 7) * 9) & M
        t = (s[1] << 9) & M
        s[2] ^= s[0]
        s[3] ^= s[1]
        s[1] ^= s[2]
        s[0] ^= s[3]
        s[2] ^= t
        s[3] = rotl(s[3], 11)
        return result

def new(seed, tag=""):
    x = seed ^ fnv1a32(tag)
    st = []
    for _ in range(4):
        x = (x + 0x9E3779B9) & M
        st.append(fmix32(x))
    return Xo(st)

print("FNV('')", hex(fnv1a32("")), "FNV('a')", hex(fnv1a32("a")), "FNV('foobar')", hex(fnv1a32("foobar")),
      "FNV('TimingStrike.Offsets')", hex(fnv1a32("TimingStrike.Offsets")))
r = Xo([1, 2, 3, 4])
print("state(1,2,3,4):", [r.next() for _ in range(10)])
for seed in (1, 3735928559):
    for tag in ("", "TimingStrike.Offsets"):
        g = new(seed, tag)
        st = [hex(v) for v in g.s]
        u = [g.next() for _ in range(6)]
        f = [repr(g.next() / 2**32) for _ in range(2)]
        print(f"seed={seed} tag={tag!r} state={st}\n   u32={u}\n   floats={f}")
