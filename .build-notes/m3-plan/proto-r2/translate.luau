--!nocheck
-- m3-plan-r2: T-DIF-07(a) on the fixtures: F1, F3, F5, C02, C06 moved by E-S2.10's 6 offsets (v2/run.luau's
-- {0,0.013,0}, {0,0.125,0}, {0,0.3317,0}, {0,0,0.01}, {0,0,-0.037}, {0,0.2,0.05}), through the emulator in the measure's
-- rank order: max |Δx| over the 5 weighted factors and |ΔG|, against the unmoved fixture; and the edge (Y moves the
-- chains by Δy, Z leaves them). An offset that leaves the hitbox is skipped (invalid), as v2/run.luau does.
--   lune run <abs>/proto/translate.luau
local L = require("./lib")
local fmt = string.format
local MVP = { "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Volume" }
local OFFSETS = { { 0, 0.013, 0 }, { 0, 0.125, 0 }, { 0, 0.3317, 0 }, { 0, 0, 0.01 }, { 0, 0, -0.037 }, { 0, 0.2, 0.05 } }
local function moved(b, d)
	local parts = {}
	for i, p in ipairs(b.parts) do
		local q = table.clone(p)
		q.pos = { p.pos[1] + d[1], p.pos[2] + d[2], p.pos[3] + d[3] }
		parts[i] = q
	end
	return { name = b.name, parts = parts }
end
for _, id in ipairs({ "F1", "F3", "F5", "C02", "C06" }) do
	local b = L.find(id)
	local A = L.run(L.inRankOrder(b))
	local wx, wf, wg, wEl, wPt, skipped = 0, "", 0, 0, 0, 0
	for _, d in ipairs(OFFSETS) do
		local B = L.run(L.inRankOrder(moved(b, d)))
		if not B.steps or not B.valid then
			skipped += 1
			continue
		end
		for si, s in ipairs(A.steps) do
			local t = B.steps[si]
			wg = math.max(wg, math.abs(s.g - t.g))
			for fi, f in ipairs(s.factors) do
				for _, m in ipairs(MVP) do
					if f.factor == m and math.abs(f.x - t.factors[fi].x) > wx then
						wx, wf = math.abs(f.x - t.factors[fi].x), string.sub(s.step, 1, 2) .. "." .. m
					end
				end
			end
		end
		wEl = math.max(wEl, math.abs(A.edge.length - B.edge.length))
		local ca, cb = A.edge.chains[1], B.edge.chains[1]
		if ca and cb and #ca.points == #cb.points then
			for k = 1, #ca.points do
				wPt = math.max(wPt, math.abs(cb.points[k][1] - ca.points[k][1]), math.abs(cb.points[k][2] - d[2] - ca.points[k][2]))
			end
		else
			wPt = math.huge
		end
	end
	print(fmt("%-4s 6 offsets (%d out of the hitbox, skipped): max |Δx| %.4f (%s), |ΔG| %.4f; EdgeLength |Δ| %.2g; main chain's points moved by Δy within %.2g", id, skipped, wx, wf, wg, wEl, wPt))
end
