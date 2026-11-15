--!nocheck
-- fix-4: which facets of a wrap-ring grip the cap's circle moves (nocap against cap), and against which hider
local Lab = require("./lab")
local S = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local PD = require(S .. "/m2x-r4-base/repo/tests/Physics/PlausibleDesigns")
local fmt = string.format
for _, d in ipairs(PD.all()) do
	if d.name == "wrapRings|F3|n4 extra0.04 gap0.0040" or d.name == "wrapRings|C09|n3 extra0.04 gap0.0040" then
		local i = if string.find(d.name, "C09") then 3 else 2
		local desc = {}
		for _, p in ipairs(d.parts) do
			table.insert(desc, fmt("%s %s r %.3f", p.slot, p.shape, math.min(p.size[1], p.size[2], p.size[3]) / 2))
		end
		print(table.concat(desc, "; "))
		for _, name in ipairs({ "nocap", "cap" }) do
			local L = Lab.tree(name)
			local P = L.prep(d.parts)
			local m = L.models(P)
			local idx, higher = L.hidersOf(P, i, m)
			local hm = {}
			for k, j in ipairs(idx) do
				hm[k] = m[j]
			end
			local row = {}
			for f = 1, m[i].n do
				local b = 6 * (f - 1)
				local one = { part = m[i].part, round = true, flat = { m[i].flat and m[i].flat[f] }, n = 1, poly = { m[i].poly[f] }, nx = { m[i].nx[f] }, ny = { m[i].ny[f] }, nz = { m[i].nz[f] },
					area = { m[i].area[f] }, box = { table.unpack(m[i].box, b + 1, b + 6) }, spread = { m[i].spread[f] }, hull = { m[i].hull[f] },
					total = m[i].area[f], np = 0, planes = {}, sag = { m[i].sag[f] }, inner = 0, reach = m[i].reach, over = m[i].over, work = 0 }
				row[f] = L.Cover.shown(one, hm, higher, math.huge, math.huge) / m[i].total
			end
			print(fmt("%s %s grip (part %d): whole %.4f %%; caps %.4f %% / %.4f %%; sides %.4f %%", d.name, name, i, 100 * L.readOf(P, i, m),
				100 * row[33], 100 * row[34], 100 * (function() local s = 0 for f = 1, 32 do s += row[f] end return s end)()))
		end
	end
end
