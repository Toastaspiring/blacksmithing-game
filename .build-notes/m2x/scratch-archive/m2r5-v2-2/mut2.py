#!/usr/bin/env python
"""A few mutants of the new code, chosen apart from the fix's list, against the quick Physics suite. python mut.py <procs>"""
import json, os, re, shutil, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "repo")
LUNE = r"C:/Users/louis/.aftman/bin/lune.exe"
S = "src/shared/Physics/Sampling.luau"
M = "src/shared/Physics/MassProps.luau"
MUT = [
    (S, "local LINES_AGREE = 1e-6", "local LINES_AGREE = 1e-3", "LINES_AGREE 1e-3"),
    (S, "local LINES_AGREE = 1e-6", "local LINES_AGREE = 1e-9", "LINES_AGREE 1e-9"),
    (S, "local LINE_NOTHING = 1e-9", "local LINE_NOTHING = 1e-6", "LINE_NOTHING 1e-6"),
    (S, "local LINE_NOTHING = 1e-9", "local LINE_NOTHING = 1e-12", "LINE_NOTHING 1e-12"),
    (S, "keys[p.index] = { -p.volume, p.cy, abs(p.cx), p.cx, p.cz,", "keys[p.index] = { -p.volume, p.cy, p.cx, p.cz,", "rank: x before |x| gone"),
    (S, "keys[p.index] = { -p.volume, p.cy, abs(p.cx), p.cx, p.cz,", "keys[p.index] = { -p.volume, abs(p.cx), p.cy, p.cx, p.cz,", "rank: |x| before y"),
    (S, "keys[p.index] = { -p.volume, p.cy, abs(p.cx), p.cx, p.cz,", "keys[p.index] = { p.cy, -p.volume, abs(p.cx), p.cx, p.cz,", "rank: y before volume"),
    (S, "if a.slot ~= b.slot then\n\t\t\treturn a.slot < b.slot", "if a.slot ~= b.slot then\n\t\t\treturn a.slot > b.slot", "rank: slot names reversed"),
    (S, "if a.material ~= b.material then\n\t\t\treturn a.material < b.material", "if a.material ~= b.material then\n\t\t\treturn a.material > b.material", "rank: material names reversed"),
    (S, "return a.index < b.index\n\tend)\n\tlocal rank", "return a.index > b.index\n\tend)\n\tlocal rank", "rank: the highest index stays"),
    (S, "if readA <= LINE_NOTHING then\n\t\t\treturn w * readB\n\t\telseif readB <= LINE_NOTHING then\n\t\t\treturn w * readA\n\t\tend", "", "a family that reads nothing does not lose"),
    (S, "return w * (if spreadA < spreadB then readA else readB)", "return w * (if spreadA < spreadB then readB else readA)", "the family that agrees worse wins"),
    (S, "return w * min(readA, readB)", "return w * max(readA, readB)", "of two alike, the larger"),
    (S, "if rank[qi] < pRank then eps else -eps", "eps", "a surface span always grown"),
    (S, "if rank[qi] < pRank then eps else -eps", "-eps", "a surface span always shrunk"),
    (S, "frames[f + 12], vx, vy, vz, eps)", "frames[f + 12], vx, vy, vz, 0)", "the probe's span not grown"),
    (S, "if p.code ~= BLOCK then -- past the rim", "if false then -- past the rim", "no rim: a triangle's or a cap's patch counts whole"),
    (S, "local atProbe = abs(ox + sx) <= hx and abs(oy + sy) <= hy and abs(oz + sz) <= hz", "local atProbe = abs(ox) <= hx and abs(oy) <= hy and abs(oz) <= hz", "the reach at the probe tested at the surface"),
    (S, "local atSurface = abs(ox) <= hx and abs(oy) <= hy and abs(oz) <= hz", "local atSurface = abs(ox + sx) <= hx and abs(oy + sy) <= hy and abs(oz + sz) <= hz", "the reach at the surface tested at the probe"),
    (S, "local hx = l1 * abs(px) + l2 * abs(rx) + q.hx + 2 * eps", "local hx = l1 * abs(px) + q.hx + 2 * eps", "the reach forgets e2 on x"),
    (S, "local hz = l1 * abs(pz) + l2 * abs(rz) + q.hz + 2 * eps", "local hz = l2 * abs(rz) + q.hz + 2 * eps", "the reach forgets e1 on z"),
    (S, "return if cornerShows then w * VERDICT_STRIP_RIM else 0", "return w * VERDICT_STRIP_RIM", "rim credit without a corner"),
    (S, "if not hiddenNear then\n\t\t\treturn w * VERDICT_STRIP_CENTRE\n\t\tend", "", "no centre credit"),
    (S, "if cells > 1 then -- the slope", "if false then -- the slope", "the verdict's grid keeps the prototype's second slope"),
    (S, "hOwn = PI * p.r / 2 / (Geo.VERDICT_BALL_NF - 0.5)", "hOwn = PI * p.r / 2 / (Geo.VERDICT_BALL_NF - 1.5)", "a Ball one cell coarser"),
    (S, "hider[i] = not isCopy[i] and parts[i].volume >= Geo.MIN_PART_VOLUME", "hider[i] = parts[i].volume >= Geo.MIN_PART_VOLUME", "copies hide"),
    (S, "hider[i] = not isCopy[i] and parts[i].volume >= Geo.MIN_PART_VOLUME", "hider[i] = not isCopy[i]", "dust hides"),
    (S, "if j ~= i and kept[j] and aabbOverlap(p, parts[j], delta + tol + hSurf) then\n\t\t\t\t\t\ttable.insert(keptCand, parts[j])", "if j ~= i and aabbOverlap(p, parts[j], delta + tol + hSurf) then\n\t\t\t\t\t\ttable.insert(keptCand, parts[j])", "the measure's candidates include the cleaned"),
    (S, "for r = 1, N do\n\t\tlocal i = byRank[r].index\n\t\tif kept[i] then", "for r = 1, N do\n\t\tlocal i = r\n\t\tif kept[i] then", "the measure spends in part order"),
    (M, "return ranked[a.index] < ranked[b.index]", "return a.index < b.index", "ownership by index within a slot"),
    (M, "if ey < 0 then\n\t\tex, ey = -ex, -ey\n\tend", "", "no ê_y ≥ 0"),
    (M, "if axY > 0 then", "if axY >= 0 then", "the sum's guard"),
    (M, "if longest < Geo.AXIS_ELONGATION * middle then", "if longest <= Geo.AXIS_ELONGATION * middle then", "exactly 1.5 × has no axis"),
]
procs = int(sys.argv[1]) if len(sys.argv) > 1 else 8
MUT = [m for m in MUT if m[0] == M or "candidates" in m[3]]
MUT = [(m[0], m[1].replace("						table.insert(keptCand", "					table.insert(keptCand").replace("if j ~= i and kept[j] and aabbOverlap(p, parts[j], delta + tol + hSurf) then", "if j ~= i and kept[j] and aabbOverlap(p, parts[j], delta + tol + hSurf) then"), m[2].replace("						table.insert(keptCand", "					table.insert(keptCand"), m[3]) for m in MUT]
ROOT = os.path.join(HERE, "mutw")
os.makedirs(ROOT, exist_ok=True)

