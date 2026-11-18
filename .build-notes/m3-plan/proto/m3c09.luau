--!nocheck
-- Which parts of C09 and P5 lose exposed area under the void-face rule (B05), and of C04, C06, C08, F3.
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

local function areas(b, set)
	CFG.RECOMPUTE, CFG.THIN_MERGE, CFG.VOID_GAP, CFG.BODY = true, set.tm or 0.01, set.vg or 0, false
	local R = Analyze.run(b, { forceKept = (function()
		local t = {}
		for i = 1, #b.parts do
			t[i] = true
		end
		return t
	end)() })
	return R
end

local want = { C04 = true, C06 = true, C08 = true, C09 = true, F3 = true, P5 = true }
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
for _, b0 in ipairs(list) do
	local tag = string.match(b0.name, "^(%w+)")
	if want[tag] then
		local b = rankOrder(b0)
		-- areas are kept on the prepared parts: rerun and read them through a probe of the module's internals
		CFG.RECOMPUTE, CFG.THIN_MERGE, CFG.VOID_GAP, CFG.BODY = true, 0.01, 0, false
		local A = Analyze.run(b)
		CFG.VOID_GAP, CFG.THIN_MERGE = 0.05, 0.05
		local B = Analyze.run(b)
		CFG.VOID_GAP, CFG.THIN_MERGE = 0.03, 0.03
		local B3 = Analyze.run(b)
		CFG.VOID_GAP, CFG.THIN_MERGE, CFG.RECOMPUTE = 0, 0.01, false
		local function sc(R, stepName)
			for _, s in ipairs(R.steps) do
				if s.step == stepName then
					for _, f in ipairs(s.factors) do
						if f.factor == "SurfaceComplexity" then
							return f.raw
						end
					end
				end
			end
			return 0
		end
		print(fmt("%-40s SC All %.4f -> B05 %.4f / B03 %.4f | SC Blade %.4f -> B05 %.4f / B03 %.4f | d %s -> %s / %s", b.name,
			sc(A, "Hammering"), sc(B, "Hammering"), sc(B3, "Hammering"), sc(A, "Sharpening"), sc(B, "Sharpening"), sc(B3, "Sharpening"),
			(function(R)
				local t = {}
				for _, s in ipairs(R.steps) do
					table.insert(t, fmt("%.4f", s.d))
				end
				return table.concat(t, "/")
			end)(A),
			(function(R)
				local t = {}
				for _, s in ipairs(R.steps) do
					table.insert(t, fmt("%.4f", s.d))
				end
				return table.concat(t, "/")
			end)(B),
			(function(R)
				local t = {}
				for _, s in ipairs(R.steps) do
					table.insert(t, fmt("%.4f", s.d))
				end
				return table.concat(t, "/")
			end)(B3)))
		if A.partsArea then
			for i = 1, #A.partsArea do
				local d = A.partsArea[i] - B.partsArea[i]
				if math.abs(d) > 1e-6 then
					print(fmt("    part %d %s %s: exposed %.4f -> %.4f (-%.4f)", i, b.parts[i].label or "?", b.parts[i].shape, A.partsArea[i], B.partsArea[i], d))
				end
			end
		end
	end
end
