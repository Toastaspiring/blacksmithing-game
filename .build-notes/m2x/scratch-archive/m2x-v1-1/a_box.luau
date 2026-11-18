--!nocheck
-- Cover's per-facet box test (margin HIDE_OFFSET + 2·EPS against the hider's AABB) against §4.4's hide test without it
-- (mybrute): round parts probe HIDE_OFFSET + sag, round hiders' probe half-spaces stand past their AABB.
local process = require("@lune/process")
local L = require("./lib")
local MB = require("./mybrute")
MB.init(L.Geo)
local Cover, Shapes = L.Cover, L.Shapes
local Geo = L.Geo
local fmt = string.format
local Attacks = require("./repo/tests/Physics/CoverAttacks")
local which = process.args[1] or "attacks"
local designs = {}
if which == "attacks" then
	for _, d in ipairs(Attacks) do table.insert(designs, { name = d.name, parts = L.copyParts(d.parts) }) end
elseif which == "fixtures" then
	for _, list in ipairs({ L.Fx.calibration(), L.Fx.golden(), L.Fx.perf(), L.Fx.regression() }) do
		for _, b in ipairs(list) do
			local parts = b.parts or (b.fixture and b.fixture.parts)
			if parts then table.insert(designs, { name = b.name or b.fixture.name, parts = L.copyParts(parts) }) end
		end
	end
	for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do table.insert(designs, { name = id, parts = L.repoFixture(id) }) end
else
	local PD = require("./repo/tests/Physics/PlausibleDesigns")
	local step = tonumber(process.args[2]) or 10
	local off = tonumber(process.args[3]) or 0
	for k, d in ipairs(PD.all()) do
		if k % step == off then table.insert(designs, { name = d.name, parts = L.copyParts(d.parts) }) end
	end
end
local nParts, nDiff, flips, worst, worstName = 0, 0, 0, 0, ""
for _, d in ipairs(designs) do
	local parts = L.renumber(d.parts)
	local P = L.prep(parts)
	local _, order = L.Sampling.ranked(P)
	local isCopy = {}
	for r = 2, #order do isCopy[order[r].index] = Shapes.sameSolid(order[r], order[r - 1]) end
	local models = {}
	for i = 1, #P do
		if not isCopy[i] and P[i].volume >= Geo.MIN_PART_VOLUME then models[i] = Cover.model(P[i]) end
	end
	for i = 1, #P do
		local m = models[i]
		if m and (m.round or true) then
			local index, higher = L.hidersOf(P, i)
			local hm = {}
			for k, j in ipairs(index) do hm[k] = models[j] end
			local c = Cover.shown(m, hm, higher, math.huge, math.huge)
			local b = 0
			for f = 1, m.n do
				local s = MB.facetShown(m, f, hm, higher)
				if s == nil then b = nil; break end
				b += s
			end
			nParts += 1
			if b then
				local diff = (c - b) / m.total
				if math.abs(diff) > 1e-9 then
					nDiff += 1
					local flip = (c >= 0.02 * m.total) ~= (b >= 0.02 * m.total)
					if flip then flips += 1 end
					if math.abs(diff) > worst then
						worst, worstName = math.abs(diff), fmt("%s part %d (%s): cover %.4f%%, the model's hide test %.4f%%", d.name, i, parts[i].shape, 100 * c / m.total, 100 * b / m.total)
					end
					if flip or math.abs(diff) > 0.005 then
						print(fmt("  %s part %d (%s): cover %.4f%%, hide test %.4f%%%s", d.name, i, parts[i].shape, 100 * c / m.total, 100 * b / m.total, if flip then "  VERDICT FLIPS" else ""))
					end
				end
			end
		end
	end
end
print(fmt("%s: %d designs, %d parts; %d read differently from the hide test (> 1e-9 of the area), %d verdicts flip; worst %.4f of a part: %s", which, #designs, nParts, nDiff, flips, worst, worstName))
