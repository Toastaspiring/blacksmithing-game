--!nocheck
-- what differs between orders, on the examples c_invar printed: lune run c_invar_dbg -- <log>
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local TestRng = require("./repo/tests/lib/TestRng")
local fmt = string.format
local rng = TestRng.new(99)
local txt = fs.readFile(process.args[1])
for line in string.gmatch(txt, "EXAMPLE order (%b[])") do
	local parts = serde.decode("json", line)
	local N = #parts
	L.renumber(parts)
	local e0 = L.Sampling.exposure(L.prep(L.copyParts(parts)))
	-- identical parts (the same in every way but id): a class
	local P = L.prep(L.copyParts(parts))
	local class = {}
	for i = 1, N do
		class[i] = i
		for j = 1, i - 1 do
			local a, b = parts[i], parts[j]
			if L.Shapes.sameSolid(P[i], P[j]) and a.slot == b.slot and a.material == b.material and a.size[1] == b.size[1] and a.size[2] == b.size[2] and a.size[3] == b.size[3] then
				class[i] = class[j]
				break
			end
		end
	end
	for k = 1, 20 do
		local perm = {}
		for i = 1, N do perm[i] = i end
		for i = N, 2, -1 do
			local j = rng:int(1, i)
			perm[i], perm[j] = perm[j], perm[i]
		end
		local sp = {}
		for i = 1, N do sp[i] = L.copyPart(parts[perm[i]]) end
		L.renumber(sp)
		local e = L.Sampling.exposure(L.prep(sp))
		local what = {}
		if e.verdictWork ~= e0.verdictWork then table.insert(what, fmt("verdictWork %.3f vs %.3f", e.verdictWork, e0.verdictWork)) end
		if e.hSurf ~= e0.hSurf then table.insert(what, "hSurf") end
		if e.surfSamples ~= e0.surfSamples then table.insert(what, "surfSamples") end
		if e.subSampled ~= e0.subSampled then table.insert(what, fmt("subSampled %d vs %d", e.subSampled, e0.subSampled)) end
		for i = 1, N do
			local o = perm[i]
			local cls = class[o] ~= o or (function() for j = 1, N do if j ~= o and class[j] == o then return true end end return false end)()
			if e.kept[i] ~= e0.kept[o] then table.insert(what, fmt("kept #%d %s->%s%s", o, tostring(e0.kept[o]), tostring(e.kept[i]), cls and " (class)" or "")) end
			if e.exposedKept[i] ~= e0.exposedKept[o] then table.insert(what, fmt("exposed #%d %.17g vs %.17g%s", o, e0.exposedKept[o], e.exposedKept[i], cls and " (class)" or "")) end
			for j = 1, N do
				if e.contact[i][j] ~= e0.contact[o][perm[j]] then table.insert(what, fmt("contact #%d,#%d%s", o, perm[j], cls and " (class)" or "")) break end
			end
		end
		if #what > 0 then
			print(fmt("design of %d parts, order %d: %s", N, k, table.concat(what, "; ")))
			break
		end
	end
end
