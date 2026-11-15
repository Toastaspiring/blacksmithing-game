import sys
p = sys.argv[1]; s = open(p, encoding="utf-8", newline="").read()
a = "\t\t\t\t\t\tband = band or s < -EPS\n"
assert s.count(a) == 1
s = s.replace(a, "")
b = """					for j = 4, #hull, 6 do
						if not inside then
							break
						end
						local s = Shapes.sd(Q, hull[j], hull[j + 1], hull[j + 2])
						inside = if higher[k] then s <= EPS else s < -EPS
					end
					pending += UNITS_PER_TEST * #hull / 3"""
assert s.count(b) == 1
s = s.replace(b, "					pending += UNITS_PER_TEST * #hull / 6")
open(p, "w", encoding="utf-8", newline="").write(s)
