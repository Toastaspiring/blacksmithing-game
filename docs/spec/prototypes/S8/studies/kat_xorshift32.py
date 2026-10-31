# Independent (non-Luau) reference for the Rng known-answer vectors.
# Prototype algorithm: xorshift32 13/17/5, seed 0 replaced by 0x6D2B79F5.
M = 0xFFFFFFFF
def xs32(seed, n):
    x = seed if seed != 0 else 0x6D2B79F5
    out = []
    for _ in range(n):
        x ^= (x << 13) & M
        x ^= x >> 17
        x ^= (x << 5) & M
        out.append(x)
    return out
def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 16777619) & M
    return h
for seed in (0, 1, 42, 0xDEADBEEF, 0xFFFFFFFF):
    print(f"seed {seed:#010x}: " + ", ".join(str(v) for v in xs32(seed, 5)))
print("fnv1a32('')", hex(fnv1a32("")), "fnv1a32('a')", hex(fnv1a32("a")), "fnv1a32('foobar')", hex(fnv1a32("foobar")))
