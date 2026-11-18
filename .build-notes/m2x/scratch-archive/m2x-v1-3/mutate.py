#!/usr/bin/env python
"""V1 (m2x, round 2; round 3: the current line ranges): line mutants of Physics/Cover.luau (all code lines) and of Sampling's rank, copy check and verdict
loop, against the Physics specs (quick: `lune run tests/run -- --quick --root tests/Physics`, case budget raised to 60 s
so that load cannot kill a mutant). python mutate.py <procs> [limit] [only-file-substring]. Writes out/mutants.json and
prints the survivors."""
import json, os, re, shutil, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "repo")
LUNE = r"C:/Users/louis/.aftman/bin/lune.exe"
COVER = "src/shared/Physics/Cover.luau"
SAMP = "src/shared/Physics/Sampling.luau"
RANGES = ((COVER, 142, 894), (SAMP, 481, 769))
SKIP_PREFIX = ("--", "local function", "function ", "export type", "type ")


def code_lines(path, lo, hi):
    lines = open(os.path.join(REPO, path), encoding="utf-8", newline="").read().split("\n")
    out = []
    for n in range(lo, min(hi, len(lines)) + 1):
        s = lines[n - 1]
        t = s.strip()
        if not t or t.startswith(SKIP_PREFIX) or t in ("end", "else", "end)", "do", "}", "})", "end,", "then", "(", ")"):
            continue
        out.append((n, s))
    return lines, out


REL = [(" <= ", " < "), (" >= ", " > "), (" ~= ", " == "), (" == ", " ~= "), (" < ", " <= "), (" > ", " >= ")]


def mutants_for(line):
    s = line
    code = s.split("--")[0]
    res = []
    # relational: every occurrence of the first operator kind found, one mutant each (up to 3)
    for a, b in REL:
        idx = [m.start() for m in re.finditer(re.escape(a), code)]
        if idx:
            for i in idx[:3]:
                res.append((s[:i] + b + s[i + len(a):], "%s -> %s @%d" % (a.strip(), b.strip(), i)))
            break
    # boolean
    for a, b in ((" and ", " or "), (" or ", " and ")):
        idx = [m.start() for m in re.finditer(re.escape(a), code)]
        for i in idx[:2]:
            res.append((s[:i] + b + s[i + len(a):], "%s -> %s @%d" % (a.strip(), b.strip(), i)))
        if idx:
            break
    m = re.search(r"\bnot ", code)
    if m:
        i = m.start()
        res.append((s[:i] + s[i + 4:], "drop not"))
    # arithmetic: the first two binary + - * /
    k = 0
    for m in re.finditer(r" ([+\-*/]) ", code):
        op = m.group(1)
        rep = {"+": "-", "-": "+", "*": "/", "/": "*"}[op]
        i = m.start()
        res.append((s[:i] + " " + rep + " " + s[i + 3:], "%s -> %s @%d" % (op, rep, i)))
        k += 1
        if k >= 2:
            break
    m = re.search(r"([+\-])= ", code)
    if m:
        op = m.group(1)
        rep = {"+": "-", "-": "+"}[op]
        i = m.start()
        res.append((s[:i] + rep + "= " + s[i + 3:], "%s= -> %s=" % (op, rep)))
    # a numeric literal: 2 -> 1, 0.5 -> 0.25 etc. (the first standalone literal outside indexing)
    m = re.search(r"(?<![\w\.\[])(\d+(?:\.\d+)?(?:e-?\d+)?)(?![\w\.\]])", code)
    if m and not re.match(r"^\s*(for|local\s+\w+\s*:\s*\{)", code):
        lit = m.group(1)
        try:
            v = float(lit)
            nv = {0.0: "1", 1.0: "2", 2.0: "1"}.get(v, repr(v * 2) if v != int(v) else str(int(v) + 1))
            res.append((s[:m.start(1)] + nv + s[m.end(1):], "literal %s -> %s" % (lit, nv)))
        except ValueError:
            pass
    # a statement dropped: simple assignments and calls on one line
    t = code.strip()
    if (re.match(r"^[\w\.\[\]\s,+*/\-]+(\+=|-=|=)\s", t) and not t.startswith("local ") and not t.endswith(("then", "do", "{", "(", ","))
            and t.count("(") == t.count(")")) or re.match(r"^(break|return\b.*|settle\(\)|work\(.*\)|table\.insert\(.*\))$", t):
        res.append((re.match(r"^\s*", s).group(0) + "do end -- " + t, "drop statement"))
    return res


def build(only):
    muts = []
    for path, lo, hi in RANGES:
        if only and only not in path:
            continue
        lines, cl = code_lines(path, lo, hi)
        for n, s in cl:
            seen = set()
            for new, what in mutants_for(s):
                if new != s and new not in seen:
                    seen.add(new)
                    muts.append({"file": path, "line": n, "orig": s, "new": new, "what": what})
    return muts


def prep(i):
    d = os.path.join(HERE, "mutw", "m%d" % i)
    if not os.path.isdir(d):
        os.makedirs(d)
        for sub in ("src", "tests", "tools", "vendor", "scripts", "docs"):
            shutil.copytree(os.path.join(REPO, sub), os.path.join(d, sub))
        for f in ("aftman.toml", "default.project.json", "test.project.json"):
            shutil.copy(os.path.join(REPO, f), os.path.join(d, f))
        tol = os.path.join(d, "tests/lib/Tol.luau")
        t = open(tol, encoding="utf-8", newline="").read()
        t2 = re.sub(r"CASE_BUDGET_MS = \d+", "CASE_BUDGET_MS = 60000", t)
        open(tol, "w", encoding="utf-8", newline="").write(t2)
    return d


def main():
    procs = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9
    only = sys.argv[3] if len(sys.argv) > 3 else None
    muts = build(only)[:limit]
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
                assert src[m["line"] - 1] == m["orig"], (m["line"], m["orig"])
                src[m["line"] - 1] = m["new"]
                for f in (COVER, SAMP):
                    open(os.path.join(w, f), "w", encoding="utf-8", newline="").write(originals[(w, f)])
                open(os.path.join(w, m["file"]), "w", encoding="utf-8", newline="").write("\n".join(src))
                log = open(os.path.join(w, "mut.log"), "w", encoding="utf-8")
                p = subprocess.Popen([LUNE, "run", "tests/run", "--", "--quick", "--root", "tests/Physics"], cwd=w, stdout=log,
                                     stderr=subprocess.STDOUT)
                running[w] = (p, k, log, time.time())
        time.sleep(0.5)
        for w in list(running):
            p, k, log, ts = running[w]
            if p.poll() is not None or time.time() - ts > 600:
                if p.poll() is None:
                    p.kill()
                    p.wait()
                log.close()
                txt = open(os.path.join(w, "mut.log"), encoding="utf-8", errors="replace").read()
                fails = re.findall(r"^\s*(?:FAIL|ERROR)\b(.*)$", txt, flags=re.M)
                state = "KILLED" if p.returncode != 0 else "SURVIVED"
                results[k] = dict(muts[k], state=state, fails=[f.strip()[:160] for f in fails[:3]], secs=round(time.time() - ts, 1))
                del running[w]
                done = sum(1 for r in results if r)
                if done % 25 == 0:
                    print("%d/%d done, %.0f s" % (done, len(muts), time.time() - t0), flush=True)
                    json.dump([r for r in results if r], open(os.path.join(HERE, "out", "mutants.partial.json"), "w"), indent=1)
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
