# Range fit for S2 v2 (reads out_raw.csv from dump_raw.luau). Hammering = .40 Th + .30 As(All) + .30 SC(All);
# Sharpening = .50 EL + .30 As(Blade) + .20 SC(Blade); Smelting = Volume. Prints the best candidates.
import csv, itertools, sys
rows = list(csv.DictReader(open('out_raw.csv')))
R = {r['name'].split(' ')[0] + ('S' if 'Steel' in r['name'] and r['name'].startswith('C02') else ''): r for r in rows}
def norm(v, lo, hi): return min(1.0, max(0.0, (v - lo) / (hi - lo)))
def q4(x): return round(x * 1e4) / 1e4
def steps(r, p):
    th, thb = float(r['Th_All_%d_%d' % p['sig']]), float(r['Th_Bl_%d_%d' % p['sig']])
    sm = norm(float(r['Vo_All']), *p['vo'])
    ha = .40 * th + .30 * norm(float(r['As_All']), 0, p['as']) + .30 * norm(float(r['SC_All']), *p['sc'])
    sh = .50 * norm(float(r['EL']), *p['el']) + .30 * norm(float(r['As_Bl']), 0, p['as']) + .20 * norm(float(r['SC_Bl']), *p['sc'])
    return q4(sm), q4(ha), q4(sh)
NORMAL15 = ['C02', 'F1', 'F5', 'C12', 'C14']        # arming family: every step <= 0.15
NORMAL = ['C01', 'C07', 'C10', 'C11', 'F2', 'C13']  # plain designs and filler: every step < 0.2
HARD = [('C04', 1), ('C04', 2), ('C06', 1), ('C06', 2), ('C05', 0), ('C05', 2), ('F3', 1), ('F3', 2), ('F4', 0), ('F4', 2)]
WANT = [('C09', 1), ('C08', 2)]                      # desirable Hard: ornate detail, greatsword's long edge
sigs = [(40,130),(45,130),(50,130),(50,140),(55,140),(50,150),(60,150)]
best = []
for sig, sclo, schi, ello, elhi in itertools.product(sigs, [2.10,2.15,2.20,2.25,2.30], [2.9,3.0,3.1], [4.0,4.5,4.6,4.8,5.0], [9.0,9.5,10.0,11.0]):
    p = dict(sig=sig, sc=(sclo, schi), el=(ello, elhi), vo=(0.08, 0.80), **{'as': 0.6})
    m15 = min(0.15 - max(steps(R[k], p)) for k in NORMAL15)
    mN = min(0.2 - 1e-9 - max(steps(R[k], p)) for k in NORMAL)
    mH = min(steps(R[k], p)[i] - 0.2 for k, i in HARD)
    mW = min(steps(R[k], p)[i] - 0.2 for k, i in WANT)
    ok = m15 >= 0 and mN > 0 and mH >= 0
    best.append((ok, min(m15, mH), mW, p, m15, mH))
best.sort(key=lambda t: (t[0], t[0] and t[2] >= 0, round(t[1], 4), t[2]), reverse=True)
for ok, score, mW, p, m15, mH in best[:12]:
    print(ok, 'min(m15,mH)=%.4f' % score, 'want=%.4f' % mW, 'm15=%.4f mH=%.4f' % (m15, mH), p['sig'], p['sc'], p['el'])
if len(sys.argv) > 1:
    pass

def show(title, pred, key):
    c = [b for b in best if b[0] and pred(b)]
    c.sort(key=key, reverse=True)
    print('\n==', title, len(c))
    for ok, score, mW, p, m15, mH in c[:5]:
        print('  m15=%.4f mH=%.4f want=%.4f' % (m15, mH, mW), p['sig'], p['sc'], p['el'])
show('(a) max arming margin, mH >= 0.05', lambda b: b[5] >= 0.05, lambda b: b[4])
show('(b) max min(m15, mH)', lambda b: True, lambda b: b[1])
show('(c) want >= 0.02, max min(m15,mH)', lambda b: b[2] >= 0.02, lambda b: b[1])
show('(d) want >= 0.0, el lo<=4.6, max m15', lambda b: b[2] >= 0.0 and b[3]['el'][0] <= 4.6, lambda b: b[4])
