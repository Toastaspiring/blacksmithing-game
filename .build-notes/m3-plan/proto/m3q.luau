--!nocheck
-- M3 plan: one short run of the S2 v2 prototype (a patched copy) for the M3 design question and the fixture table.
--   section "fix":  every fixture of §5.5 (and P1-P5, A25-A27 with bases, X01/X02/X07) in rank order, under
--                   R0 (the prototype as is), R0r (measure re-run for every kept part), A05 (Thinness chords merge
--                   gaps <= 0.05), B05 (A05 + void faces <= 0.05 hidden in the measure), C (body rule)
--   section "lam":  the §17.2 sandwich (cheeks + core) and flush layers, core kept / cleaned / absent, same variants
--   section "gen":  T-DIF-07 on Gen.validSword: flush re-segmentation and Y/Z translation, max |dx_f| and |dG|
-- Run from the repo root: lune run <this file> -- [fix] [lam] [gen]
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local Shapes = require("./shapes")
local process = require("@lune/process")

local ROOT = "../../../../../../../../../Documents/RANDOM/ROBLOX/Blacksmithing Game/"
local CFG = Analyze.CFG
local fmt = string.format

local want = {}
local any = false
for _, a in ipairs(process.args) do
	want[a] = true
	any = true
end
local function on(s)
	return not any or want[s] == true
end

local DEFAULTS = { RECOMPUTE = false, THIN_MERGE = 0.01, VOID_GAP = 0, BODY = false, THIN_LADDER = false }
local function apply(set)
	for k, v in pairs(DEFAULTS) do
		CFG[k] = v
	end
	for k, v in pairs(set) do
		CFG[k] = v
	end
end

-- Sampling.ranked's keys: the larger first, then cy, |cx|, cx, cz, half extents, axes; slot and material names
local function rankOrder(b)
	local list = {}
	for i, part in ipairs(b.parts) do
		list[i] = { p = Shapes.prepare(part, i), part = part }
	end
	local function key(p)
		return { -p.volume, p.cy, math.abs(p.cx), p.cx, p.cz, p.hx, p.hy, p.hz, p.ux, p.uy, p.uz, p.vx, p.vy, p.vz }
	end
	for _, e in ipairs(list) do
		e.k = key(e.p)
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

local function step(R, name)
	for _, s in ipairs(R.steps or {}) do
		if s.step == name then
			return s
		end
	end
	return nil
end
local function dl(R)
	if not R.steps then
		return "INVALID"
	end
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%.4f", s.d))
	end
	return table.concat(t, "/")
end
local function maxDD(A, B)
	local w = 0
	for i, s in ipairs(A.steps or {}) do
		w = math.max(w, math.abs(s.d - B.steps[i].d))
	end
	return w
end
local function tiers(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, string.sub(s.tier, 1, 1))
	end
	return table.concat(t, "")
end

local VARIANTS = {
	{ name = "R0", set = {} },
	{ name = "R0r", set = { RECOMPUTE = true } },
	{ name = "A05", set = { RECOMPUTE = true, THIN_MERGE = 0.05 } },
	{ name = "B05", set = { RECOMPUTE = true, THIN_MERGE = 0.05, VOID_GAP = 0.05 } },
	{ name = "B10", set = { RECOMPUTE = true, THIN_MERGE = 0.10, VOID_GAP = 0.10 } },
	{ name = "C", set = { RECOMPUTE = true, BODY = true } },
}

local function runAll(b, opts)
	local out = {}
	for _, v in ipairs(VARIANTS) do
		apply(v.set)
		out[v.name] = Analyze.run(b, opts)
	end
	apply({})
	return out
end

