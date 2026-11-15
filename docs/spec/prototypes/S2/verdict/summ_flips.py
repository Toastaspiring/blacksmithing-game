#!/usr/bin/env python
"""m2r5: the flip searches per variant."""
import glob
import os
import re
import sys
from collections import defaultdict


def main():
    names = sys.argv[1:]
    if not names:
        names = sorted({os.path.basename(p).split('.')[1] if not os.path.basename(p).startswith('rand') else os.path.basename(p).split('.')[1] for p in glob.glob('out/flips/*.txt')})
    for v in names:
        # X placements
        xp, designs, windows, flips, tiers = 0, 0, 0, 0, 0
        rows = []
        missing = 0
        for path in glob.glob('out/flips/x.%s.*.txt' % glob.escape(v)):
            txt = open(path, encoding='utf-8', errors='replace').read()
            m = re.search(r'(\d+) X placements, (\d+) designs tested, (\d+) with a window, (\d+) flips', txt)
            if not m:
                missing += 1
                continue
            xp += int(m.group(1)); designs += int(m.group(2)); windows += int(m.group(3)); flips += int(m.group(4))
            t = re.search(r'tier flips: (\d+)', txt)
            tiers += int(t.group(1)) if t else 0
            for line in txt.splitlines():
                if ' host ' in line:
                    rows.append(line)
        lam = ''
        lamrows = []
        p = 'out/flips/lam.%s.txt' % v
        if os.path.exists(p):
            txt = open(p, encoding='utf-8', errors='replace').read()
            m = re.search(r'\s(\d+)\s+designs\s+(\d+)\s+flips', txt)
            t = re.search(r'tier flips\s+(\d+)', txt)
            lam = '%s designs, %s flips, %s tier flips' % (m.group(1), m.group(2), t.group(1)) if m and t else 'unfinished'
            lamrows = [l for l in txt.splitlines() if l.startswith('w ')]
        rd, rflips, rtier, rmeas = 0, 0, 0, 0
        rrows = []
        for path in glob.glob('out/flips/rand.%s.*.txt' % glob.escape(v)):
            txt = open(path, encoding='utf-8', errors='replace').read()
            m = re.search(r'(\d+) designs in \d+ s; a part of K flipped by the filler: (\d+) designs, measured (\d+), tier flips (\d+)', txt)
            if m:
                rd += int(m.group(1)); rflips += int(m.group(2)); rmeas += int(m.group(3)); rtier += int(m.group(4))
            rrows += [l for l in txt.splitlines() if l.strip().startswith('flip:')]
        print('%-10s X placements: %d placements, %d designs, %d windows, %d flips, %d tier flips%s | laminates: %s | random fill: %d designs, %d flips (measured %d), %d tier flips' % (v, xp, designs, windows, flips, tiers, ' (%d unfinished)' % missing if missing else '', lam, rd, rflips, rmeas, rtier))
        rows.sort(key=lambda l: -float(re.search(r'\|dD\| ([\d.]+)', l).group(1)))
        for l in rows[:4]:
            print('    X   ', l[:230])
        for l in lamrows[:3]:
            print('    lam ', l[:200])
        rrows.sort(key=lambda l: -float(re.search(r'\|dD\| ([\d.]+)', l).group(1)))
        for l in rrows[:5]:
            print('    rand', l.strip()[:180])


if __name__ == '__main__':
    main()
