#!/usr/bin/env python
"""V1 (e): run the mutants. Stage 1: the Physics suites, quick. Stage 2 on a survivor: the whole quick suite. Stage 3 on a survivor: the whole suite with the slow cases.
Each worker has its own copy of the tree. Results to out/mut.jsonl; a kill keeps the first failing case's name, so a kill by a time budget shows."""
import os, sys, json, shutil, subprocess, threading, queue, time, re
from mutants import M

HERE = os.path.dirname(os.path.abspath(__file__))
TREE = os.path.join(HERE, "tree")
WORK = os.path.join(HERE, "mutw")
LUNE = shutil.which("lune") or "lune"
OUT = os.path.join(HERE, "out", sys.argv[1] if len(sys.argv) > 1 else "mut.jsonl")
NWORK = int(sys.argv[2]) if len(sys.argv) > 2 else 6
ONLY = set(int(x) for x in sys.argv[3].split(",")) if len(sys.argv) > 3 and sys.argv[3] != "-" else None
STAGES = sys.argv[4].split(",") if len(sys.argv) > 4 else ["physics", "quick", "full"]

def read(path):
    return open(path, encoding="utf-8", newline="").read()

def run(cwd, args, timeout):
    t0 = time.time()
    try:
        p = subprocess.run([LUNE, "run", "tests/run", "--"] + args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout.decode("utf-8", "replace"), time.time() - t0
    except subprocess.TimeoutExpired as e:
        return 124, (e.stdout or b"").decode("utf-8", "replace"), time.time() - t0

def firstFail(out):
    lines = [l for l in out.splitlines() if re.match(r"^\s*(FAIL|ERROR)", l)]
    return lines

def worker(k, q, results, lock):
    root = os.path.join(WORK, str(k))
    if not os.path.isdir(root):
        shutil.copytree(TREE, root)
        tol = os.path.join(root, "tests/lib/Tol.luau")
        t = read(tol)
        assert "CASE_BUDGET_MS = 2000," in t
        open(tol, "w", encoding="utf-8", newline="").write(t.replace("CASE_BUDGET_MS = 2000,", "CASE_BUDGET_MS = 300000,"))
    while True:
        try:
            idx = q.get_nowait()
        except queue.Empty:
            return
        mu = M[idx]
        path = os.path.join(root, mu["file"])
        original = read(os.path.join(TREE, mu["file"]))
        lines = original.split("\n")
        ln = lines[mu["line"] - 1]
        if mu["old"] not in ln:
            with lock:
                results.write(json.dumps(dict(idx=idx, file=mu["file"], line=mu["line"], old=mu["old"], new=mu["new"], why=mu["why"], state="BADLINE", got=ln)) + "\n")
                results.flush()
            continue
        lines[mu["line"] - 1] = ln.replace(mu["old"], mu["new"], 1)
        open(path, "w", encoding="utf-8", newline="").write("\n".join(lines))
        state, stage, fail = "SURVIVED", "", []
        for st in STAGES:
            if st == "physics":
                code, out, secs = run(root, ["--quick", "--filter", "Physics/"], 400)
            elif st == "quick":
                code, out, secs = run(root, ["--quick"], 600)
            else:
                code, out, secs = run(root, [], 1500)
            if code != 0:
                state, stage, fail = "KILLED", st, firstFail(out)
                if code == 124:
                    fail = ["TIMEOUT"] + fail
                if code == 2:
                    fail = ["HARNESS"] + out.splitlines()[-3:]
                break
        open(path, "w", encoding="utf-8", newline="").write(original)
        with lock:
            results.write(json.dumps(dict(idx=idx, file=mu["file"], line=mu["line"], old=mu["old"], new=mu["new"], why=mu["why"], state=state, stage=stage, fail=fail)) + "\n")
            results.flush()
        print(idx, state, stage, mu["why"], flush=True)

def main():
    q = queue.Queue()
    for i in range(len(M)):
        if ONLY is None or i in ONLY:
            q.put(i)
    lock = threading.Lock()
    with open(OUT, "a", encoding="utf-8") as results:
        ts = [threading.Thread(target=worker, args=(k, q, results, lock)) for k in range(NWORK)]
        for t in ts: t.start()
        for t in ts: t.join()

if __name__ == "__main__":
    main()
