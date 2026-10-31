# Formats the E-S3.2 main table from out/final_table.txt (helper for the appendix; prints Markdown rows).
import re, sys
txt = open(sys.argv[1], encoding='utf-8').read()
rows = []
for line in txt.splitlines():
    m = re.match(r'(HoldZone|TimingStrike|PrecisionTrace) (Iron|Steel)/(Normal|Hard) \| (.*)', line)
    if not m or 'Perfect' in line or 'Avg@30' in line:
        continue
    fam, mat, tier, rest = m.groups()
    cells = []
    for part in rest.split(' | '):
        pm = re.match(r'(Elite|Good|Average|Poor) ([\d.]+) ([\d.]+) \[([\d.]+) ([\d.]+) ([\d.]+)\]\s+([\d.]+)%', part.strip())
        prof, mean, sd, p10, p50, p90, pas = pm.groups()
        cells.append('%s ± %s [%s–%s] %.1f' % (mean, sd, p10, p90, 100 - float(pas)))
    rows.append('| %s %s/%s | %s |' % (fam, mat, tier, ' | '.join(cells)))
out = open(sys.argv[2], 'w', encoding='utf-8')
out.write('\n'.join(rows) + '\n')
out.close()
