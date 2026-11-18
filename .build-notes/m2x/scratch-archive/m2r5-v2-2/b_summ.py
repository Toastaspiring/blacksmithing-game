#!/usr/bin/env python
import json, glob, collections, sys
pat = sys.argv[1] if len(sys.argv) > 1 else 'out/b_*_*.json'
rows = []
byfam = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
designs = collections.Counter()
parts = collections.Counter()
for f in glob.glob(pat):
    d = json.load(open(f))
    designs[d['family']] += d['designs']
    parts[d['family']] += d['parts']
    for sh, c in d['byShape'].items():
        for k, v in c.items():
            byfam[d['family']][sh][k] += v
    rows += d['wrong']
print('designs', sum(designs.values()), 'parts', sum(parts.values()))
BANDS = ['E0.025', 'E0.03', 'E0.05', 'E0.075', 'E0.1', 'E0.15', 'E0.2', 'E0.3', 'E0.4']
KB = ['K0.015', 'K0.01', 'K0.005', 'K0.0025']
tot = collections.Counter()
for fam in sorted(byfam):
    fc = collections.Counter()
    for sh in byfam[fam]:
        fc.update(byfam[fam][sh])
    tot.update(fc)
    print('%-11s %6d designs: false Enclosed at 2.5/3/5/7.5/10/15/20/30/40 %%: %s | false kept < 1.5/1/0.5/0.25 %%: %s' % (fam, designs[fam], '/'.join(str(fc[b]) for b in BANDS), '/'.join(str(fc[b]) for b in KB)))
print('TOTAL false Enclosed', '/'.join(str(tot[b]) for b in BANDS), 'false kept', '/'.join(str(tot[b]) for b in KB))
shc = collections.defaultdict(collections.Counter)
for fam in byfam:
    for sh in byfam[fam]:
        shc[sh].update(byfam[fam][sh])
for sh in sorted(shc):
    print('%-12s parts %6d: false Enclosed %s | false kept %s' % (sh, shc[sh]['parts'], '/'.join(str(shc[sh][b]) for b in BANDS), '/'.join(str(shc[sh][b]) for b in KB)))
# extremes
hi = collections.defaultdict(lambda: None)
lo = collections.defaultdict(lambda: None)
for r in rows:
    for w in r['wrong']:
        key = w['shape']
        if not w['kept']:
            if hi[key] is None or w['s'] > hi[key][0]:
                hi[key] = (w['s'], w.get('read'), r['family'], r['name'], w['label'], r.get('maxDD'), r.get('tier'), r.get('valid'))
        else:
            if lo[key] is None or w['s'] < lo[key][0]:
                lo[key] = (w['s'], w.get('read'), r['family'], r['name'], w['label'], r.get('maxDD'), r.get('tier'), r.get('valid'))
print('--- the highest true share cleaned, per shape')
for k, v in sorted(hi.items()):
    print(k, 'true %.2f%% read %.2f%%' % (v[0]*100, (v[1] or 0)*100), v[2], v[3], v[4], '|dD| %.4f' % (v[5] or 0), 'TIER' if v[6] else '', 'valid' if v[7] else 'invalid')
print('--- the lowest true share kept, per shape')
for k, v in sorted(lo.items()):
    print(k, 'true %.3f%% read %.2f%%' % (v[0]*100, (v[1] or 0)*100), v[2], v[3], v[4], '|dD| %.4f' % (v[5] or 0), 'TIER' if v[6] else '', 'valid' if v[7] else 'invalid')
# effect on D
good = [r for r in rows if r.get('maxDD', -1) >= 0]
print('--- wrong designs with a D: %d; |dD| >= .005/.01/.02/.05/.1: %s; tier flips %d; valid tier flips %d' % (len(good), '/'.join(str(sum(1 for r in good if r['maxDD'] >= t)) for t in (.005, .01, .02, .05, .1)), sum(1 for r in good if r['tier']), sum(1 for r in good if r['tier'] and r.get('valid'))))
fam = collections.defaultdict(list)
for r in good:
    fam[r['family']].append(r)
print('--- per family: wrong designs, tier flips (valid), largest |dD|')
ranked = sorted(fam.items(), key=lambda kv: -max(x['maxDD'] for x in kv[1]))
for k, v in ranked:
    v.sort(key=lambda r: -r['maxDD'])
    t = v[0]
    print('%-11s %5d wrong, %4d flips (%d valid), |dD| %.4f %s: %s | %s | build: %s | truth: %s' % (k, len(v), sum(1 for r in v if r['tier']), sum(1 for r in v if r['tier'] and r.get('valid')), t['maxDD'], t['step'], t['name'], [(w['label'], w['shape'], round(w['s']*100, 2), round((w.get('read') or 0)*100, 2), 'kept' if w['kept'] else 'cleaned') for w in t['wrong']][:4], t.get('lineV'), t.get('lineT')))
print('--- per family, false kept and false Enclosed apart: largest |dD| when only one kind is wrong')
for kind, label in ((True, 'false kept'), (False, 'false Enclosed')):
    for k, v in ranked:
        sub = [r for r in v if all(w['kept'] == kind for w in r['wrong'])]
        if sub:
            t = sub[0]
            print('%-14s %-11s %5d, %4d flips, |dD| %.4f %s: %s | %s' % (label, k, len(sub), sum(1 for r in sub if r['tier']), t['maxDD'], t['step'], t['name'], [(w['label'], w['shape'], round(w['s']*100, 2), round((w.get('read') or 0)*100, 2)) for w in t['wrong']][:3]))
print('--- the highest share cleaned among tier flips, per family')
for k, v in ranked:
    best = None
    for r in v:
        if r['tier'] and r.get('valid'):
            for w in r['wrong']:
                if not w['kept'] and (best is None or w['s'] > best[0]):
                    best = (w['s'], r['name'], w['label'], w['shape'], r['maxDD'], r.get('lineV'), r.get('lineT'))
    if best:
        print('%-11s true %.2f%% %s %s %s |dD| %.4f build: %s | truth: %s' % (k, best[0]*100, best[1], best[2], best[3], best[4], best[5], best[6]))
