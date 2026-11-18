# Load factor: this machine's old-reading verdict ms (out/m5_worst.json) against worst_P.json's recorded lune_ms.verdict
import json, statistics
rec = json.load(open('out/worst_P_repo.json'))
mine = json.load(open('out/m5_worst.json'))
recd = {}
for d in rec:
    recd['worst_P ' + d['from']] = d['lune_ms']
factors = []
for r in mine:
    if r['name'] in recd and 'verdict' in recd[r['name']]:
        f = r['verdict']['old'] / recd[r['name']]['verdict']
        factors.append(f)
        print('%-26s old verdict here %7.2f ms, recorded %6.2f ms: x%.2f | new (base) here %7.2f ms -> %6.1f ms unloaded est.; exposure old %6.2f new %6.2f -> %6.1f est.' % (
            r['name'], r['verdict']['old'], recd[r['name']]['verdict'], f, r['verdict']['base'], r['verdict']['base'] / f, r['full']['old'], r['full']['base'], r['full']['base'] / f))
print('load factor: median %.2f, min %.2f, max %.2f over %d designs' % (statistics.median(factors), min(factors), max(factors), len(factors)))
