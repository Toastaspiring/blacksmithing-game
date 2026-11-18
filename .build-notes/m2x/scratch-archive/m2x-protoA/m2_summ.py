# M2 summary: false Enclosed / false kept per reading and target shape, from m2_eval rows. args: glob [label]
import json, glob, sys, collections
files = sorted(glob.glob(sys.argv[1]))
rows, errors = [], []
for f in files:
    for line in open(f, encoding='utf-8'):
        line = line.strip()
        if not line: continue
        r = json.loads(line)
        if 'error' in r: errors.append(r); continue
        rows.append(r)
E = [0.025, 0.03, 0.05, 0.075, 0.10, 0.15, 0.20]
K = [0.015, 0.01, 0.005, 0.0025]
READ = [('old', 'vo', None), ('base', 'vb', 'rb'), ('canon', 'vc', 'rc'), ('fine', 'vf', 'rf')]
designs = len(set(r['d'] for r in rows))
print('%s: %d designs, %d parts, %d design errors, files %d' % (sys.argv[2] if len(sys.argv) > 2 else sys.argv[1], designs, len(rows), len(errors), len(files)))
for e in errors[:5]: print('  ERROR', e['d'], e['error'][:200])
shapes = sorted(set(r['shape'] for r in rows))
for name, v, rd in READ:
    print('== reading %s' % name)
    tot_e = [0] * len(E); tot_k = [0] * len(K)
    for sh in shapes + ['ALL']:
        sel = [r for r in rows if sh == 'ALL' or r['shape'] == sh]
        fe = [sum(1 for r in sel if (not r[v]) and r['t'] >= b) for b in E]
        fk = [sum(1 for r in sel if r[v] and r['t'] < b) for b in K]
        hi = max([r['t'] for r in sel if not r[v]] or [0])
        lo = min([r['t'] for r in sel if r[v]] or [1])
        print('  %-11s parts %6d  false Enclosed at >= 2.5/3/5/7.5/10/15/20 %%: %s   false kept at < 1.5/1/0.5/0.25 %%: %s   highest cleaned %.2f %%, lowest kept %.3f %%'
              % (sh, len(sel), '/'.join(map(str, fe)), '/'.join(map(str, fk)), hi * 100, lo * 100))
    # the worst
    wrongE = sorted([r for r in rows if not r[v] and r['t'] >= 0.025], key=lambda r: -r['t'])[:6]
    wrongK = sorted([r for r in rows if r[v] and r['t'] < 0.015], key=lambda r: r['t'])[:6]
    for r in wrongE: print('    false Enclosed: true %.2f %% read %s  %s part %d (%s)' % (r['t'] * 100, ('%.2f %%' % (r[rd] * 100)) if rd else '-', r['d'][:90], r['i'], r['shape']))
    for r in wrongK: print('    false kept:     true %.3f %% read %s  %s part %d (%s)' % (r['t'] * 100, ('%.3f %%' % (r[rd] * 100)) if rd else '-', r['d'][:90], r['i'], r['shape']))
# reading error vs truth (new readings): largest |read - truth| per shape
for name, v, rd in READ[1:]:
    by = collections.defaultdict(float)
    for r in rows:
        if r.get('f') or r['t'] < 0.3:
            by[r['shape']] = max(by[r['shape']], abs(r[rd] - r['t']))
    print('  |%s read - truth| max by shape (fine-lattice rows): %s' % (name, ', '.join('%s %.4f' % (k, by[k]) for k in sorted(by))))
