# p_witness.py <tree>: fix3/witness.diff ported to the final Cover: a round facet's buried piece on the moved half-spaces
# too wherever a vertex of it lies in the round hider (deeper than EPS_GEOM)
import sys
f = sys.argv[1] + "/src/shared/Physics/Cover.luau"
s = open(f, encoding="utf-8", newline="").read()
a = """				if pm.round and q.round then
					local hull = pm.hull[f]
					local inside = true
					for j = 1, #hull, 3 do
						local s = Shapes.sd(Q, hull[j], hull[j + 1], hull[j + 2])
						if (if higher[k] then s > EPS else s >= -EPS) then
							inside = false
							break
						end
					end
"""
b = """				local band = not pm.round -- the witness: a flat facet, or a round one with a vertex buried in q
				if pm.round and q.round then
					local hull = pm.hull[f]
					local inside = true
					for j = 1, #hull, 6 do
						local s = Shapes.sd(Q, hull[j], hull[j + 1], hull[j + 2])
						band = band or s < -EPS
						inside = inside and (if higher[k] then s <= EPS else s < -EPS)
					end
					for j = 4, #hull, 6 do
						if not inside then
							break
						end
						local s = Shapes.sd(Q, hull[j], hull[j + 1], hull[j + 2])
						inside = if higher[k] then s <= EPS else s < -EPS
					end
"""
assert s.count(a) == 1
s = s.replace(a, b)
a = "\t\t\t\t\t\tcA[i] = coincident - (if pm.round then qsag[i] else 0)\n"
assert s.count(a) == 1
s = s.replace(a, "\t\t\t\t\t\tcA[i] = coincident - (if band then 0 else qsag[i])\n")
open(f, "w", encoding="utf-8", newline="").write(s)
print("witness ok")
