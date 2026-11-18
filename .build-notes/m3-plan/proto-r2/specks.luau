--!nocheck
-- m3-plan-r2: P1–P3 + a Dust speck (floating, d_cost.luau's; attached, at part 23's centre): the snapshot's validation,
-- cleaned list and the emulator's d in the measure's rank order.
--   lune run <abs>/proto/specks.luau
local L = require("./lib")
local Analyze = require("../repo/src/shared/Physics/Analyze")
local fmt = string.format
local I = { 0, 0, 0, 1 }
local function copyParts(parts)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = { id = p.id, slot = p.slot, shape = p.shape, material = p.material, pos = table.clone(p.pos), rot = table.clone(p.rot), size = table.clone(p.size) }
	end
	return out
end
for _, id in ipairs({ "P1", "P2", "P3" }) do
	for _, kind in ipairs({ "floating", "attached" }) do
		local s = copyParts(L.find(id).parts)
		local pos = if kind == "floating" then { 0.7, 0.2, 0.2 } else table.clone(s[#s - 1].pos)
		s[#s] = { id = s[#s].id, slot = s[#s].slot, shape = "Block", material = "Iron", pos = pos, rot = I, size = { 0.05, 0.05, 0.05 } }
		local A = Analyze.run({ schema = 1, name = id, type = "Sword", parts = s }, { measureInvalid = true })
		local codes = {}
		for _, e in ipairs(A.validation.errors) do
			table.insert(codes, e.code .. (if e.partId then "#" .. e.partId else ""))
		end
		local R = L.run(L.inRankOrder({ name = id, parts = s }))
		print(fmt("%s + %s speck (part %d, slot %s): valid %s %s cleaned %s | d %s", id, kind, #s, s[#s].slot, tostring(A.validation.ok), table.concat(codes, ","), L.cleanedLine(A), (L.dline(R))))
	end
end
