p = 'm4_inv.luau'
s = open(p, encoding='utf-8').read()
a = s.index('local res = {')
b = s.index('res.seconds = os.clock() - t0')
body = open('m4_body.luau', encoding='utf-8').read()
s = s[:a] + body + s[b:]
old_verdict = '''local function verdict(parts)
	local P = L.prep(parts)
	local e = Exposure.exposure(P)
	local share, kept, tests, shown = L.newShares(P, mf)
	return e, shown, share, P
end'''
new_verdict = '''local function verdict(parts)
	local P = L.prep(parts)
	local e = Exposure.exposure(P)
	local share, kept, tests, shown = L.newShares(P, mf)
	for i = 1, #P do
		if kept[i] ~= e.kept[i] then error("the full reading disagrees with exposure on part " .. i) end
	end
	return e, shown, share, P
end'''
assert old_verdict in s
s = s.replace(old_verdict, new_verdict)
i = s.index('print(fmt("m4 %s %s shard %d')
j = s.index('\n', s.index('res.dustBad, res.seconds))', i))
s = s[:i] + '''print(fmt("m4 %s %s shard %d: designs %d | orders %d bad %d | mirror images %d: verdict differs without a rank flip %d, with a twin's rank flip %d; max |dshare| without a flip X %.3e (%s), Z %.3e (%s), with a flip %.3e | copies %d bad %d | dust %d bad %d | %.0f s",
	which, modelName, shard, res.designs, res.orderRuns, res.orderBad, res.mirrorRuns, res.mirrorBadVerdict, res.mirrorTwinVerdict, res.mirrorMaxDiff, res.mirrorWorst, res.mirrorMaxDiffZ, res.mirrorWorstZ, res.mirrorTwinMaxDiff, res.copyRuns, res.copyBad, res.dustRuns, res.dustBad, res.seconds))''' + s[j:]
open(p, 'w', encoding='utf-8').write(s)
print('patched')
