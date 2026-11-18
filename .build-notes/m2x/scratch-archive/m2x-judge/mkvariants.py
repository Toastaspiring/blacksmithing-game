# Builds the judge's timing variants of Physics/Sampling: full and verdict-only copies of today's (repo/), A's and B's,
# with their requires pointed back at their own repo copies. Only the requires and (for the V copies) the measure change.
import os

J = os.path.dirname(os.path.abspath(__file__))
SRC = {
    'today': ('repo', os.path.join(J, 'repo', 'src', 'shared', 'Physics', 'Sampling.luau')),
    'A': ('../m2x-protoA/repo', os.path.join(J, '..', 'm2x-protoA', 'repo', 'src', 'shared', 'Physics', 'Sampling.luau')),
    'B': ('../m2x-protoB/repo', os.path.join(J, '..', 'm2x-protoB', 'repo', 'src', 'shared', 'Physics', 'Sampling.luau')),
}
RET = '\treturn { kept = kept, cleaned = cleaned, hSurf = 0, surfSamples = 0, subSampled = 0, exposedKept = {}, contact = {} } :: any\n'
for name, (rel, path) in SRC.items():
    s = open(path, encoding='utf-8').read()
    base = '../../' + rel + '/src/shared/'
    s = s.replace('require("../Definitions/Balance")', 'require("%sDefinitions/Balance")' % base)
    s = s.replace('require("../Definitions/Limits")', 'require("%sDefinitions/Limits")' % base)
    s = s.replace('require("./Shapes")', 'require("%sPhysics/Shapes")' % base)
    s = s.replace('require("./Cover")', 'require("%sPhysics/Cover")' % base)
    assert 'require("./' not in s and 'require("../D' not in s, name
    a = s.index('\t-- the measure: the kept parts, against kept parts only')
    b = s.index('\treturn {\n\t\thSurf = hSurf', a)
    e = s.index('\t}\n', b) + 3
    assert s[e:e + 4] == 'end\n', repr(s[e:e + 20])
    verdictOnly = s[:a] + RET + s[e:]
    for v, text in ((name, s), (name + 'V', verdictOnly)):
        d = os.path.join(J, 'v', v)
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, 'Sampling.luau'), 'w', encoding='utf-8').write(text)
        print(v, len(text.splitlines()), 'lines')

# A's model options: canonical frames, and canonical + sagitta <= 0.002 (A's 'fine')
for v, opt in (('Acanon', '{ canon = true }'), ('Afine', '{ canon = true, sag = 0.002 }')):
    for suffix in ('', 'V'):
        s = open(os.path.join(J, 'v', 'A' + suffix, 'Sampling.luau'), encoding='utf-8').read()
        old = 'local MODEL: Cover.ModelOptions? = nil'
        assert old in s
        s = s.replace(old, 'local MODEL: Cover.ModelOptions? = ' + opt)
        d = os.path.join(J, 'v', v + suffix)
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, 'Sampling.luau'), 'w', encoding='utf-8').write(s)
        print(v + suffix)