-- ── fixtures ────────────────────────────────────────────────────────────────────────────────────────────────────
if on("fix") then
	local t0 = os.clock()
	print("=== fixtures in rank order: d Sm/Ha/Sh per variant; |dD| vs R0r ===")
	local list = {}
	for _, b in ipairs(Fx.calibration()) do
		table.insert(list, b)
	end
	for _, b in ipairs(Fx.golden()) do
		table.insert(list, b)
	end
	for _, a in ipairs(Fx.adversarial()) do
		table.insert(list, a.fixture)
		if a.base.name ~= "F1 ArmingSword" then
			table.insert(list, a.base)
		end
	end
	for _, r in ipairs(Fx.regression()) do
		if r.id == "X01" or r.id == "X02" or r.id == "X03" or r.id == "X07a" or r.id == "X07b" or r.id == "X07c" or r.id == "X04a" then
			table.insert(list, r.fixture)
		end
	end
	for _, b in ipairs(Fx.perf()) do
		table.insert(list, b)
	end
	for _, b0 in ipairs(list) do
		local b = rankOrder(b0)
		local R = runAll(b)
		local base = R.R0r
		local cl = {}
		for _, c in ipairs(R.R0.cleaned or {}) do
			table.insert(cl, c.reason:sub(1, 1) .. c.partId)
		end
		print(fmt("%-46s R0 %s %s | R0r %s | A05 %s (%.4f) | B05 %s (%.4f) | B10 %s (%.4f) | C %s (%.4f) | cl[%s]", string.sub(b.name, 1, 46), dl(R.R0), tiers(R.R0), dl(base),
			dl(R.A05), maxDD(R.A05, base), dl(R.B05), maxDD(R.B05, base), dl(R.B10), maxDD(R.B10, base), dl(R.C), maxDD(R.C, base), table.concat(cl, ",")))
		local h = step(R.R0, "Hammering")
		if h then
			local f = {}
			for _, fv in ipairs(h.factors) do
				f[fv.factor] = fv
			end
			local sh = step(R.R0, "Sharpening")
			local g = {}
			for _, fv in ipairs(sh.factors) do
				g[fv.factor] = fv
			end
			print(fmt("    R0 All: Th %.4f As %.4f SC %.4f/%.3f Vo %.5f EL %.4f | Blade: Th %.4f As %.4f SC %.4f/%.3f | g %.4f %.4f %.4f",
				f.Thinness.raw, f.Asymmetry.raw, f.SurfaceComplexity.raw, f.SurfaceComplexity.x, f.Volume.raw, f.EdgeLength.raw,
				g.Thinness.raw, g.Asymmetry.raw, g.SurfaceComplexity.raw, g.SurfaceComplexity.x,
				step(R.R0, "Smelting").g, h.g, sh.g))
		end
	end
	print(fmt("fix section %.2f s", os.clock() - t0))
end

-- ── the design question ─────────────────────────────────────────────────────────────────────────────────────────
local I = Fx.I
local Z90 = Fx.Z90
local function part(label, shape, slot, pos, rot, size, mat)
	return Fx.P(label, shape, slot, mat or "Iron", pos, rot, size)
end
local function hilt(gx)
	return {
		part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { gx or 1.10, 0.16, 0.30 }),
	}
end
local function indexOf(b, label)
	local out = {}
	for i, p in ipairs(b.parts) do
		if p.label == label then
			table.insert(out, i)
		end
	end
	return out
end
local function forceOff(b, labels)
	local f = {}
	for i = 1, #b.parts do
		f[i] = true
	end
	for _, l in ipairs(labels) do
		for _, i in ipairs(indexOf(b, l)) do
			f[i] = false
		end
	end
	return f
end
local function showRow(label, R)
	local t = {}
	for _, v in ipairs(VARIANTS) do
		if v.name ~= "R0" then
			local r = R[v.name]
			local h = step(r, "Hammering")
			local th, sc, vo = 0, 0, 0
			if h then
				for _, fv in ipairs(h.factors) do
					if fv.factor == "Thinness" then
						th = fv.x
					elseif fv.factor == "SurfaceComplexity" then
						sc = fv.raw
					elseif fv.factor == "Volume" then
						vo = fv.raw
					end
				end
			end
			table.insert(t, fmt("%s %s %s [Th %.3f SC %.3f V %.4f]", v.name, dl(r), tiers(r), th, sc, vo))
		end
	end
	print(fmt("  %-34s %s", label, table.concat(t, " | ")))
	return R
end

