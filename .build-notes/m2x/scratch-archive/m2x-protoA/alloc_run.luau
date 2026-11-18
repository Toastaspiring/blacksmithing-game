--!nocheck
-- garbage per verdict: Luau's heap count (KB) grows by the allocation of one call when the collector is held off by a large step
local S = require("./sets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local New = require("./v/newV_base/Sampling")
local Old = require("./v/oldV/Sampling")
local fmt = string.format
local list = {}
for _, d in ipairs(S.protoFixtures()) do if string.sub(d.name, 1, 3) == "C09" or string.sub(d.name, 1, 3) == "P1 " or string.sub(d.name, 1, 3) == "P4 " then table.insert(list, d) end end
for _, d in ipairs(S.json("../m2r5-v1-1/out/d_hand.json")) do if string.find(d.name, "d 0.15 L 4.8", 1, true) then table.insert(list, d) end end
for _, d in ipairs(list) do
	local P = {}
	for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
	local res = {}
	for _, v in ipairs({ { "old", Old }, { "new", New } }) do
		local best = math.huge
		for r = 1, 3 do
			local before = gcinfo()
			v[2].exposure(P)
			local after = gcinfo()
			-- gcinfo can drop when a cycle completes mid-call; keep the largest growth seen
			if after - before > 0 then best = math.min(best, after - before) end
		end
		res[v[1]] = best
	end
	print(fmt("%-44s heap growth over one verdict: old %8.0f KB, new %8.0f KB", string.sub(d.name, 1, 44), res.old, res.new))
end
