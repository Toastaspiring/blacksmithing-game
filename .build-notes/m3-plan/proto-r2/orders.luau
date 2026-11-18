--!nocheck
-- m3-plan-r2: order dependence of M3 through the emulator (§17.2: "C09 in 300 random orders ... Hammering 0.3170–0.3195;
-- P5 Hammering 0.1853–0.1902 in 60"). For each fixture, n random permutations of its parts (ids kept; xorshift32 seeds
-- 0x5EED0100 + k): the emulator walking the permuted list (today's part order), and walking the measure's rank order
-- (Sampling.measureRanked of the permuted list). Prints per step the d range in part order, how many distinct outcomes
-- (every factor raw, d, edge length, chains, bladeArea, mean thickness and the difficulty frame's grip point, to the bit)
-- each walk gives, and whether the rank-order walk equals the rank order of the fixture's own list.
--   lune run <abs>/proto/orders.luau -- <n> <id> [<id> ...]
local L = require("./lib")
local process = require("@lune/process")
local fmt = string.format

local n = tonumber(process.args[1]) or 20
local ids = {}
for i = 2, #process.args do
	table.insert(ids, process.args[i])
end

local function key(R)
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%.17g", s.d))
		for _, f in ipairs(s.factors) do
			table.insert(t, fmt("%.17g", f.raw))
		end
	end
	local e = R.edge
	table.insert(t, fmt("%.17g|%d|%.17g|%.17g|%.17g|%.17g|%.17g", e.length, #e.chains, e.bladeArea, e.bladeMeanThickness,
		e.gripPoint[1], e.gripPoint[2], e.gripPoint[3]))
	for _, c in ipairs(e.chains) do
		for _, p in ipairs(c.points) do
			table.insert(t, fmt("%.17g,%.17g", p[1], p[2]))
		end
	end
	return table.concat(t, ";")
end

for _, id in ipairs(ids) do
	local b = L.find(id)
	local base = L.run(L.inRankOrder(b))
	local baseKey = key(base)
	local lo, hi = { 1, 1, 1 }, { 0, 0, 0 }
	local partKeys, rankKeys, nPart, nRank = {}, {}, 0, 0
	local rankEqualsBase = true
	local t0 = os.clock()
	for k = 1, n do
		local p = L.shuffled(b, 0x5EED0100 + k)
		local A = L.run(p)
		local B = L.run(L.inRankOrder(p))
		for s = 1, 3 do
			lo[s] = math.min(lo[s], A.steps[s].d)
			hi[s] = math.max(hi[s], A.steps[s].d)
		end
		local ka, kb = key(A), key(B)
		if not partKeys[ka] then
			partKeys[ka] = true
			nPart += 1
		end
		if not rankKeys[kb] then
			rankKeys[kb] = true
			nRank += 1
		end
		if kb ~= baseKey then
			rankEqualsBase = false
		end
	end
	local da, _ = L.dline(base)
	print(fmt("%-6s %d orders: part order Sm %.4f–%.4f Ha %.4f–%.4f Sh %.4f–%.4f, %d distinct outcomes | rank order %d distinct, %s (%s) | %.1f s",
		id, n, lo[1], hi[1], lo[2], hi[2], lo[3], hi[3], nPart, nRank, if rankEqualsBase then "= the fixture's own rank order" else "DIFFERS",
		da, os.clock() - t0))
end
