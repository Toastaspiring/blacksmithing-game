"""m2x-fix-6: stat/ = a copy of tree/ (the build with this round's Cover.spec) whose Cover logs rule A's tests (each cap's
state from its bounds, and for a test with both caps open whether their searches agree) and the reading's reports, and
whose Cover.spec prints them: per size and {turn, lean} of the tilted cases, rule A's tests, the caps left open, the tests
with both open and those whose two searches disagree, for the readings and for the centred ones moved 2e-8 (V2's check);
for the run of searched cap rims, each test's caps and units and every report (where one past 300 came from).
   python mkstat.py && cd stat && lune run tests/run -- --filter "tilted rods" ; lune run tests/run -- --filter "a run of searched cap rims"
"""
import os, shutil

W = os.path.dirname(os.path.abspath(__file__))
src, dst = os.path.join(W, "tree"), os.path.join(W, "stat")
if os.path.exists(dst):
    shutil.rmtree(dst)
shutil.copytree(src, dst)


def patch(path, pairs):
    p = os.path.join(dst, path)
    s = open(p, encoding="utf-8", newline="").read()
    for a, b in pairs:
        assert s.count(a) == 1, (path, a[:60])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="").write(s)


patch("src/shared/Physics/Cover.luau", [
    ("local Cover = {}\n",
     "local Cover = {}\nCover.LOG = { open = 0, both = 0, split = 0, tests = 0, reports = {}, lies = {} } -- mkstat\nlocal LOG = Cover.LOG\n"),
    ("\tlocal ux, uy, uz = Q.ux, Q.uy, Q.uz\n\tlocal dx, dy, dz = P.cx - Q.cx, P.cy - Q.cy, P.cz - Q.cz\n",
     "\tLOG.tests += 1\n\tlocal ux, uy, uz = Q.ux, Q.uy, Q.uz\n\tlocal dx, dy, dz = P.cx - Q.cx, P.cy - Q.cy, P.cz - Q.cz\n"),
    ("\tlocal units = UNITS_PER_TEST + (if a == 0 then UNITS_PER_RIM else 0) + (if b == 0 then UNITS_PER_RIM else 0)\n",
     "\tlocal units = UNITS_PER_TEST + (if a == 0 then UNITS_PER_RIM else 0) + (if b == 0 then UNITS_PER_RIM else 0)\n"
     "\ttable.insert(LOG.lies, string.format(\"caps %d %d, units %g\", a, b, units))\n"
     "\tLOG.open += (if a == 0 then 1 else 0) + (if b == 0 then 1 else 0)\n"
     "\tif a == 0 and b == 0 then\n"
     "\t\tLOG.both += 1\n"
     "\t\tlocal ha = held(rimFarthest(ax, ay, az, P.r, P.ux, P.uy, P.uz, ux, uy, uz) - Q.r, higher)\n"
     "\t\tlocal hb = held(rimFarthest(bx, by, bz, P.r, P.ux, P.uy, P.uz, ux, uy, uz) - Q.r, higher)\n"
     "\t\tif ha ~= hb then\n\t\t\tLOG.split += 1\n\t\tend\n"
     "\tend\n"),
    ("\tlocal function settle()\n\t\tif pending > 0 then\n",
     "\tlocal function settle()\n"
     "\t\tif LOG.trace and pending > 300 then\n\t\t\tprint(debug.traceback(\"a report of \" .. pending))\n\t\tend\n"
     "\t\tif pending > 0 then\n\t\t\ttable.insert(LOG.reports, pending)\n"),
])

