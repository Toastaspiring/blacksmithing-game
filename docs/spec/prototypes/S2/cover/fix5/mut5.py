"""m2x-fix-5: the round's tests against the tree before and against mutants of the build.
   python mut5.py base      the tree before's src with this round's tests: the new cases, each expected to fail or pass
   python mut5.py mutants   V1's three surviving mutants of round 4's lines and hand mutants of this round's rule A, each
                            on a copy of the build: the Physics quick cases that should kill it
Trees are made under ./mt/<name> (src, tests, docs, aftman.toml), run from their root, at most 3 at a time."""
import os, re, shutil, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

W = os.path.dirname(os.path.abspath(__file__))
REPO = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
BASE = W + "/base"
MT = W + "/mt"


def tree(name, src_from):
    d = os.path.join(MT, name)
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    shutil.copytree(os.path.join(src_from, "src"), os.path.join(d, "src"))
    for sub in ("tests", "docs"):
        shutil.copytree(os.path.join(REPO, sub), os.path.join(d, sub))
    for f in ("aftman.toml", "default.project.json", "test.project.json"):
        if os.path.exists(os.path.join(REPO, f)):
            shutil.copy(os.path.join(REPO, f), d)
    return d


def run(d, flt):
    p = subprocess.run(["lune", "run", "tests/run", "--", "--quick", "--filter", flt], cwd=d, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    out = p.stdout + p.stderr
    m = re.search(r"RESULT pass=(\d+) fail=(\d+)", out)
    fails = [l.strip() for l in out.splitlines() if l.strip().startswith("FAIL") or l.strip().startswith("ERROR")]
    return (int(m.group(1)), int(m.group(2))) if m else (None, None), fails, out


def mutate(path, a, b):
    s = open(path, encoding="utf-8", newline="").read()
    assert s.count(a) == 1, (path, a[:70], s.count(a))
    open(path, "w", encoding="utf-8", newline="").write(s.replace(a, b))


NEW = [
    ("tilted rods and pucks in a Cylinder", "fail"),
    ("pucks wholly inside a round guard", "fail"),
    ("round parts a hair inside and a hair out", "pass"),
    ("(e) a flat face against a Ball", "pass"),
    ("Sampling.ranked: the larger", "pass"),
]

COVER = "src/shared/Physics/Cover.luau"
SAMPLING = "src/shared/Physics/Sampling.luau"
MUTANTS = [
    ("v1_176 X/Z tie dropped", COVER, "\telseif ax <= az + AXIS_TIE then", "\telseif ax <= az then", "(e) a flat face against a Ball"),
    ("v1_579 fixD reverted", COVER, "\t\treturn held(sqrt(best) - Q.r, higher), UNITS_PER_TEST",
     "\t\treturn held(Shapes.maxDist(P, Q.cx, Q.cy, Q.cz) - Q.r, higher), UNITS_PER_TEST", "round parts a hair inside and a hair out"),
    ("v1_498 Wedge hy, hz out of order", SAMPLING, "h2, h3 = min(p.hy, p.hz), max(p.hy, p.hz)", "h2, h3 = max(p.hy, p.hz), min(p.hy, p.hz)",
     "Sampling.ranked: the larger"),
    ("open caps held, no search", COVER, "\tif a == 0 and not held(rimFarthest(ax, ay, az, P.r, P.ux, P.uy, P.uz, ux, uy, uz) - Q.r, higher) then",
     "\tif false then", "tilted rods and pucks in a Cylinder"),
    ("open caps not held", COVER, "\tlocal units = UNITS_PER_TEST + (if a == 0 then UNITS_PER_RIM else 0) + (if b == 0 then UNITS_PER_RIM else 0)",
     "\tif a == 0 or b == 0 then\n\t\treturn false, UNITS_PER_TEST\n\tend\n\tlocal units = UNITS_PER_TEST", "tilted rods and pucks in a Cylinder"),
    ("bound above without 2r·|p|", COVER, "if held(sqrt(mx * mx + my * my + mz * mz + 2 * r * pl + r * r) - Q.r, higher) then",
     "if held(sqrt(mx * mx + my * my + mz * mz + r * r) - Q.r, higher) then", "tilted rods and pucks in a Cylinder"),
    ("bound below the old bound (|m| + r)", COVER, "return mx, my, mz, if held(sqrt(qx * qx + qy * qy + qz * qz) - Q.r, higher) then 0 else -1",
     "return mx, my, mz, if held(sqrt(mx * mx + my * my + mz * mz) + r - Q.r, higher) then 0 else -1", "tilted rods and pucks in a Cylinder"),
    ("search on the old bound", COVER, "\tlocal lo, hi = -1, 1\n\tfor _ = 1, 60 do", "\tdo\n\t\treturn sqrt(mx * mx + my * my + mz * mz) + r\n\tend\n\tlocal lo, hi = -1, 1\n\tfor _ = 1, 60 do",
     "tilted rods and pucks in a Cylinder"),
    ("search: c's sign dropped (A signed)", COVER, "\tlocal A = 2 * r * abs(mx * ax + my * ay + mz * az)", "\tlocal A = 2 * r * (mx * ax + my * ay + mz * az)",
     "tilted rods and pucks in a Cylinder"),
    ("search: 10 halvings", COVER, "\tfor _ = 1, 60 do\n\t\tlocal s = (lo + hi) / 2", "\tfor _ = 1, 10 do\n\t\tlocal s = (lo + hi) / 2",
     "tilted rods and pucks in a Cylinder"),
    ("second cap never searched", COVER, "\treturn b ~= 0 or held(rimFarthest(bx, by, bz, P.r, P.ux, P.uy, P.uz, ux, uy, uz) - Q.r, higher), units",
     "\treturn true, units", "tilted rods and pucks in a Cylinder"),
    ("rim search charged nothing", COVER, "local UNITS_PER_RIM = 28", "local UNITS_PER_RIM = 0", "tilted rods and pucks in a Cylinder"),
]


def job_base(args):
    flt, want = args
    d = MT + "/base"
    (pa, fa), fails, out = run(d, flt)
    got = "fail" if (fa or 0) > 0 or pa is None else "pass"
    return flt, want, got, fails[:3]


def job_mut(m):
    name, path, a, b, flt = m
    d = tree("m_" + re.sub(r"[^a-z0-9]+", "_", name.lower()), REPO)
    mutate(os.path.join(d, path), a, b)
    (pa, fa), fails, out = run(d, flt)
    killed = (fa or 0) > 0 or pa is None
    return name, flt, killed, fails[:2]


if __name__ == "__main__":
    os.makedirs(MT, exist_ok=True)
    if sys.argv[1] == "base":
        tree("base", BASE)
        with ThreadPoolExecutor(3) as ex:
            for flt, want, got, fails in ex.map(job_base, NEW):
                print(f"{'OK ' if want == got else 'BAD'} on the tree before, '{flt}': expected to {want}, did {got}")
                for f in fails:
                    print("     ", f)
    else:
        with ThreadPoolExecutor(3) as ex:
            for name, flt, killed, fails in ex.map(job_mut, MUTANTS):
                print(f"{'killed  ' if killed else 'SURVIVED'} {name}  ('{flt}')")
                for f in fails:
                    print("     ", f)