def prep(i):
    d = os.path.join(ROOT, "m%d" % i)
    if not os.path.isdir(d):
        os.makedirs(d)
        for sub in ("src", "tests", "tools", "vendor", "scripts"):
            shutil.copytree(os.path.join(REPO, sub), os.path.join(d, sub))
        for f in ("aftman.toml", "default.project.json", "test.project.json", ".luaurc"):
            shutil.copy(os.path.join(REPO, f), os.path.join(d, f))
        os.makedirs(os.path.join(d, "docs/spec/prototypes/S2/verdict"))
        shutil.copytree(os.path.join(REPO, "docs/spec/prototypes/S2/v2"), os.path.join(d, "docs/spec/prototypes/S2/v2"))
        shutil.copy(os.path.join(REPO, "docs/spec/prototypes/S2/verdict/worst_P.json"), os.path.join(d, "docs/spec/prototypes/S2/verdict/worst_P.json"))
        tol = os.path.join(d, "tests/lib/Tol.luau")
        t = open(tol, encoding="utf-8", newline="").read().replace("CASE_BUDGET_MS = 2000,", "CASE_BUDGET_MS = 60000,")
        open(tol, "w", encoding="utf-8", newline="").write(t)
    return d

running = []
results = []
idx = 0
free = list(range(procs))
for w in free:
    prep(w)
def reap():
    global running
    still = []
    for (p, w, m, log) in running:
        if p.poll() is None:
            still.append((p, w, m, log))
        else:
            txt = open(log, encoding="utf-8", errors="replace").read()
            fails = re.findall(r"^\s*(?:FAIL|ERROR)\s+(.*)$", txt, flags=re.M)
            state = "KILLED" if p.returncode != 0 else "SURVIVED"
            results.append((state, m[3], fails[:3]))
            print(state, "|", m[3], "|", (fails[0][:90] if fails else ""), flush=True)
            # restore
            shutil.copy(os.path.join(REPO, m[0]), os.path.join(ROOT, "m%d" % w, m[0]))
            free.append(w)
    running = still
for m in MUT:
    while not free:
        reap()
        time.sleep(0.5)
    w = free.pop()
    d = os.path.join(ROOT, "m%d" % w)
    p0 = os.path.join(d, m[0])
    s = open(p0, encoding="utf-8", newline="").read()
    a = m[1].replace("\n", "\r\n") if "\r\n" in s else m[1]
    b = m[2].replace("\n", "\r\n") if "\r\n" in s else m[2]
    if a not in s:
        print("NOT APPLIED", m[3], flush=True)
        free.append(w)
        continue
    open(p0, "w", encoding="utf-8", newline="").write(s.replace(a, b, 1))
    log = os.path.join(ROOT, "log%d.txt" % w)
    lf = open(log, "w", encoding="utf-8")
    p = subprocess.Popen([LUNE, "run", "tests/run", "--", "--quick", "--filter", "Physics/"], cwd=d, stdout=lf, stderr=subprocess.STDOUT)
    running.append((p, w, m, log))
while running:
    reap()
    time.sleep(0.5)
print("killed", sum(1 for r in results if r[0] == "KILLED"), "of", len(results))
