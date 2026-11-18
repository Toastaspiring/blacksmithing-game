--!nocheck
-- m3-plan-r2: the verdict's rank (Sampling.ranked: the slot's name second) against the measure's (Sampling.measureRanked)
-- as the order M3 walks, through the emulator, on every fixture. Prints the fixtures whose d, a factor or the edge differ.
--   lune run <abs>/proto/vrank.luau
local L = require("./lib")
local fmt = string.format

local same, diff = 0, 0
for _, f in ipairs(L.fixtures()) do
	local A = L.run(L.inRankOrder(f.b))
	local B = L.run(L.inVerdictOrder(f.b))
	if A.steps and B.steps then
		local notes = {}
		for si, s in ipairs(A.steps) do
			local t = B.steps[si]
			if s.d ~= t.d then
				table.insert(notes, fmt("%s d %.4f vs %.4f", s.step, s.d, t.d))
			end
			for fi, v in ipairs(s.factors) do
				local w = t.factors[fi]
				if v.raw ~= w.raw and math.abs(v.raw - w.raw) > 1e-12 then
					table.insert(notes, fmt("%s.%s %.3g", string.sub(s.step, 1, 2), v.factor, math.abs(v.raw - w.raw)))
				end
			end
		end
		local e, g = A.edge, B.edge
		if e.length ~= g.length or e.gripPoint[1] ~= g.gripPoint[1] or e.gripPoint[2] ~= g.gripPoint[2] or e.gripPoint[3] ~= g.gripPoint[3] then
			table.insert(notes, "edge or grip point")
		end
		local orderSame = true
		local pa, pb = L.inRankOrder(f.b).parts, L.inVerdictOrder(f.b).parts
		for k = 1, #pa do
			if pa[k] ~= pb[k] then
				orderSame = false
			end
		end
		if #notes > 0 then
			diff += 1
			print(fmt("%-12s %s", f.id, table.concat(notes, "; ")))
		elseif not orderSame then
			same += 1
			print(fmt("%-12s orders differ, d and factors within 1e-12", f.id))
		else
			same += 1
		end
	end
end
print(fmt("%d fixtures alike, %d differ (beyond 1e-12)", same, diff))
