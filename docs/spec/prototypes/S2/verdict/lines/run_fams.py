#!/usr/bin/env python
"""Runs b_run on families in a harness folder, shards in parallel, one family at a time. args: folder procs shards family..."""
import os, subprocess, sys, time
folder, procs, shards = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
fams = sys.argv[4:]
LUNE = r"C:/Users/louis/.aftman/bin/lune.exe"
log = open(os.path.join(folder, "out", "fams.log"), "a")
for fam in fams:
    t0 = time.time()
    running = []
    for s in range(shards):
        while len(running) >= procs:
            running = [p for p in running if p.poll() is None]
            time.sleep(0.2)
        running.append(subprocess.Popen([LUNE, "run", "b_run", "--", fam, str(s), str(shards)], cwd=folder, stdout=log, stderr=subprocess.STDOUT))
    for p in running:
        p.wait()
    log.write("done %s %.0f s\n" % (fam, time.time() - t0))
    log.flush()
log.write("ALLDONE\n")
log.close()
