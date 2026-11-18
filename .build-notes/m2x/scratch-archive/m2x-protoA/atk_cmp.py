# Attack logs, old reading against new: per script the worst |dD|, the TIER flags, the rows.
import re, glob, os
def stats(path):
    if not os.path.isfile(path): return None
    txt = open(path, encoding='utf-8', errors='replace').read()
    dds = [float(x) for x in re.findall(r'\|dD\|\s*[=:]?\s*([0-9.]+)', txt)]
    tiers = len(re.findall(r'\bTIER\b', txt))
    rows = len(re.findall(r'\|dD\|', txt))
    err = 'exit 0' not in txt.splitlines()[-1] if txt.strip() else True
    return (max(dds) if dds else 0.0, tiers, rows, err)
print('%-26s %28s   %28s' % ('script', 'old: worst |dD|, TIER, rows', 'new: worst |dD|, TIER, rows'))
for f in sorted(glob.glob('atk/logs/*.log')):
    name = os.path.basename(f)
    n = stats(f); o = stats('atk_old/logs/' + name)
    fmt = lambda s: '-' if s is None else '%7.4f %4d %4d%s' % (s[0], s[1], s[2], ' ERR' if s[3] else '')
    print('%-26s %28s   %28s' % (name[:-4], fmt(o), fmt(n)))
