#!/usr/bin/env python
"""V1 (m2x): line mutants of Physics/Cover.luau and Sampling's verdict loop against the quick suite (case budget raised
to 60 s so that load cannot kill a mutant). python mutate.py <procs> [limit]. Writes out/mutants.json and prints the
survivors."""
import json, os, re, shutil, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "repo")
LUNE = r"C:/Users/louis/.aftman/bin/lune.exe"
COVER = "src/shared/Physics/Cover.luau"
SAMP = "src/shared/Physics/Sampling.luau"

def code_lines(path, lo, hi):
    lines = open(os.path.join(REPO, path), encoding="utf-8", newline="").read().split("\n")
    out = []
    for n in range(lo, min(hi, len(lines)) + 1):
        s = lines[n - 1]
        t = s.strip()
        if not t or t.startswith("--") or t in ("end", "else", "end)", "do", "}", "})", "end,"):
            continue
        out.append((n, s))
    return lines, out

REL = [("<=", "<"), (">=", ">"), ("~=", "=="), ("==", "~=")]
def mutants_for(line):
    s = line
    code = s.split("--")[0]
    res = []
    # relational (first match)
    for a, b in REL:
        i = code.find(" " + a + " ")
        if i >= 0:
            res.append((s[:i] + " " + b + " " + s[i + len(a) + 2:], "%s -> %s" % (a, b)))
            break
    else:
        m = re.search(r" (<|>) ", code)
        if m:
            i = m.start()
            res.append((s[:i] + " " + m.group(1) + "= " + s[i + 3:], "%s -> %s=" % (m.group(1), m.group(1))))
    # boolean
    if " and " in code:
        i = code.find(" and ")
        res.append((s[:i] + " or " + s[i + 5:], "and -> or"))
    elif " or " in code:
        i = code.find(" or ")
        res.append((s[:i] + " and " + s[i + 4:], "or -> and"))
    elif re.search(r"\bnot ", code):
        i = re.search(r"\bnot ", code).start()
        res.append((s[:i] + s[i + 4:], "drop not"))
    # arithmetic (first + or - or *)
    m = re.search(r" ([+\-*/]) ", code)
    if m and len(res) < 3:
        op = m.group(1)
        rep = {"+": "-", "-": "+", "*": "/", "/": "*"}[op]
        i = m.start()
        res.append((s[:i] + " " + rep + " " + s[i + 3:], "%s -> %s" % (op, rep)))
    m = re.search(r"([+\-])= ", code)
    if m and len(res) < 3:
        op = m.group(1)
        rep = {"+": "-", "-": "+"}[op]
        i = m.start()
        res.append((s[:i] + rep + "= " + s[i + 3:], "%s= -> %s=" % (op, rep)))
    # a statement dropped: simple assignments and calls on one line
    t = code.strip()
    if (re.match(r"^[\w\.\[\]\s,+*/\-]+(\+=|-=|=)\s", t) and not t.startswith("local ") and not t.endswith(("then", "do", "{", "(", ",")) and t.count("(") == t.count(")")) or re.match(r"^(break|return\b.*|settle\(\)|work\(.*\))$", t):
        res.append((re.match(r"^\s*", s).group(0) + "do end -- " + t, "drop statement"))
    return res

def build():
    muts = []
    for path, lo, hi in ((COVER, 130, 762), (SAMP, 632, 700)):
        lines, cl = code_lines(path, lo, hi)
        for n, s in cl:
            for new, what in mutants_for(s):
                if new != s:
                    muts.append({"file": path, "line": n, "orig": s, "new": new, "what": what})
    return muts

def prep(i):
    d = os.path.join(HERE, "mutw", "m%d" % i)
    if not os.path.isdir(d):
        os.makedirs(d)
        for sub in ("src", "tests", "tools", "vendor", "scripts"):
            shutil.copytree(os.path.join(REPO, sub), os.path.join(d, sub))
        for f in ("aftman.toml", "default.project.json", "test.project.json", ".luaurc"):
            shutil.copy(os.path.join(REPO, f), os.path.join(d, f))
        shutil.copytree(os.path.join(REPO, "docs"), os.path.join(d, "docs"))
        tol = os.path.join(d, "tests/lib/Tol.luau")
        t = open(tol, encoding="utf-8", newline="").read().replace("CASE_BUDGET_MS = 2000,", "CASE_BUDGET_MS = 60000,")
        open(tol, "w", encoding="utf-8", newline="").write(t)
    return d

def main():
    procs = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9
    muts = build()[:limit]
    print("mutants:", len(muts), flush=True)
    workers = [prep(i) for i in range(procs)]
    originals = {}
    for w in workers:
        for f in (COVER, SAMP):
            originals[(w, f)] = open(os.path.join(w, f), encoding="utf-8", newline="").read()
    pending = list(range(len(muts)))
    running = {}
    results = [None] * len(muts)
    t0 = time.time()
    while pending or running:
        for w in workers:
            if w not in running and pending:
                k = pending.pop(0)
                m = muts[k]
                src = originals[(w, m["file"])].split("\n")
                assert src[m["line"] - 1] == m["orig"]
                src[m["line"] - 1] = m["new"]
                for f in (COVER, SAMP):
                    open(os.path.join(w, f), "w", encoding="utf-8", newline="").write(originals[(w, f)])
                open(os.path.join(w, m["file"]), "w", encoding="utf-8", newline="").write("\n".join(src))
                log = open(os.path.join(w, "mut.log"), "w", encoding="utf-8")
                p = subprocess.Popen([LUNE, "run", "tests/run", "--", "--quick"], cwd=w, stdout=log, stderr=subprocess.STDOUT)
                running[w] = (p, k, log, time.time())
        time.sleep(0.5)
        for w in list(running):
            p, k, log, ts = running[w]
            if p.poll() is not None or time.time() - ts > 400:
                if p.poll() is None:
                    p.kill()
                    p.wait()
                log.close()
                txt = open(os.path.join(w, "mut.log"), encoding="utf-8", errors="replace").read()
                fails = re.findall(r"^\s*(?:FAIL|ERROR)\s+(.*)$", txt, flags=re.M)
                state = "KILLED" if p.returncode != 0 else "SURVIVED"
                results[k] = dict(muts[k], state=state, fails=fails[:3])
                del running[w]
                done = sum(1 for r in results if r)
                if done % 20 == 0:
                    print("%d/%d done, %.0f s" % (done, len(muts), time.time() - t0), flush=True)
    for w in workers:
        for f in (COVER, SAMP):
            open(os.path.join(w, f), "w", encoding="utf-8", newline="").write(originals[(w, f)])
    json.dump(results, open(os.path.join(HERE, "out", "mutants.json"), "w"), indent=1)
    surv = [r for r in results if r["state"] == "SURVIVED"]
    print("killed %d, survived %d" % (len(results) - len(surv), len(surv)))
    for r in surv:
        print("SURVIVED %s:%d %s | %s" % (os.path.basename(r["file"]), r["line"], r["what"], r["orig"].strip()))

if __name__ == "__main__":
    main()
