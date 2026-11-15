# p_minors.py <tree>: on the base, the round's minors alone: fixW2 (Sampling.ranked) and fixD (Cover.farthest)
import sys
f = sys.argv[1] + "/src/shared/Physics/Sampling.luau"
s = open(f, encoding="utf-8", newline="").read()
a = "\t\t\tv = 4 * p.hx * min(p.hy, p.hz) * max(p.hy, p.hz)\n"
assert s.count(a) == 1
s = s.replace(a, "\t\t\th2, h3 = min(p.hy, p.hz), max(p.hy, p.hz)\n\t\t\tv = 4 * p.hx * h2 * h3\n")
open(f, "w", encoding="utf-8", newline="").write(s)
f = sys.argv[1] + "/src/shared/Physics/Cover.luau"
s = open(f, encoding="utf-8", newline="").read()
a = "\t\treturn Shapes.maxDist(P, Q.cx, Q.cy, Q.cz) - Q.r\n"
assert s.count(a) == 1
b = """\t\tlocal best = 0
\t\tfor s = -1, 1, 2 do
\t\t\tlocal dx, dy, dz = P.cx + s * P.hx * P.ux - Q.cx, P.cy + s * P.hx * P.uy - Q.cy, P.cz + s * P.hx * P.uz - Q.cz
\t\t\tlocal a = dx * P.ux + dy * P.uy + dz * P.uz
\t\t\tlocal px, py, pz = dx - a * P.ux, dy - a * P.uy, dz - a * P.uz
\t\t\tlocal perp = sqrt(px * px + py * py + pz * pz) + P.r
\t\t\tbest = max(best, a * a + perp * perp)
\t\tend
\t\treturn sqrt(best) - Q.r
"""
s = s.replace(a, b)
open(f, "w", encoding="utf-8", newline="").write(s)
print("minors ok")
