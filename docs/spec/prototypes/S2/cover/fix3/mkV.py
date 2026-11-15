# mkV.py <tree>: <tree>/src/shared/Physics/SamplingV.luau = Sampling, returning right after the verdict (the timing's cut)
import sys
p = sys.argv[1] + "/src/shared/Physics/Sampling.luau"
s = open(p, encoding="utf-8", newline="").read()
a = """	-- the measure: the kept parts, against kept parts only, on a ladder"""
assert s.count(a) == 1
s = s.replace(a, """	do
		return { capped = false, verdictWork = verdictWork, kept = kept, cleaned = cleaned } :: any
	end
""" + a)
s = s.replace("--!strict", "--!nocheck", 1)
open(sys.argv[1] + "/src/shared/Physics/SamplingV.luau", "w", encoding="utf-8", newline="").write(s)
print("ok", sys.argv[1])
