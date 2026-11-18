--!nocheck
-- A search for a verdict the per-facet box test flips: a Ball in 6 axis walls (gap g, may cut in) and 12 edge blocks
-- (burying where two coordinates pass b); Cover's reading against the model's hide test (mybrute) and the truth.
local process = require("@lune/process")
local L = require("./lib")
local MB = require("./mybrute")
MB.init(L.Geo)
local Cover = L.Cover
local fmt = string.format
local seed = tonumber(process.args[1]) or 1
local N = tonumber(process.args[2]) or 300
math.randomseed(seed)
local function cage(r, g, b, wallT, wallS, rot)
	local parts = {}
	local c = { 0, 2.5, 0 }
	table.insert(parts, L.part("Pommel", "Ball", c, L.I, { 2 * r, 2 * r, 2 * r }))
	for a = 1, 3 do
		for _, s in ipairs({ -1, 1 }) do
			local pos = { c[1], c[2], c[3] }
			pos[a] += s * (r + g + wallT / 2)
			local size = { wallS, wallS, wallS }
			size[a] = wallT
			table.insert(parts, L.part("Blade", "Block", pos, L.I, size))
		end
	end
	local E = r + 0.06
	for a = 1, 3 do
		for bb = a + 1, 3 do
			for _, sa in ipairs({ -1, 1 }) do
				for _, sb in ipairs({ -1, 1 }) do
					local lo, hi = { -E, -E, -E }, { E, E, E }
					if sa > 0 then lo[a] = b else hi[a] = -b end
					if sb > 0 then lo[bb] = b else hi[bb] = -b end
					local pos, size = {}, {}
					for k = 1, 3 do
						pos[k] = c[k] + (lo[k] + hi[k]) / 2
						size[k] = hi[k] - lo[k]
					end
					table.insert(parts, L.part("Guard", "Block", pos, L.I, size))
				end
			end
		end
	end
	return L.renumber(parts)
end
local best = { 0 }
local flips = 0
for t = 1, N do
	local r = ({ 0.05, 0.08, 0.1, 0.15, 0.2, 0.28 })[math.random(1, 6)]
	local g = -0.012 + 0.024 * math.random()
	local b = r * (0.15 + 0.42 * math.random())
	local parts = cage(r, g, b, 0.02, 2 * r + 0.1, nil)
	local P = L.prep(parts)
	local models = {}
	for i = 1, #P do models[i] = Cover.model(P[i]) end
	local index, higher = L.hidersOf(P, 1)
	local hm = {}
	for k, j in ipairs(index) do hm[k] = models[j] end
	local m = models[1]
	local c = Cover.shown(m, hm, higher, math.huge, math.huge) / m.total
	local bsum = 0
	for f = 1, m.n do bsum += MB.facetShown(m, f, hm, higher) end
	local bb = bsum / m.total
	local diff = c - bb
	if c >= 0.02 and bb < 0.02 then
		flips += 1
		local truth = L.Oracle.share(P, 1, (function() local _, _, h = L.Oracle.flags(P) return h end)())
		print(fmt("FLIP r %.2f g %.6f b %.6f: cover %.3f%%, hide test %.3f%%, truth %.3f%%", r, g, b, 100 * c, 100 * bb, 100 * truth))
	end
	if diff > best[1] then best = { diff, r, g, b, c, bb } end
end
print(fmt("seed %d: %d cages; Cover above the hide test by up to %.4f (r %.2f g %.5f b %.4f: cover %.3f%%, hide test %.3f%%); verdicts flipped %d", seed, N, best[1], best[2] or 0, best[3] or 0, best[4] or 0, 100 * (best[5] or 0), 100 * (best[6] or 0), flips))