if on("lam") then
	if want.late then
		CFG.VOID_LATE = true
		print("VOID_LATE: the void test once per exposed sample")
	end
	local t0 = os.clock()
	print("\n=== sandwich: cheeks w x l x c, gap 0.02, core wc x l x 0.02 (Steel), top cap; d Sm/Ha/Sh ===")
	for _, def in ipairs({ { 1.1, 2.0, 0.06, 0.95, 1.08 }, { 1.2, 2.5, 0.05, 0.90, 1.15 } }) do
		local w, l, c, wc, wh = def[1], def[2], def[3], def[4], def[5]
		local k = 0.02
		local y = 1.45 + l / 2
		local function blade(withCore, withSheet, solid)
			local t = hilt()
			if solid then
				table.insert(t, part("Solid", "Block", "Blade", { 0, y, 0 }, I, { w, l, k + 2 * c }))
			else
				table.insert(t, part("CheekA", "Block", "Blade", { 0, y, k / 2 + c / 2 }, I, { w, l, c }))
				table.insert(t, part("CheekB", "Block", "Blade", { 0, y, -(k / 2 + c / 2) }, I, { w, l, c }))
			end
			table.insert(t, part("Top", "Block", "Blade", { 0, 1.45 + l + 0.02, 0 }, I, { w, 0.04, k + 2 * c }))
			if withCore then
				table.insert(t, part("LamCore", "Block", "Blade", { 0, y, 0 }, I, { wc, l, k }, "Steel"))
			end
			if withSheet then
				table.insert(t, part("Sheet", "Block", "Blade", { 0, y, 0 }, I, { wh, l, k }))
			end
			return rankOrder(Fx.bp("lam", t))
		end
		print(fmt("cheeks %.1f x %.1f x %.2f, core %.2f, sheet %.2f", w, l, c, wc, wh))
		local solid = blade(false, false, true)
		showRow("solid blade (union)", runAll(solid))
		local K = blade(true, false)
		showRow("K: core kept", runAll(K, { forceKept = forceOff(K, {}) }))
		local KH = blade(true, true)
		showRow("K + sheet: core, sheet cleaned", runAll(KH, { forceKept = forceOff(KH, { "LamCore", "Sheet" }) }))
		local hol = blade(false, false)
		showRow("hollow: no core", runAll(hol))
	end
	print("\n=== flush layers: solid w x len x t against n layers, interior layers cleaned ===")
	for _, def in ipairs({ { 1.6, 3.5, 0.16, 8 }, { 1.5, 3.4, 0.08, 4 } }) do
		local w, len, t, n = def[1], def[2], def[3], def[4]
		local y = 1.47 + len / 2
		local solid = hilt(1.60)
		table.insert(solid, part("Blade", "Block", "Blade", { 0, y, 0 }, I, { w, len, t }))
		local lamp = hilt(1.60)
		for kk = 1, n do
			table.insert(lamp, part(if kk == 1 or kk == n then "Outer" else "Inner", "Block", "Blade", { 0, y, -t / 2 + (kk - 0.5) * t / n }, I, { w, len, t / n }))
		end
		print(fmt("%.1f x %.1f x %.2f in %d layers", w, len, t, n))
		local S = rankOrder(Fx.bp("solid", solid))
		showRow("solid", runAll(S))
		local L = rankOrder(Fx.bp("layers", lamp))
		showRow("layers, interior cleaned", runAll(L, { forceKept = forceOff(L, { "Inner" }) }))
		showRow("layers, all kept", runAll(L, { forceKept = forceOff(L, {}) }))
	end
	print(fmt("lam section %.2f s", os.clock() - t0))
end

