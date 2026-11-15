"""m2x-fix-5 variant trees beside the repo (src, tests, docs copied; SamplingV.luau made as fix3/mkV.py does):
   python mkvar.py hook    the build with `Cover._lies = lies` (its rule A, for the decision bit-compare)
   python mkvar.py exact   the build with rule A always exact: both caps searched (rimFarthest), no bounds; `_lies` too
   python mkvar.py v1a     the build with V1's fixA rule A (its rimFarthest verbatim: the whole offset, cutoff 1e-6),
                           both caps searched, UNITS_PER_TEST a test as V1 tried it; `_lies` too
"""
import os, shutil, sys

REPO = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
W = os.path.dirname(os.path.abspath(__file__))
name = sys.argv[1]
dst = os.path.join(W, name)
if os.path.exists(dst):
    shutil.rmtree(dst)
for d in ("src", "tests", "docs"):
    shutil.copytree(os.path.join(REPO, d), os.path.join(dst, d))
shutil.copy(os.path.join(REPO, "aftman.toml"), dst)
p = os.path.join(dst, "src/shared/Physics/Cover.luau")
s = open(p, encoding="utf-8", newline="").read()


def sub(a, b):
    global s
    assert s.count(a) == 1, a[:80]
    s = s.replace(a, b)


sub("return table.freeze(Cover)", "Cover._lies = lies\nreturn table.freeze(Cover)")
if name in ("exact", "v1a"):
    a = s.index("\tlocal ax, ay, az, a = capBounds(P, Q, -1, higher)")
    b = s.index("\treturn b ~= 0 or held(", a)
    b = s.index("\n", b) + 1
    if name == "exact":
        body = """\tlocal across = 0
\tfor s = -1, 1, 2 do
\t\tlocal mx, my, mz = P.cx + s * P.hx * P.ux - Q.cx, P.cy + s * P.hx * P.uy - Q.cy, P.cz + s * P.hx * P.uz - Q.cz
\t\tlocal t = mx * ux + my * uy + mz * uz
\t\tmx, my, mz = mx - t * ux, my - t * uy, mz - t * uz
\t\tacross = max(across, rimFarthest(mx, my, mz, P.r, P.ux, P.uy, P.uz, ux, uy, uz))
\tend
\treturn held(across - Q.r, higher), UNITS_PER_TEST + 2 * UNITS_PER_RIM
"""
    else:
        body = """\tlocal across = 0
\tfor s = -1, 1, 2 do
\t\tacross = max(across, v1Farthest(dx + s * P.hx * P.ux, dy + s * P.hx * P.uy, dz + s * P.hx * P.uz, P.r, P.ux, P.uy,
\t\t\tP.uz, Q))
\tend
\treturn held(across - Q.r, higher), UNITS_PER_TEST
"""
        sub("local function lies(", """local function v1Farthest(dx: number, dy: number, dz: number, r: number, nx: number, ny: number, nz: number,
\tQ: Prepared): number
\tlocal ux, uy, uz = Q.ux, Q.uy, Q.uz
\tlocal du = dx * ux + dy * uy + dz * uz
\tlocal ax, ay, az = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
\tlocal al = sqrt(ax * ax + ay * ay + az * az)
\tif al <= 1e-6 then
\t\tlocal px, py, pz = dx - du * ux, dy - du * uy, dz - du * uz
\t\treturn sqrt(px * px + py * py + pz * pz) + r
\tend
\tax, ay, az = ax / al, ay / al, az / al
\tlocal ex, ey, ez = ny * az - nz * ay, nz * ax - nx * az, nx * ay - ny * ax
\tlocal eu = ex * ux + ey * uy + ez * uz
\tlocal K = dx * dx + dy * dy + dz * dz + r * r - du * du
\tlocal A = 2 * r * abs(dx * ax + dy * ay + dz * az)
\tlocal B = 2 * r * (dx * ex + dy * ey + dz * ez - du * eu)
\tlocal C = r * r * eu * eu
\tlocal lo, hi = -1, 1
\tfor _ = 1, 60 do
\t\tlocal s = (lo + hi) / 2
\t\tif (B - 2 * C * s) * sqrt(max(0, 1 - s * s)) - A * s > 0 then
\t\t\tlo = s
\t\telse
\t\t\thi = s
\t\tend
\tend
\tlocal s = (lo + hi) / 2
\treturn sqrt(max(0, K + A * sqrt(max(0, 1 - s * s)) + B * s - C * s * s))
end

local function lies(""")
        a = s.index("\tlocal ax, ay, az, a = capBounds(P, Q, -1, higher)")
        b = s.index("\treturn b ~= 0 or held(", a)
        b = s.index("\n", b) + 1
    s = s[:a] + body + s[b:]
open(p, "w", encoding="utf-8", newline="").write(s)
# SamplingV: Sampling returning right after the verdict (fix3/mkV.py)
q = os.path.join(dst, "src/shared/Physics/Sampling.luau")
t = open(q, encoding="utf-8", newline="").read()
a = """\t-- the measure: the kept parts, against kept parts only, on a ladder"""
assert t.count(a) == 1
t = t.replace(a, """\tdo
\t\treturn { capped = false, verdictWork = verdictWork, kept = kept, cleaned = cleaned } :: any
\tend
""" + a).replace("--!strict", "--!nocheck", 1)
open(os.path.join(dst, "src/shared/Physics/SamplingV.luau"), "w", encoding="utf-8", newline="").write(t)
print("ok", dst)
