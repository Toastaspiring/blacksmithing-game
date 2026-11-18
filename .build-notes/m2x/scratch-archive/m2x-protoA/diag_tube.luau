--!nocheck
local S = require("./sets")
local L = require("./lib")
local fmt = string.format
local list = S.jsonl("corpus/v12_a_void.jsonl")
for _, d in ipairs(list) do
	local P = L.prep(d.parts)
	local hasRod = false
	for i, p in ipairs(d.parts) do if p.shape == "Cylinder" and p.size[1] > 2 then hasRod = i end end
	if hasRod and #d.parts == 17 then
		local i = hasRod
		print(d.name, #d.parts, "rod", i, fmt("r %.4f", P[i].r))
		for j, p in ipairs(d.parts) do
			print(fmt("  %2d %-9s %-6s pos %.5f %.5f %.5f size %.5f %.5f %.5f rot %.4f %.4f %.4f %.4f", j, p.shape, p.slot, p.pos[1], p.pos[2], p.pos[3], p.size[1], p.size[2], p.size[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4]))
		end
		for _, v in ipairs({ { "base", nil }, { "canon", { canon = true } }, { "fine", { canon = true, sag = 0.002 } } }) do
			local share = L.newShares(P, function(Pp) return L.Cover.model(Pp, v[2]) end)
			print("  ", v[1], L.pct(share[i]))
		end
		local tr = L.truth(P)
		print("  truth (VisibleOracle)", L.pct(tr[i]))
		break
	end
end
