#!/usr/bin/env python
"""m2r5: merges out/eval/<variant>.<set>.<shard>.json into tables. usage: summ.py [--brief] [variants...]"""
import glob
import json
import os
import re
import sys
from collections import defaultdict

BANDS = ['0.025', '0.03', '0.05', '0.075', '0.1', '0.15', '0.2']
SHAPES = ['Block', 'Wedge', 'CornerWedge', 'Cylinder', 'Ball']
SETS = ['fixtures', 'plausible', 'fuzz', 'poke']


def load():
    data = defaultdict(lambda: defaultdict(list))
    for path in glob.glob('out/eval/*.json'):
        name = os.path.basename(path)
        m = re.match(r'^(.*)\.(fixtures|plausible|fuzz|poke)\.(\d+)\.json$', name)
        if not m:
            continue
        data[m.group(1)][m.group(2)].append(json.load(open(path)))
    return data


def merged(rows):
    out = {'fe': defaultdict(lambda: defaultdict(lambda: defaultdict(int))), 'fk': defaultdict(lambda: defaultdict(lambda: defaultdict(int))), 'effects': [], 'worst': [], 'parts': 0, 'designs': 0, 'byShape': defaultdict(int), 'near': defaultdict(int), 'emuErrors': 0}
    for r in rows:
        for key in ('fe', 'fk'):
            for fam, a in r[key].items():
                for shape, b in a.items():
                    for band, n in b.items():
                        out[key][fam][shape][band] += n
        out['effects'] += r['effects'] if r['effects'] else []
        out['worst'] += r['worstShare'] if r['worstShare'] else []
        out['parts'] += r['counts']['parts']
        out['designs'] += r['counts']['designs']
        out['emuErrors'] += r['emuErrors']
        for s, n in r['counts']['partsByShape'].items():
            out['byShape'][s] += n
        for s, n in (r['counts'].get('nearByShape') or {}).items():
            out['near'][s] += n
    out['effects'].sort(key=lambda x: -x['maxDD'])
    out['worst'].sort(key=lambda x: -x['s'])
    return out


def bandline(fe, shape=None, fam=None):
    t = defaultdict(int)
    for f, a in fe.items():
        if fam and f != fam:
            continue
        for sh, b in a.items():
            if shape and sh != shape:
                continue
            for band, n in b.items():
                t[band] += n
    return t


def fmt_band(t, bands=BANDS):
    return ' '.join('%6d' % t.get(b, 0) for b in bands)


def main():
    brief = '--brief' in sys.argv
    wanted = [a for a in sys.argv[1:] if not a.startswith('--')]
    data = load()
    names = wanted or sorted(data.keys())
    print('false Enclosed: cleaned, true share at or above  2.5    3      5      7.5    10     15     20 % | false kept: true share below 1.5, 1 %')
    for v in names:
        if v not in data:
            continue
        print('== %s' % v)
        grand = defaultdict(int)
        gk = defaultdict(int)
        for st in SETS:
            if st not in data[v]:
                continue
            m = merged(data[v][st])
            t = bandline(m['fe'])
            k = bandline(m['fk'])
            for b, n in t.items():
                grand[b] += n
            for b, n in k.items():
                gk[b] += n
            print('  %-10s %6d designs %6d parts | %s | %6d %6d' % (st, m['designs'], m['parts'], fmt_band(t), k.get('0.015', 0), k.get('0.01', 0)))
            if brief:
                continue
            for sh in SHAPES:
                ts, ks = bandline(m['fe'], sh), bandline(m['fk'], sh)
                if ts or ks:
                    print('    %-12s %14d parts | %s | %6d %6d' % (sh, m['byShape'].get(sh, 0), fmt_band(ts), ks.get('0.015', 0), ks.get('0.01', 0)))
        print('  %-10s %29s | %s | %6d %6d' % ('TOTAL', '', fmt_band(grand), gk.get('0.015', 0), gk.get('0.01', 0)))
        # D effects
        for st in SETS:
            if st not in data[v]:
                continue
            m = merged(data[v][st])
            eff = m['effects']
            n = len(eff)
            tier = sum(1 for e in eff if e['tierFlip'])
            ge = lambda x: sum(1 for e in eff if e['maxDD'] >= x)
            feEff = [e for e in eff if any(not w['kept'] for w in e['wrong'])]
            tierFE = sum(1 for e in feEff if e['tierFlip'])
            print('  effect on D %-10s rows %5d: |dD| >= .001 %5d, .005 %5d, .01 %5d, .02 %5d, .05 %5d; tier flips %4d (with a false Enclosed %4d)' % (st, n, ge(.001), ge(.005), ge(.01), ge(.02), ge(.05), tier, tierFE))
            if not brief:
                for e in eff[:6]:
                    w = ', '.join('%s %s %.2f%% %s' % (x['label'], x['shape'], x['s'] * 100, 'kept' if x['kept'] else 'cleaned') for x in e['wrong'][:3])
                    print('     |dD| %.4f%s %s: %s; %s' % (e['maxDD'], ' TIER' if e['tierFlip'] else '', e['name'], w, ' '.join('%.4f>%.4f' % (a, b) for a, b in zip(e['dt'], e['dv']))))
        if not brief:
            for st in SETS:
                if st not in data[v]:
                    continue
                m = merged(data[v][st])
                for w in m['worst'][:5]:
                    print('  worst share %-9s %5.2f%% %-11s %-10s %s' % (st, w['s'] * 100, w['shape'], w['label'], w['name']))


if __name__ == '__main__':
    main()
