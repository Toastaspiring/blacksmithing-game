import json, sys
d = json.load(open(sys.argv[1]))
def walk(n, ind=0):
    print('  '*ind + n['name'] + ' (' + n['className'] + ')')
    for c in n.get('children', []): walk(c, ind+1)
walk(d)
