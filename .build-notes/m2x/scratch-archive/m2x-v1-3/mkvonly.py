# mkvonly.py <tree>: write <tree>/src/shared/Physics/SamplingV.luau, Sampling with Sampling.VERDICT_ONLY returning the verdict
import sys
t = sys.argv[1]
p = t + "/src/shared/Physics/Sampling.luau"
s = open(p, encoding="utf-8", newline="").read()
a = "\tif capped then\n\t\tlocal contact: { { number } } = table.create(N)"
assert s.count(a) == 1
s = s.replace(a, "\tdo\n\t\treturn ({ kept = kept, capped = capped, verdictWork = verdictWork, cleaned = cleaned } :: any)\n\tend\n" + a)
s = s.replace("--!strict", "--!nocheck", 1)
open(t + "/src/shared/Physics/SamplingV.luau", "w", encoding="utf-8", newline="").write(s)
print("ok", t)
