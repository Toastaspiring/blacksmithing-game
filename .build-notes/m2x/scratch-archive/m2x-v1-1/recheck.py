import json, os, subprocess, re
HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.join(HERE, "tunits", "repo")
LUNE = r"C:/Users/louis/.aftman/bin/lune.exe"
res = json.load(open(os.path.join(HERE, "out", "mutants.json")))
surv = [r for r in res if r["state"] == "SURVIVED"]
orig = {}
for f in ("src/shared/Physics/Cover.luau", "src/shared/Physics/Sampling.luau"):
    orig[f] = open(os.path.join(W, f), encoding="utf-8", newline="").read()
killed = 0
rows = []
for r in surv:
    src = orig[r["file"]].split("\n")
    assert src[r["line"] - 1] == r["orig"]
    src[r["line"] - 1] = r["new"]
    open(os.path.join(W, r["file"]), "w", encoding="utf-8", newline="").write("\n".join(src))
    p = subprocess.run([LUNE, "run", "tests/run", "--", "--filter", "to the unit"], cwd=W, capture_output=True, text=True, timeout=300)
    open(os.path.join(W, r["file"]), "w", encoding="utf-8", newline="").write(orig[r["file"]])
    k = p.returncode != 0
    killed += k
    rows.append(("KILLED" if k else "still survives", os.path.basename(r["file"]), r["line"], r["what"], r["orig"].strip()[:90]))
for row in rows:
    print("%-15s %s:%d %s | %s" % row)
print("the unit pin kills %d of %d survivors" % (killed, len(surv)))
