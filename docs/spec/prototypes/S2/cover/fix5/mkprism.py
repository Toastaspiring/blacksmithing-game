"""m2x-fix-5: a copy of the hook tree (the build + Cover._lies) whose Cylinder model is the prism over the inscribed
NS-gon instead of the 32-gon (§17.1 O9's finer prism), its directions from math.cos and math.sin (an experiment, outside
§4.1), OVER_CYLINDER sec(π/NS) − 1 + 4e-4, the side facets 1…NS, the caps NS + 1, NS + 2. A Ball's model and a flat
facet's 32-gon against a Ball keep their own 32 directions (COS, SIN), as does Sampling.
   python mkprism.py <NS>      -> prism<NS>/
"""
import math, os, shutil, sys

W = os.path.dirname(os.path.abspath(__file__))
NS = int(sys.argv[1])
src = os.path.join(W, "hook")
dst = os.path.join(W, "prism%d" % NS)
if os.path.exists(dst):
    shutil.rmtree(dst)
shutil.copytree(src, dst)
p = os.path.join(dst, "src/shared/Physics/Cover.luau")
s = open(p, encoding="utf-8", newline="").read()


def sub(a, b, n=1):
    global s
    assert s.count(a) == n, (a, s.count(a))
    s = s.replace(a, b)


sub("local OVER_BALL, OVER_CYLINDER = 0.03, 0.005",
    "local OVER_BALL, OVER_CYLINDER = 0.03, %r\nlocal NS = %d\nlocal COSN, SINN = {}, {}\nfor k = 1, NS do\n\tCOSN[k], SINN[k] = math.cos(2 * math.pi * (k - 1) / NS), math.sin(2 * math.pi * (k - 1) / NS)\nend"
    % (1 / math.cos(math.pi / NS) - 1 + 4e-4, NS))
sub("""		for k = 1, 32 do
			local k1 = if k == 32 then 1 else k + 1
			local y0, z0, y1, z1 = r * COS[k], r * SIN[k], r * COS[k1], r * SIN[k1]""",
    """		for k = 1, NS do
			local k1 = if k == NS then 1 else k + 1
			local y0, z0, y1, z1 = r * COSN[k], r * SINN[k], r * COSN[k1], r * SINN[k1]""")
sub("""		local plus: { number } = table.create(96, 0)
		local minus: { number } = table.create(96, 0)
		for k = 1, 32 do
			plus[3 * k - 2], plus[3 * k - 1], plus[3 * k] = hx, r * COS[k], r * SIN[k]
			local s = 33 - k
			minus[3 * k - 2], minus[3 * k - 1], minus[3 * k] = -hx, r * COS[s], r * SIN[s]
		end""",
    """		local plus: { number } = table.create(3 * NS, 0)
		local minus: { number } = table.create(3 * NS, 0)
		for k = 1, NS do
			plus[3 * k - 2], plus[3 * k - 1], plus[3 * k] = hx, r * COSN[k], r * SINN[k]
			local s = NS + 1 - k
			minus[3 * k - 2], minus[3 * k - 1], minus[3 * k] = -hx, r * COSN[s], r * SINN[s]
		end""")
sub("if code == BALL or (code == CYLINDER and i <= 32) then", "if code == BALL or (code == CYLINDER and i <= NS) then")
sub("local scale = P.r / (if code == CYLINDER and i > 32 then apothem else own)", "local scale = P.r / (if code == CYLINDER and i > NS then apothem else own)")
s = s.replace("--!strict", "--!nocheck", 1)
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok", dst)
