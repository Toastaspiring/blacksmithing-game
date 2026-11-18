# fuller sweep (patched port, new reading): sum of the shards finished so far
import glob, re
n = k = 0; fe = [0] * 6; old = [0] * 6; fk = [0] * 4; big = t = 0; w = 0.0; shards = 0; secs = 0
for f in sorted(glob.glob('atk/logs/fs2_*.log')):
    txt = open(f, encoding='utf-8', errors='replace').read()
    m = re.search(r'SUMMARY (\d+) designs, core kept (\d+), .*?: ([\d/]+); .*?: ([\d/]+); .*?: (\d+), tier flips (\d+), worst \|dD\| ([\d.]+)', txt)
    if not m: continue
    shards += 1
    n += int(m[1]); k += int(m[2])
    fe = [a + int(b) for a, b in zip(fe, m[3].split('/'))]
    old = [a + int(b) for a, b in zip(old, m[4].split('/'))]
    big += int(m[5]); t += int(m[6]); w = max(w, float(m[7]))
    m2 = re.search(r'FALSEKEPT kept cores truly under 1.5/1/0.5/0.25 %: ([\d/]+)', txt)
    if m2: fk = [a + int(b) for a, b in zip(fk, m2[1].split('/'))]
    m3 = re.search(r'exit \d+ (\d+)s', txt)
    if m3: secs += int(m3[1])
print('fuller sweep, %d of 40 shards: %d designs, core kept %d; cleaned at true >= 2.5/5/7.5/10/15/20 %%: %s; kept while truly under 1.5/1/0.5/0.25 %%: %s; |dD| >= .05: %d, tier flips %d, worst |dD| %.4f; %d s' % (shards, n, k, '/'.join(map(str, fe)), '/'.join(map(str, fk)), big, t, w, secs))
