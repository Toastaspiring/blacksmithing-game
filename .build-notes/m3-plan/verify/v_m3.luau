--!nocheck
-- Reviser's checks of the critique (read-only on the repo), on the plan's patched prototype (../proto).
--   cuts   E-S2.10's F5 flush cuts (2, 3, 7) and C12 vs C02, rank order: stride (R0), D2 (L), FINE
--   lam0   the critic's sandwich variants under option 0 (SPEC as written, R0) and option B (B05late): K -> K + sheet
-- Run from the repo root: lune run <abs path>/v_m3.luau -- cuts | lam0
local process = require("@lune/process")
local Analyze = require("../proto/analyze")
local Fx = require("../proto/fixtures")
local Shapes = require("../proto/shapes")
local CFG = Analyze.CFG
local fmt = string.format
local section = process.args[1] or "cuts"

local DEFAULTS = { RECOMPUTE = false, THIN_MERGE = 0.01, VOID_GAP = 0, BODY = false, THIN_LADDER = false, VOID_LATE = false,
	THICK_BUDGET = 400 }
local function apply(set)
	for k, v in pairs(DEFAULTS) do
		CFG[k] = v
	end
	for k, v in pairs(set) do
		CFG[k] = v
	end
end
local R0 = { name = "R0", set = {} }
local L = { name = "L", set = { THIN_LADDER = true } }
local FINE = { name = "FINE", set = { THICK_BUDGET = 1e9 } }
local B05 = { name = "B05late", set = { RECOMPUTE = true, THIN_MERGE = 0.05, VOID_GAP = 0.05, VOID_LATE = true } }

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
local function runVar(v, b, opts)
	apply(v.set)
	local R = Analyze.run(b, opts)
	apply({})
	return R
end
local function dl(R)
	if not R.steps then
		return "INVALID"
	end
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%.4f%s", s.d, string.sub(s.tier, 1, 1)))
	end
	return table.concat(t, "/")
end
local MVP = { "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Volume" }
local function xOf(s, f)
	for _, fv in ipairs(s.factors) do
		if fv.factor == f then
			return fv.x
		end
	end
	error(f)
end
local function delta(A, B)
	local w, wf, wg = 0, "", 0
	for i, s in ipairs(A.steps) do
		wg = math.max(wg, math.abs(s.g - B.steps[i].g))
		for _, f in ipairs(MVP) do
			local d = math.abs(xOf(s, f) - xOf(B.steps[i], f))
			if d > w then
				w, wf = d, s.step:sub(1, 2) .. "." .. f
			end
		end
	end
	return w, wf, wg
end

if section == "cuts" then
	local g = Fx.golden()
	local base = rankOrder(g[5])
	for _, v in ipairs({ R0, L, FINE }) do
		local B = runVar(v, base)
		local row = {}
		for _, n in ipairs({ 2, 3, 7 }) do
			local t = {}
			for _, p in ipairs(Fx.copy(g[5])) do
				if p.label ~= "Blade" then
					table.insert(t, p)
				end
			end
			local len = 2.60 / n
			for k = 0, n - 1 do
				table.insert(t, Fx.P("Seg" .. k, "Block", "Blade", "Iron", { 0, 1.38 + (k + 0.5) * len, 0 }, Fx.I, { 0.16, len, 0.06 }))
			end
			local X = runVar(v, rankOrder(Fx.bp("seg", t)))
			local w, wf, wg = delta(X, B)
			table.insert(row, fmt("%d pieces |dx| %.6f (%s) |dG| %.6f", n, w, wf, wg))
		end
		print(fmt("F5 %-5s base %s | %s", v.name, dl(B), table.concat(row, " | ")))
	end
	local cal = Fx.calibration()
	local c02, c12 = rankOrder(cal[2]), rankOrder(cal[12])
	for _, v in ipairs({ R0, L, FINE }) do
		local A, B = runVar(v, c12), runVar(v, c02)
		local w, wf, wg = delta(A, B)
		print(fmt("C12 vs C02 %-5s C12 %s C02 %s |dx| %.6f (%s) |dG| %.6f", v.name, dl(A), dl(B), w, wf, wg))
	end
end

if section == "lam0" then
	local I, Z90 = Fx.I, Fx.Z90
	local function part(label, shape, slot, pos, rot, size, mat)
		return Fx.P(label, shape, slot, mat or "Iron", pos, rot, size)
	end
	local function forceOff(b, labels)
		local f = {}
		for i, p in ipairs(b.parts) do
			f[i] = true
			for _, l in ipairs(labels) do
				if p.label == l then
					f[i] = false
				end
			end
		end
		return f
	end
	print("sandwich: K (core kept) -> K + sheet (core and sheet forced cleaned); d Sm/Ha/Sh with tier initial")
	for _, def in ipairs({
		{ 1.1, 2.0, 0.06, 0.95, 1.08, 0.00 },
		{ 1.1, 2.0, 0.04, 0.95, 1.08, 0.00 },
		{ 1.1, 2.0, 0.03, 0.95, 1.08, 0.00 },
		{ 1.2, 2.5, 0.05, 0.90, 1.15, 0.00 },
		{ 1.2, 2.5, 0.03, 0.90, 1.15, 0.00 },
		{ 1.0, 2.5, 0.04, 0.80, 0.95, 0.00 },
		{ 1.0, 2.5, 0.06, 0.80, 0.95, 0.00 },
		{ 0.8, 2.5, 0.04, 0.60, 0.75, 0.00 },
		{ 1.1, 2.0, 0.02, 0.95, 1.08, 0.00 },
	}) do
		local w, l, c, wc, wh, dx = def[1], def[2], def[3], def[4], def[5], def[6]
		local k = 0.02
		local y = 1.45 + l / 2
		local function blade(withCore, withSheet)
			local t = {
				part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
				part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
				part("Guard", "Block", "Guard", { dx, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
			}
			table.insert(t, part("CheekA", "Block", "Blade", { 0, y, k / 2 + c / 2 }, I, { w, l, c }))
			table.insert(t, part("CheekB", "Block", "Blade", { 0, y, -(k / 2 + c / 2) }, I, { w, l, c }))
			table.insert(t, part("Top", "Block", "Blade", { 0, 1.45 + l + 0.02, 0 }, I, { w, 0.04, k + 2 * c }))
			if withCore then
				table.insert(t, part("LamCore", "Block", "Blade", { 0, y, 0 }, I, { wc, l, k }, "Steel"))
			end
			if withSheet then
				table.insert(t, part("Sheet", "Block", "Blade", { 0, y, 0 }, I, { wh, l, k }))
			end
			return rankOrder(Fx.bp("lam", t))
		end
		local K, KH = blade(true, false), blade(true, true)
		local row = {}
		for _, v in ipairs({ R0, B05 }) do
			local a = runVar(v, K, { forceKept = forceOff(K, {}) })
			local b2 = runVar(v, KH, { forceKept = forceOff(KH, { "LamCore", "Sheet" }) })
			local flips = 0
			for i, s in ipairs(a.steps) do
				if s.tier ~= b2.steps[i].tier then
					flips += 1
				end
			end
			table.insert(row, fmt("%s %s -> %s (%d flips)", v.name, dl(a), dl(b2), flips))
		end
		print(fmt("  %.1f x %.1f x %.2f core %.2f: %s", w, l, c, wc, table.concat(row, " | ")))
	end
end
