"""Collect M1's open items into docs/build/M1-notes.md, so later milestones read them (they would otherwise be lost
with the workflow output). Each item is the agent's own words."""
import io, json, os, sys

task = sys.argv[1]
out = sys.argv[2]
d = json.load(io.open(task, encoding='utf-8'))['result']
L = ['# M1 build notes', '',
     'Open items and deviations reported while building M1 (data contracts), verbatim from the builders, fixer and',
     'verifiers. Read the part for your milestone before building it. The items are point-in-time, so check them against',
     'the code and SPEC.md; strike what is done.', '']
names = ['B1 Definitions core', 'B2 Definitions feature data', 'B3 Util and Blueprint', 'B4 Fixtures, Gen, M0 carry-overs']
for name, b in zip(names, d['builds']):
    L += [f'## {name}', '']
    for head, key in (('Open issues', 'openIssues'), ('Deviations from the SPEC', 'deviations')):
        if b.get(key):
            L += [f'**{head}**', ''] + [f'- {x}' for x in b[key]] + ['']
for i, f in enumerate(d['fixes']):
    if f and f.get('openIssues'):
        L += [f'## Fix round {i + 1}', ''] + [f'- {x}' for x in f['openIssues']] + ['']
L += ['## Verifier notes with no M1 action', '',
      '- A SPEC evidence mismatch for M7: E-S8.4 and E-S8.6 summarize A10–A12 and A19 as E_INVALID_BLUEPRINT, but the '
      'fixtures follow the normative §3.5, §3.6 and §10.3 (A10 and A19-IdNaN answer E_BAD_REQUEST with a Hard strike, as '
      'does A19-Array at depth 5; A12\'s sloppy variants are renormalized and stored). S-E2E-04 must assert each '
      'variant\'s `save` field, not the evidence summary.',
      '- `Canonical.draft` throws on a table whose metatable traps `__index` or `__len`. Remotes should strip metatables '
      '(from knowledge of Roblox, not tested): confirm in M7.',
      '- `Canonical.draft` silently drops keys past the array part of `parts` and extra tuple keys; the output is still a '
      'clean rebuilt draft.',
      '- §3.10\'s "+54 B" Save envelope is S1\'s size of `{blueprintId}`; the exact JSON overhead is 63 B (T-BP-05 asserts '
      'it). No budget is affected.', '']
os.makedirs(os.path.dirname(out), exist_ok=True)
io.open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(L))
print(len(L), 'lines')
