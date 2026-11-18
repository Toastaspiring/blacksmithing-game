# The judge's climbed designs for timing: the best design of each jclimb seed and the 2 best of the time climb.
import json
out = []
for s in (1, 2, 3, 4):
    try:
        d = json.load(open('out/jclimb_%d.json' % s))
    except Exception as e:
        print('seed', s, 'missing', e); continue
    d.sort(key=lambda e: -e['score'])
    from collections import Counter
    e = d[0]
    c = Counter(p['shape'] for p in e['parts'])
    out.append({'name': 'judge climb seed %d best %d units' % (s, e['score']), 'parts': e['parts']})
    print(s, e['score'], dict(c))
t = json.load(open('out/jtime_5.json'))
t.sort(key=lambda e: -e['score'])
for e in t[:2]:
    out.append({'name': 'judge time climb %.1f ms (load)' % (e['score'] / 1000), 'parts': e['parts']})
json.dump(out, open('out/judge_worst.json', 'w'))
print(len(out), 'designs')
