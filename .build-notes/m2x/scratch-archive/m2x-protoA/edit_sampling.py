p='repo/src/shared/Physics/Sampling.luau'
s=open(p,encoding='utf-8',newline='').read()
nl = '\r\n' if '\r\n' in s else '\n'
lines=s.split(nl)
def idx(marker, start=0):
    for i in range(start,len(lines)):
        if marker in lines[i]:
            return i
    raise Exception(marker)
a = idx('-- A line through a flat patch, in the frame of each near part')
b = idx('-- the verdict: each part on a grid of its own')
c = idx('-- the measure: the kept parts, against kept parts only')
new_verdict = '''	-- the verdict: each part's model against every part but exact copies and Dust that comes within reach, in rank order,
	-- until it shows ENCLOSED_EXPOSED_MAX of its model's area (Physics/Cover). How many other parts there are changes
	-- nothing it looks at, so hidden parts cannot change a verdict by using anything up; only a part that covers another can.
	local kept: { boolean } = table.create(N, false)
	local cleaned: { Cleaned } = {}
	local hider: { boolean } = table.create(N, false)
	local models: { Cover.Model } = table.create(N)
	for i = 1, N do
		hider[i] = not isCopy[i] and parts[i].volume >= Geo.MIN_PART_VOLUME
		if hider[i] then
			models[i] = Cover.model(parts[i])
			work(UNITS_PER_SAMPLE * models[i].n)
		end
	end
	local reach = delta + 2 * eps
	for i = 1, N do
		local p = parts[i]
		if p.volume < Geo.MIN_PART_VOLUME then
			table.insert(cleaned, { partId = p.id, reason = "Dust" :: CleanReason })
		elseif isCopy[i] then
			table.insert(cleaned, { partId = p.id, reason = "Enclosed" :: CleanReason })
		else
			local cand: { Cover.Model } = {}
			local higher: { boolean } = {}
			local own = rank[i]
			for r = 1, N do
				local q = byRank[r]
				local j = q.index
				if j ~= i and hider[j] and aabbOverlap(p, q, reach) then
					table.insert(cand, models[j])
					table.insert(higher, r < own)
				end
			end
			work(N)
			local need = Geo.ENCLOSED_EXPOSED_MAX * models[i].total
			if Cover.shown(models[i], cand, higher, need, work) >= need then
				kept[i] = true
			else
				table.insert(cleaned, { partId = p.id, reason = "Enclosed" :: CleanReason })
			end
		end
	end
'''.split('\n')
out = lines[:a] + new_verdict + lines[c:]
open(p,'w',encoding='utf-8',newline='').write(nl.join(out))
print('removed lines', a, 'to', c, 'replaced with', len(new_verdict))
