"""m2x-fix-6: the verifiers' surviving mutants of round 5's lines of Physics/Cover.luau (V1's 41, `mutants_v1.json`, the
survivors of its mutants6.json; V2's 4 from its mut6.py), each on a copy of tree/ (the build with this round's
Cover.spec), against the cases this round changed or added: Cover.spec's tilted rods (both cases) and the run of searched
cap rims. Every one survived the whole quick Physics suite before this round (their runs), so a mutant these cases kill
is killed by the suite. At most 3 Lune processes at a time.
   python mut6.py [procs]   -> out/mut6.json, out/mut6.txt"""
import json, os, re, shutil, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

W = os.path.dirname(os.path.abspath(__file__))
TREE = os.path.join(W, "tree")
MT = os.path.join(W, "mt")
COVER = "src/shared/Physics/Cover.luau"
LUNE = r"C:/Users/louis/.aftman/tool-storage/lune-org/lune/0.8.9/lune.exe"
FILTERS = ("tilted rods", "a run of searched cap rims")

# V2's survivors (m2x-v2-6/mut6.py), whole-text replacements
V2 = [
    ("V2 units: only the caps actually searched (order-dependent)",
     "\tlocal units = UNITS_PER_TEST + (if a == 0 then UNITS_PER_RIM else 0) + (if b == 0 then UNITS_PER_RIM else 0)\n"
     "\tif a == 0 and not held(rimFarthest(ax, ay, az, P.r, P.ux, P.uy, P.uz, ux, uy, uz) - Q.r, higher) then\n"
     "\t\treturn false, units\n\tend\n",
     "\tlocal units = UNITS_PER_TEST + (if a == 0 then UNITS_PER_RIM else 0)\n"
     "\tif a == 0 and not held(rimFarthest(ax, ay, az, P.r, P.ux, P.uy, P.uz, ux, uy, uz) - Q.r, higher) then\n"
     "\t\treturn false, units\n\tend\n\tunits += if b == 0 then UNITS_PER_RIM else 0\n"),
    ("V2 lower bound always P's local Y (pl ignored)",
     "\tif pl > 0 then\n\t\tc, sn = pv / pl, pw / pl\n\tend\n", "\tif pl > math.huge then\n\t\tc, sn = pv / pl, pw / pl\n\tend\n"),
    ("V2 rule A's loop reports removed",
     "\t\t\t\tif due() then -- a run of rims searched reports too\n\t\t\t\t\treturn 0, done, true\n\t\t\t\tend\n", ""),
    ("V2 parallel cut 1e-8 -> 0 (search at any tilt)", "\tif al <= 1e-8 then\n", "\tif al <= 0 then\n"),
]


def mutants():
    out = []
    for x in json.load(open(os.path.join(W, "mutants_v1.json"), encoding="utf-8")):
        out.append(("V1 %d %s" % (x["line"], x["what"]), ("line", x["line"], x["orig"], x["new"])))
    for name, a, b in V2:
        out.append((name, ("text", a, b)))
    return out


def tree(k):
    d = os.path.join(MT, "m%02d" % k)
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    for sub in ("src", "tests", "docs"):
        shutil.copytree(os.path.join(TREE, sub), os.path.join(d, sub))
    for f in ("aftman.toml", ".luaurc", "default.project.json", "test.project.json"):
        shutil.copy(os.path.join(TREE, f), d)
    return d


def job(arg):
    k, (name, m) = arg
    d = tree(k)
    p = os.path.join(d, COVER)
    s = open(p, encoding="utf-8", newline="").read()
    if m[0] == "line":
        lines = s.split("\n")
        assert lines[m[1] - 1] == m[2], name
        lines[m[1] - 1] = m[3]
        s = "\n".join(lines)
    else:
        assert s.count(m[1]) == 1, name
        s = s.replace(m[1], m[2])
    open(p, "w", encoding="utf-8", newline="").write(s)
    fails, results = [], []
    for f in FILTERS:
        r = subprocess.run([LUNE, "run", "tests/run", "--", "--filter", f], cwd=d, capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
        out = r.stdout + r.stderr
        res = re.search(r"RESULT pass=(\d+) fail=(\d+)", out)
        results.append(res.group(0) if res else "no RESULT (exit %d)" % r.returncode)
        lines = out.splitlines()
        for i, l in enumerate(lines):
            if l.strip().startswith(("FAIL", "ERROR")):
                why = lines[i + 1].strip() if i + 1 < len(lines) else ""
                fails.append(l.strip()[:150] + " :: " + why[:200])
        if not res:
            fails.append("no RESULT: " + out[-300:])
    shutil.rmtree(d)
    return {"name": name, "state": "KILLED" if fails else "SURVIVED", "results": results, "fails": fails}


if __name__ == "__main__":
    procs = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    ms = list(enumerate(mutants()))
    os.makedirs(MT, exist_ok=True)
    os.makedirs(os.path.join(W, "out"), exist_ok=True)
    with ThreadPoolExecutor(procs) as ex:
        res = list(ex.map(job, ms))
    json.dump(res, open(os.path.join(W, "out", "mut6.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    with open(os.path.join(W, "out", "mut6.txt"), "w", encoding="utf-8") as f:
        for r in res:
            f.write("%-8s %s | %s\n" % (r["state"], r["name"], "; ".join(r["results"])))
            for x in r["fails"][:2]:
                f.write("         %s\n" % x)
        f.write("killed %d of %d\n" % (sum(r["state"] == "KILLED" for r in res), len(res)))
    print(open(os.path.join(W, "out", "mut6.txt"), encoding="utf-8").read())
