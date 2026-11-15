#!/usr/bin/env python
"""m2r5: per family: false Enclosed by band and shape, false kept, and the effect on D. usage: summ_fam.py variant [set]"""
import sys
from collections import defaultdict
from summ import load, merged, bandline, fmt_band, SHAPES, BANDS


def main():
    v = sys.argv[1]
    st = sys.argv[2] if len(sys.argv) > 2 else 'plausible'
    top = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    data = load()
    m = merged(data[v][st])
    fams = sorted(set(list(m['fe'].keys()) + list(m['fk'].keys()) + [e['family'] for e in m['effects']]))
    print('%s on %s: family | false Enclosed >= 2.5 3 5 7.5 10 15 20 | false kept < 1.5, < 1 | rows, |dD| >= .005, .02, tier flips' % (v, st))
    for fam in fams:
        t = bandline(m['fe'], None, fam)
        k = bandline(m['fk'], None, fam)
        eff = [e for e in m['effects'] if e['family'] == fam]
        print('%-14s | %s | %5d %5d | %5d %5d %5d %5d' % (fam, fmt_band(t), k.get('0.015', 0), k.get('0.01', 0), len(eff), sum(1 for e in eff if e['maxDD'] >= .005), sum(1 for e in eff if e['maxDD'] >= .02), sum(1 for e in eff if e['tierFlip'])))
        for sh in SHAPES:
            ts = bandline(m['fe'], sh, fam)
            ks = bandline(m['fk'], sh, fam)
            if ts or ks:
                print('   %-11s | %s | %5d %5d' % (sh, fmt_band(ts), ks.get('0.015', 0), ks.get('0.01', 0)))
        for e in eff[:top]:
            w = ', '.join('%s %s %.2f%% %s' % (x['label'], x['shape'], x['s'] * 100, 'kept' if x['kept'] else 'cleaned') for x in e['wrong'][:3])
            print('      |dD| %.4f%s %s: %s; %s' % (e['maxDD'], ' TIER' if e['tierFlip'] else '', e['name'], w, ' '.join('%.4f>%.4f' % (a, b) for a, b in zip(e['dt'], e['dv']))))


if __name__ == '__main__':
    main()
