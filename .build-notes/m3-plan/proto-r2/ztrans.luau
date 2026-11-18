--!nocheck
-- m3-plan-r2: T-EDG-01 item 6's Z translation through the emulator in rank order: F1, F3, F5, C02, C06 moved by
-- (0, 0, 0.01) and (0, 0, -0.037): are the chains (every point, every length, EdgeLength) bit-identical, and how far do
-- bladeArea and bladeMeanThickness move?
--   lune run <abs>/proto/ztrans.luau
local L = require("./lib")
local fmt = string.format
for _, id in ipairs({ "F1", "F3", "F5", "C02", "C06" }) do
	local b = L.find(id)
	local A = L.run(L.inRankOrder(b))
	local same, dArea, dThick = true, 0, 0
	for _, dz in ipairs({ 0.01, -0.037 }) do
		local parts = {}
		for i, p in ipairs(b.parts) do
			local q = table.clone(p)
			q.pos = { p.pos[1], p.pos[2], p.pos[3] + dz }
			parts[i] = q
		end
		local B = L.run(L.inRankOrder({ name = id, parts = parts }))
		if B.edge.length ~= A.edge.length or #B.edge.chains ~= #A.edge.chains then
			same = false
		else
			for c, ch in ipairs(A.edge.chains) do
				local other = B.edge.chains[c]
				if ch.length ~= other.length or #ch.points ~= #other.points then
					same = false
				else
					for k, pt in ipairs(ch.points) do
						if pt[1] ~= other.points[k][1] or pt[2] ~= other.points[k][2] then
							same = false
						end
					end
				end
			end
		end
		dArea = math.max(dArea, math.abs(A.edge.bladeArea - B.edge.bladeArea))
		dThick = math.max(dThick, math.abs(A.edge.bladeMeanThickness - B.edge.bladeMeanThickness))
	end
	print(fmt("%-4s Z offsets 0.01, -0.037: chains %s; |Δ bladeArea| %.2g, |Δ bladeMeanThickness| %.2g", id,
		if same then "bit-identical" else "DIFFER", dArea, dThick))
end