-- ── T-DIF-07 on generated swords ────────────────────────────────────────────────────────────────────────────────
if on("gen") or on("gen2") or on("gen3") or on("gen4") then
	if want.gen4 then
		CFG.THIN_LADDER, CFG.RECOMPUTE, CFG.THIN_MERGE, CFG.VOID_GAP, CFG.VOID_LATE = true, true, 0.05, 0.05, true
		print("gen4: ladder probes + VOID_GAP 0.05 (late)")
	end
	local t0 = os.clock()
	if want.gen2 then
		CFG.THICK_BUDGET = 1e9 -- every owned volume sample is a Thinness probe: no stride
		print("THICK_BUDGET = 1e9 (no stride)")
	end
	if want.gen3 then
		CFG.THIN_LADDER = true -- probes on the ladder grid that fits THICK_BUDGET
		print("THIN_LADDER (probes on a per-part grid at the ladder spacing, THICK_BUDGET 400)")
	end
	local Gen = require(ROOT .. "tests/lib/Gen")
	local TestRng = require(ROOT .. "tests/lib/TestRng")
	local Limits = require(ROOT .. "src/shared/Definitions/Limits")
	local EquipmentTypes = require(ROOT .. "src/shared/Definitions/EquipmentTypes")
	local Materials = require(ROOT .. "src/shared/Definitions/Materials")
	local Versions = require(ROOT .. "src/shared/Definitions/Versions")
	local Balance = require(ROOT .. "src/shared/Definitions/Balance")
	local ctx = Gen.context(Limits, EquipmentTypes.get("Sword"), Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)
	local MVP = { "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Volume" }
	local function setsOf(R)
		local s = {}
		for _, st in ipairs(R.steps) do
			local m = {}
			for _, fv in ipairs(st.factors) do
				m[fv.factor] = fv.x
			end
			s[st.step] = m
		end
		return s
	end
	local function compare(A, B, worst, tag)
		local sa, sb = setsOf(A), setsOf(B)
		for _, stepName in ipairs({ "Hammering", "Sharpening" }) do
			for _, f in ipairs(MVP) do
				local d = math.abs(sa[stepName][f] - sb[stepName][f])
				local key = stepName:sub(1, 2) .. "." .. f
				if d > (worst[key] or 0) then
					worst[key] = d
					worst[key .. "@"] = tag
				end
			end
		end
		for i, st in ipairs(A.steps) do
			local d = math.abs(st.g - B.steps[i].g)
			if d > (worst.G or 0) then
				worst.G = d
				worst["G@"] = tag
			end
		end
	end
	local N = 30
	local wSeg, wTr = {}, {}
	local turned, nSeg = 0, 0
	local rng = TestRng.new(0x5EED0007)
	for i = 1, N do
		local core = Gen.validSword(rng, ctx)
		local base = Analyze.run(rankOrder(core))
		if base.steps then
			local seg, cut = Gen.segmented(rng, ctx, core)
			if #cut > 0 then
				nSeg += 1
				local isTurned = false
				for _, p in ipairs(core.parts) do
					if p.slot == "Blade" and (p.rot[1] ~= 0 or p.rot[2] ~= 0 or p.rot[3] ~= 0) then
						isTurned = true
					end
				end
				if isTurned then
					turned += 1
				end
				local S = Analyze.run(rankOrder(seg))
				if S.steps then
					compare(S, base, wSeg, fmt("#%d%s", i, if isTurned then " turned" else ""))
				end
			end
			local tr = Gen.translated(rng, ctx, core)
			local T = Analyze.run(rankOrder(tr))
			if T.steps then
				compare(T, base, wTr, fmt("#%d", i))
			end
		end
	end
	local function show(name, w)
		local keys = {}
		for k in pairs(w) do
			if not string.find(k, "@") then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		local t = {}
		for _, k in ipairs(keys) do
			table.insert(t, fmt("%s %.4f (%s)", k, w[k], tostring(w[k .. "@"])))
		end
		print(name .. ": " .. table.concat(t, "; "))
	end
	print(fmt("\n=== T-DIF-07 on %d Gen.validSword designs (%d segmented, %d with a turned blade part) ===", N, nSeg, turned))
	show("segmented", wSeg)
	show("translated", wTr)
	print(fmt("gen section %.2f s", os.clock() - t0))
end

-- ── the recommended combination: ladder probes (T-DIF-07) + thin voids read as solid (design question) ──────────────
if want.final then
	if want.late then
		CFG.VOID_LATE = true
	end
	local t0 = os.clock()
	DEFAULTS.THIN_LADDER = false
	local FINAL = {
		{ name = "R0", set = {} },
		{ name = "L", set = { THIN_LADDER = true } },
		{ name = "LB05", set = { THIN_LADDER = true, RECOMPUTE = true, THIN_MERGE = 0.05, VOID_GAP = 0.05 } },
	}
	local function runF(b, opts)
		local out = {}
		for _, v in ipairs(FINAL) do
			apply(v.set)
			out[v.name] = Analyze.run(b, opts)
		end
		apply({})
		return out
	end
	print("=== final: R0 (stride, as specified) | L (ladder probes) | LB05 (ladder + VOID_GAP 0.05) ===")
	local list = {}
	for _, b in ipairs(Fx.calibration()) do
		table.insert(list, b)
	end
	for _, b in ipairs(Fx.golden()) do
		table.insert(list, b)
	end
	for _, a in ipairs(Fx.adversarial()) do
		table.insert(list, a.fixture)
		if a.base.name ~= "F1 ArmingSword" then
			table.insert(list, a.base)
		end
	end
	for _, b in ipairs(Fx.perf()) do
		table.insert(list, b)
	end
	for _, b0 in ipairs(list) do
		local b = rankOrder(b0)
		local R = runF(b)
		print(fmt("%-44s R0 %s %s | L %s %s (%.4f) | LB05 %s %s (%.4f)", string.sub(b.name, 1, 44), dl(R.R0), tiers(R.R0), dl(R.L), tiers(R.L),
			maxDD(R.L, R.R0), dl(R.LB05), tiers(R.LB05), maxDD(R.LB05, R.R0)))
	end
	print(fmt("final section %.2f s", os.clock() - t0))
end
