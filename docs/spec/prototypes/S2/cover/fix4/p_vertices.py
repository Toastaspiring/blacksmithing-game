# p_vertices.py <tree>: fix3/vertices.diff ported to the final Cover: a round facet hidden whole when its vertices alone lie
# in a round hider's true solid
import sys
f = sys.argv[1] + "/src/shared/Physics/Cover.luau"
s = open(f, encoding="utf-8", newline="").read()
a = """					for j = 1, #hull, 3 do
						local s = Shapes.sd(Q, hull[j], hull[j + 1], hull[j + 2])
						if (if higher[k] then s > EPS else s >= -EPS) then
							inside = false
							break
						end
					end
					pending += UNITS_PER_TEST * #hull / 3
"""
b = """					for j = 1, #hull, 6 do
						local s = Shapes.sd(Q, hull[j], hull[j + 1], hull[j + 2])
						inside = inside and (if higher[k] then s <= EPS else s < -EPS)
					end
					pending += UNITS_PER_TEST * #hull / 6
"""
assert s.count(a) == 1
s = s.replace(a, b)
open(f, "w", encoding="utf-8", newline="").write(s)
print("vertices ok")
