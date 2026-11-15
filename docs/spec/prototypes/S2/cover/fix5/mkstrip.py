"""m2x-fix-5: strip/ = a copy of hook/ (the build + Cover._lies) where a flat facet whose plane is parallel to a Cylinder
hider's axis (|n·u| ≤ 1e-9) reads the true side's cut by that plane, a strip, instead of the prism's moved half-spaces:
4 lines, across the axis within sqrt(R² − h²) of its foot (h the axis's distance from the plane, the probe's δ + its sag
further), along it within hx of the centre, R and hx grown by EPS_GEOM if the hider ranks higher, else shrunk (the
probe's grown). A trial for §17.1 O9 (b), not adopted (`%` and all: outside §4.1).
   python mkstrip.py"""
import os, shutil
W = os.path.dirname(os.path.abspath(__file__))
src, dst = os.path.join(W, "hook"), os.path.join(W, "strip")
if os.path.exists(dst):
    shutil.rmtree(dst)
shutil.copytree(src, dst)
p = os.path.join(dst, "src/shared/Physics/Cover.luau")
s = open(p, encoding="utf-8", newline="").read()
def sub(a, b):
    global s
    assert s.count(a) == 1, a[:80]
    s = s.replace(a, b)
sub("""				local circle = flat and Q.code == BALL
				local lines = if circle then 32 else np
				local ue, ug, ve, vg, cu, cv, rhoA, rhoB = 0, 0, 0, 0, 0, 0, 0, 0""",
"""				local circle = flat and Q.code == BALL
				local strip = flat and Q.code == CYLINDER and abs(nx * Q.ux + ny * Q.uy + nz * Q.uz) <= 1e-9
				local lines = if circle then 32 elseif strip then 4 else np
				local ue, ug, ve, vg, cu, cv, rhoA, rhoB = 0, 0, 0, 0, 0, 0, 0, 0
				local hA, hB = 0, 0
				if strip then
					local ax, ay, az = ny * Q.uz - nz * Q.uy, nz * Q.ux - nx * Q.uz, nx * Q.uy - ny * Q.ux
					local al = sqrt(ax * ax + ay * ay + az * az)
					ax, ay, az = ax / al, ay / al, az / al
					ue, ug = ax * ex + ay * ey + az * ez, ax * gx + ay * gy + az * gz
					ve, vg = Q.ux * ex + Q.uy * ey + Q.uz * ez, Q.ux * gx + Q.uy * gy + Q.uz * gz
					local dx, dy, dz = Q.cx - ox, Q.cy - oy, Q.cz - oz
					cu, cv = dx * ex + dy * ey + dz * ez, dx * gx + dy * gy + dz * gz
					local h = dx * nx + dy * ny + dz * nz
					local RA, RB = Q.r + coincident, Q.r + EPS
					rhoA = if h * h < RA * RA then sqrt(RA * RA - h * h) else -math.huge
					rhoB = if (probe - h) * (probe - h) < RB * RB then sqrt(RB * RB - (probe - h) * (probe - h)) else -math.huge
					hA, hB = Q.hx + coincident, Q.hx + EPS
				end""")
sub("""				for i = 1, lines do
					local a, b, base
					if circle then""",
"""				for i = 1, lines do
					local a, b, base
					if strip then
						local sgn = if i % 2 == 1 then 1 else -1
						if i <= 2 then
							a, b = sgn * ue, sgn * ug
							cA[i], cB[i] = rhoA, rhoB
						else
							a, b = sgn * ve, sgn * vg
							cA[i], cB[i] = if rhoA > -math.huge then hA else -math.huge, if rhoB > -math.huge then hB else -math.huge
						end
						base = a * cu + b * cv
					elseif circle then""")
s = s.replace("--!strict", "--!nocheck", 1)
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok", dst)
