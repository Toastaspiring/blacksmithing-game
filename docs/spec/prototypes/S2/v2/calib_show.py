import csv, sys
exec(open('calib.py').read().split('NORMAL15')[0])
for sig, sc, el in [((50,150),(2.25,3.0),(5.0,9.5)), ((55,140),(2.25,2.9),(5.0,9.5)), ((50,140),(2.25,3.0),(5.0,9.5))]:
    p = dict(sig=sig, sc=sc, el=el, vo=(0.08,0.80), **{'as':0.6})
    print('\n== sigma', sig, 'SC', sc, 'EL', el)
    for k, r in R.items():
        s = steps(r, p)
        print('  %-5s %-48s Sm %.4f  Ha %.4f  Sh %.4f  %s' % (k, r['name'][:48], s[0], s[1], s[2], '/'.join('H' if v >= 0.2 else 'N' for v in s)))
