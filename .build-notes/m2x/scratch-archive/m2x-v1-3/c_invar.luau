--!nocheck
-- invariance on V1's round-2 tangles: (1) random orders of the parts: kept, cleaned, exposedKept, contact rows, verdictWork
-- bit-identical; (2) an exact copy of a part put first or last, and a Dust speck: every other part's exposure bit-identical;
-- (3) X and Z mirror images: the parts whose verdict differs, by class. lune run c_invar -- <seed> <count>
local process = require("@lune/process")
local L = require("./lib")
local T = require("./tangles")
local TestRng = require("./repo/tests/lib/TestRng")
local fmt = string.format
local seed, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 100
local rng = TestRng.new(seed)
ORDERS = tonumber(process.args[3])
local function exposure(parts)
	L.renumber(parts)
	return L.Sampling.exposure(L.prep(parts))
end
local function same(a, b)
	return a == b
end
local stats = { designs = 0, orderDiff = 0, copyDiff = 0, dustDiff = 0, mirror = 0, mirrorDiff = 0, mirrorRound = 0, mirrorOther = 0 }
local examples = {}
for d = 1, count do
	local parts = T.tangle(rng)
	local N = #parts
	local e0 = exposure(L.copyParts(parts))
	stats.designs += 1
	-- (1) orders
	for k = 1, (ORDERS or 3) do
		local perm = {}
		for i = 1, N do perm[i] = i end
		for i = N, 2, -1 do
			local j = rng:int(1, i)
			perm[i], perm[j] = perm[j], perm[i]
		end
		local sp = {}
		for i = 1, N do sp[i] = L.copyPart(parts[perm[i]]) end
		local e = exposure(sp)
		local bad = e.capped ~= e0.capped or (not e0.capped and e.verdictWork ~= e0.verdictWork) or e.hSurf ~= e0.hSurf
			or e.surfSamples ~= e0.surfSamples or e.subSampled ~= e0.subSampled
		for i = 1, N do
			local o = perm[i]
			if e.kept[i] ~= e0.kept[o] or e.exposedKept[i] ~= e0.exposedKept[o] then bad = true end
			for j = 1, N do
				if e.contact[i][j] ~= e0.contact[o][perm[j]] then bad = true end
			end
		end
		if bad then
			stats.orderDiff += 1
			if #examples < 5 then table.insert(examples, { "order", parts }) end
		end
	end
	-- (2) an exact copy first or last; a Dust speck
	local src = parts[rng:int(1, N)]
	for _, where in ipairs({ "first", "last", "dust" }) do
		local sp = L.copyParts(parts)
		local extra
		if where == "dust" then
			extra = L.part("Guard", "Block", { src.pos[1] + src.size[1] / 2, src.pos[2], src.pos[3] }, L.I, { 0.05, 0.05, 0.05 })
		else
			extra = L.copyPart(src)
		end
		local off = 0
		if where == "first" then
			table.insert(sp, 1, extra)
			off = 1
		else
			table.insert(sp, extra)
		end
		local e = exposure(sp)
		local bad = false
		for i = 1, N do
			local k = i + off
			if e.kept[k] ~= e0.kept[i] or e.exposedKept[k] ~= e0.exposedKept[i] then bad = true end
			for j = 1, N do
				if e.contact[k][j + off] ~= e0.contact[i][j] then bad = true end
			end
		end
		-- the copy itself: an exact copy is cleaned, unless it outranks its original (another slot first): then the
		-- original is; the pair is compared as a class
		if bad and where ~= "dust" then
			-- allowed: the copy took the original's place (same solid); compare with the original's slot swapped
			local allow = true
			for i = 1, N do
				local k = i + off
				if e.exposedKept[k] ~= e0.exposedKept[i] and not L.Shapes.sameSolid(L.Shapes.prepare(parts[i], 1), L.Shapes.prepare(src, 2)) then allow = false end
			end
			if allow then bad = false end
		end
		if bad then
			if where == "dust" then stats.dustDiff += 1 else stats.copyDiff += 1 end
			if #examples < 5 then table.insert(examples, { where, parts }) end
		end
	end
	-- (3) mirrors
	for _, plane in ipairs({ "X", "Z" }) do
		local im = {}
		for i = 1, N do im[i] = L.Mirror.reflect(L.copyPart(parts[i]), plane) end
		local e = exposure(im)
		stats.mirror += N
		for i = 1, N do
			if e.kept[i] ~= e0.kept[i] then
				stats.mirrorDiff += 1
				if parts[i].shape == "Ball" or parts[i].shape == "Cylinder" then stats.mirrorRound += 1 else
					stats.mirrorOther += 1
					print(string.format("MIRROR %s part %d %s", plane, i, require("@lune/serde").encode("json", parts)))
				end
			end
		end
	end
end
print(fmt("seed %d: %d tangles; orders differing %d; copy first/last differing %d; Dust differing %d; mirror verdicts %d of %d part images differ (round %d, other %d)",
	seed, stats.designs, stats.orderDiff, stats.copyDiff, stats.dustDiff, stats.mirrorDiff, stats.mirror, stats.mirrorRound, stats.mirrorOther))
for _, ex in ipairs(examples) do
	print("EXAMPLE " .. ex[1] .. " " .. require("@lune/serde").encode("json", ex[2]))
end
