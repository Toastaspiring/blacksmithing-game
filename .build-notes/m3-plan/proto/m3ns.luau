--!nocheck
-- Thinness probes without the stride (THICK_BUDGET = 1e9) against §5.2's stride (400): the §5 fixtures in rank order,
-- d per step, Thinness All / Blade raw, and the cost of the factor phase (prototype T.factors, ms, one run each).
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local Shapes = require("./shapes")
local CFG = Analyze.CFG
local fmt = string.format

local function rankOrder(b)
	local list = {}
	for i, part in ipairs(b.parts) do
		local p = Shapes.prepare(part, i)
		list[i] = { p = p, part = part, k = { -p.volume, p.cy, math.abs(p.cx), p.cx, p.cz, p.hx, p.hy, p.hz, p.ux, p.uy, p.uz, p.vx, p.vy, p.vz } }
	end
	table.sort(list, function(A, B)
		for k = 1, #A.k do
			if A.k[k] ~= B.k[k] then
				return A.k[k] < B.k[k]
			end
		end
		if A.p.slot ~= B.p.slot then
			return A.p.slot < B.p.slot
		end
		if A.p.material ~= B.p.material then
			return A.p.material < B.p.material
		end
		return A.p.index < B.p.index
	end)
	local parts = {}
	for r, e in ipairs(list) do
		local q = table.clone(e.part)
		q.id = r
		parts[r] = q
	end
	return { name = b.name, parts = parts }
end
local function dl(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, fmt("%.4f", s.d))
	end
	return table.concat(t, "/")
end
local function th(R, stepName)
	for _, s in ipairs(R.steps) do
		if s.step == stepName then
			for _, f in ipairs(s.factors) do
				if f.factor == "Thinness" then
					return f.raw
				end
			end
		end
	end
	return 0
end
local list = {}
for _, b in ipairs(Fx.calibration()) do
	table.insert(list, b)
end
for _, b in ipairs(Fx.golden()) do
	table.insert(list, b)
end
for _, b in ipairs(Fx.perf()) do
	table.insert(list, b)
end
local worst = 0
for _, b0 in ipairs(list) do
	local b = rankOrder(b0)
	CFG.THICK_BUDGET = 400
	CFG.THIN_LADDER = false
	local A = Analyze.run(b)
	CFG.THIN_LADDER = true -- probes on the ladder grid that fits THICK_BUDGET, no stride
	local B = Analyze.run(b)
	CFG.THIN_LADDER = false
	local w = 0
	for i, s in ipairs(A.steps) do
		w = math.max(w, math.abs(s.d - B.steps[i].d))
	end
	worst = math.max(worst, w)
	print(fmt("%-44s stride %s Th %.4f/%.4f factors %.1f ms | none %s Th %.4f/%.4f factors %.1f ms | |dD| %.4f", string.sub(b.name, 1, 44), dl(A),
		th(A, "Hammering"), th(A, "Sharpening"), A.T.factors * 1000, dl(B), th(B, "Hammering"), th(B, "Sharpening"), B.T.factors * 1000, w))
end
print(fmt("worst |dD| %.4f", worst))