patch("tests/Physics/Cover.spec.luau", [
    ("\t\t\t\tlocal nx, _, _, ny, _, _, nz = Quat.toMatrix(q0) -- its axis: the matrix's first column\n",
     "\t\t\t\tlocal nx, _, _, ny, _, _, nz = Quat.toMatrix(q0) -- its axis: the matrix's first column\n"
     "\t\t\t\tlocal L = (Cover :: any).LOG\n"
     "\t\t\t\tlocal st = { 0, 0, 0, 0, 0, 0, 0, 0 }\n"
     "\t\t\t\tlocal function count(k: number, t0: { number })\n"
     "\t\t\t\t\tst[k] += L.tests - t0[1]\n\t\t\t\t\tst[k + 1] += L.open - t0[2]\n"
     "\t\t\t\t\tst[k + 2] += L.both - t0[3]\n\t\t\t\t\tst[k + 3] += L.split - t0[4]\n"
     "\t\t\t\tend\n"),
    ("\t\t\t\t\t\tif v == 1 then\n\t\t\t\t\t\t\tlocal a, b = Cover.model(place(y0, 2e-8, q0)), Cover.model(place(y0, 2e-8, q))\n",
     "\t\t\t\t\t\tlocal t0 = { L.tests, L.open, L.both, L.split }\n"
     "\t\t\t\t\t\tif v == 1 then\n\t\t\t\t\t\t\tlocal a, b = Cover.model(place(y0, 2e-8, q0)), Cover.model(place(y0, 2e-8, q))\n"),
    ("\t\t\t\t\t\tfor _, higher in ipairs({ true, false }) do\n\t\t\t\t\t\t\tlocal limit = if higher then eps else -eps\n",
     "\t\t\t\t\t\tcount(5, t0)\n\t\t\t\t\t\tt0 = { L.tests, L.open, L.both, L.split }\n"
     "\t\t\t\t\t\tfor _, higher in ipairs({ true, false }) do\n\t\t\t\t\t\t\tlocal limit = if higher then eps else -eps\n"),
    ("\t\t\t\t\t\t\t\tsearched += (used - 0.5) / 28\n\t\t\t\t\t\t\tend\n\t\t\t\t\t\tend\n",
     "\t\t\t\t\t\t\t\tsearched += (used - 0.5) / 28\n\t\t\t\t\t\t\tend\n\t\t\t\t\t\tend\n\t\t\t\t\t\tcount(1, t0)\n"),
    ("\t\t\t\t\tend\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\t\treturn checked, held, searched, units\n",
     "\t\t\t\t\tend\n\t\t\t\tend\n"
     "\t\t\t\tprint(string.format(\"r %.2f turn %g lean %g: readings %d tests, %d caps open, %d both open, %d split | \"\n"
     "\t\t\t\t\t.. \"moved %d tests, %d open, %d both, %d split\", r, turn, lean, table.unpack(st)))\n"
     "\t\t\tend\n\t\tend\n"
     "\t\tprint(string.format(\"T (%g, %g, %g, %g): checked %d, held %d, caps searched %d, units %g\", T[1], T[2], T[3], T[4], checked, held, searched, units))\n"
     "\t\treturn checked, held, searched, units\n"),
    ("\t\tlocal most, total = 0, 0\n\t\tlocal shown, used = Cover.shown(m[21], hm, higher, math.huge, math.huge, function(n: number)\n",
     "\t\tlocal L = (Cover :: any).LOG\n\t\tL.reports, L.lies, L.trace = {}, {}, true\n"
     "\t\tlocal most, total = 0, 0\n\t\tlocal shown, used = Cover.shown(m[21], hm, higher, math.huge, math.huge, function(n: number)\n"),
    ("\t\tA.truthy(shown > 0, \"the puck stands out of every disk: it reads \" .. shown)\n",
     "\t\tprint(\"rule A's tests: \" .. #L.lies .. \": \" .. table.concat(L.lies, \"; \"))\n"
     "\t\tprint(\"reports: \" .. #L.reports .. \", the largest \" .. most .. \": \" .. table.concat(L.reports, \" \"))\n"
     "\t\tprint(\"reads \" .. shown .. \" of \" .. m[21].total .. \" for \" .. used .. \" units\")\n"
     "\t\tA.truthy(shown > 0, \"the puck stands out of every disk: it reads \" .. shown)\n"),
])
print("stat/ written")
