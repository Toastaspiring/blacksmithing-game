# Throwaway: extra PRNG vectors from the independent reference (same algorithm as prototypes/S3/rng_ref.py)
import importlib.util, sys
spec = importlib.util.spec_from_file_location("r", sys.argv[1]); r = importlib.util.module_from_spec(spec)
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()): spec.loader.exec_module(r)
M = 0xFFFFFFFF
for tag in ("HoldZone.Target", "TimingStrike.Tempo", "TimingStrike.Offsets", "PrecisionTrace.Perturb"):
    print("FNV", repr(tag), hex(r.fnv1a32(tag)))
for a, b in ((0xFFFFFFFF, 0xFFFFFFFF), (0x80000000, 2), (0x01000193, 0x811C9DC5), (123456789, 987654321), (0, 0xFFFFFFFF)):
    print("mul32", hex(a), hex(b), "=", (a * b) & M)
for seed in (0, 4294967295):
    g = r.new(seed, ""); st = [hex(v) for v in g.s]; u = [g.next() for _ in range(4)]
    print("seed", seed, "tag '' state", st, "u32x4", u)
# hashU32 over one word, from the basis: FNV-1a over 4 LE bytes
def hashU32(h, v):
    for _ in range(4):
        h = ((h ^ (v & 0xFF)) * 0x01000193) & M; v >>= 8
    return h
print("hashU32(basis, 0) =", hex(hashU32(0x811C9DC5, 0)), " hashU32(basis, 0xDEADBEEF) =", hex(hashU32(0x811C9DC5, 0xDEADBEEF)))
