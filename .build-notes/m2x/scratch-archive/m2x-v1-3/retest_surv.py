"""V1 (m2x, round 3): every Cover.luau survivor of mutate.py against the 3 Cover.spec cases of surv_tests.py (the stop at the
budget, a reading entered past it, the stretches around a plate ringed by Balls), 3 workers. Prints the ones they kill."""
import json, os, re, shutil, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
LUNE = r"C:/Users/louis/.aftman/bin/lune.exe"
COVER = "src/shared/Physics/Cover.luau"
surv = [r for r in json.load(open(os.path.join(HERE, "out", "mutants.json"))) if r["state"] == "SURVIVED" and r["file"] == COVER]
workers = []
for i in range(3):
    d = os.path.join(HERE, "stw", "w%d" % i)
    if os.path.isdir(d):
        shutil.rmtree(d)
    shutil.copytree(os.path.join(HERE, "st_build", "repo"), d)
    workers.append(d)
orig = open(os.path.join(workers[0], COVER), encoding="utf-8", newline="").read()
pending = list(range(len(surv)))
running = {}
res = [None] * len(surv)
while pending or running:
    for w in workers:
        if w not in running and pending:
            k = pending.pop(0)
            m = surv[k]
            src = orig.split("\n")
            assert src[m["line"] - 1] == m["orig"]
            src[m["line"] - 1] = m["new"]
            open(os.path.join(w, COVER), "w", encoding="utf-8", newline="").write("\n".join(src))
            log = open(os.path.join(w, "t.log"), "w", encoding="utf-8")
            p = subprocess.Popen([LUNE, "run", "tests/run", "--", "--filter", "(f) a"], cwd=w, stdout=log, stderr=subprocess.STDOUT)
            running[w] = (p, k, log, time.time())
    time.sleep(0.3)
    for w in list(running):
        p, k, log, ts = running[w]
        if p.poll() is not None or time.time() - ts > 300:
            if p.poll() is None:
                p.kill(); p.wait()
            log.close()
            txt = open(os.path.join(w, "t.log"), encoding="utf-8", errors="replace").read()
            fails = re.findall(r"^\s*(?:FAIL|ERROR)\s+(.*)$", txt, flags=re.M)
            res[k] = (p.returncode != 0, fails[:2])
            del running[w]
for w in workers:
    open(os.path.join(w, COVER), "w", encoding="utf-8", newline="").write(orig)
killed = [(surv[k], res[k][1]) for k in range(len(surv)) if res[k][0]]
print("Cover survivors %d, killed by the new cases %d" % (len(surv), len(killed)))
for m, f in killed:
    print("KILLED %d %s | %s || %s" % (m["line"], m["what"], m["orig"].strip()[:70], "; ".join(x[:90] for x in f)))
left = [surv[k] for k in range(len(surv)) if not res[k][0]]
for m in left:
    print("LEFT %d %s | %s" % (m["line"], m["what"], m["orig"].strip()[:90]))
