--!nocheck
-- m2x-fix-3: the plausible ballRivet whose verdict the band witness moves: its parts, and per facet of the rivet what shows
-- under the fixAB + A tree and the build, against each hider
local Lab = require("./lab")
local fmt = string.format
local A, N = Lab.tree(Lab.SCR .. "/m2x-fix-3/var_ABA"), Lab.tree("now")
local PD = (require :: any)(N.root .. "/tests/Physics/PlausibleDesigns")
local d
for _, x in ipairs(PD.all()) do
	if x.name == "ballRivet|F3|guardX d0.10 unrot cap0.3000" then
		d = x
	end
end
local parts = N.renumber(N.copyParts(d.parts))
for i, p in ipairs(parts) do
	print(fmt("%2d %-6s %-8s pos (%.4f, %.4f, %.4f) size (%.4f, %.4f, %.4f)", i, p.slot, p.shape, p.pos[1], p.pos[2], p.pos[3], p.size[1], p.size[2], p.size[3]))
end
for _, T in ipairs({ A, N }) do
	local P = T.prep(parts)
	local models = T.models(P)
	local index, higher = T.hidersOf(P, 8, models)
	local hm = {}
	for k, j in ipairs(index) do
		hm[k] = models[j]
	end
	local m = models[8]
	local shownTotal = 0
	local per = {}
	for f = 1, m.n do
		local b = 6 * (f - 1)
		local one = { part = m.part, round = m.round, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
			area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
			spread = { m.spread[f] }, hull = { m.hull and m.hull[f] }, total = m.area[f], np = 0, planes = {}, sag = { m.sag[f] }, inner = 0,
			reach = m.reach, over = m.over, work = 0 }
		local s = T.Cover.shown(one, hm, higher, math.huge, math.huge)
		per[f] = s
		shownTotal += s
	end
	print(fmt("hiders %s; reads %.4f%%", table.concat(index, ","), 100 * shownTotal / m.total))
	T.per = per
	T.m = m
end
-- the facets that differ
local Qs = N.prep(parts)
for f = 1, N.m.n do
	if math.abs(A.per[f] - N.per[f]) > 1e-12 then
		local poly = N.m.poly[f]
		local sds = {}
		for j = 1, #poly, 3 do
			table.insert(sds, fmt("%.4f", N.Shapes.sd(Qs[4], poly[j], poly[j + 1], poly[j + 2])))
		end
		print(fmt("facet %3d (%.3f%% of the model): ABA shows %.3f%%, build %.3f%%; its vertices' sd to part 4: %s", f,
			100 * N.m.area[f] / N.m.total, 100 * A.per[f] / N.m.area[f], 100 * N.per[f] / N.m.area[f], table.concat(sds, " ")))
	end
end
