import itertools
exec(open('calib.py').read().split('sigs = ')[0])
sigs = [(40,130),(45,130),(50,130),(50,140),(55,140),(50,150),(60,150)]
res = []
for sig, sclo, schi, ello, elhi in itertools.product(sigs, [2.2,2.25,2.3,2.35], [2.9,3.0], [4.2,4.4,4.5,4.6,4.8], [8.0,8.5,9.0,9.5]):
    p = dict(sig=sig, sc=(sclo, schi), el=(ello, elhi), vo=(0.08, 0.80), **{'as': 0.6})
    m15 = min(0.15 - max(steps(R[k], p)) for k in NORMAL15)
    mN = min(0.2 - 1e-9 - max(steps(R[k], p)) for k in NORMAL)
    mH = min(steps(R[k], p)[i] - 0.2 for k, i in HARD)
    mW = min(steps(R[k], p)[i] - 0.2 for k, i in WANT)
    if m15 >= 0 and mN > 0 and mH >= 0:
        res.append((min(m15, mH, mW), m15, mH, mW, p))
res.sort(key=lambda t: t[0], reverse=True)
for s, m15, mH, mW, p in res[:10]:
    print('min %.4f | arming max %.4f (m15 %.4f) hardMin %.4f wantMin %.4f |' % (s, 0.15 - m15, m15, 0.2 + mH, 0.2 + mW), p['sig'], p['sc'], p['el'])
