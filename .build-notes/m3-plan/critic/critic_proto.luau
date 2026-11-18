--!nocheck
-- Critic checks of the M3 plan's numbers, on the plan's own patched prototype (../proto). Read-only on the repo.
--   sweep        T-DIF-06's real edits (F5 blade thickness, C02 blade +dL) under R0 (stride), L (D2), LB (D2 + D1 late)
--   gen N        T-DIF-07 flush re-segmentation on N Gen.validSword designs (stride, D2, D2+D1), plus each variant's
--                Thinness and G against the fine reference (every volume sample a probe, THICK_BUDGET 1e9)
--   mirror N     a whole design against its X mirror image (Blueprint/Mirror semantics), max |dD| per variant
--   lam          the sandwich design question with an asymmetric hilt: does option B still flip a tier?
-- Run from the repo root: lune run <abs path>/critic_proto.luau -- sweep | gen 300 | mirror 200 | lam
local process = require("@lune/process")
local args = process.args
-- "t3:<section>": the same checks with tau = min over the union chords along world Z and the owner's 3 local axes
local useT3 = args[1] ~= nil and string.sub(args[1], 1, 3) == "t3:"
local Analyze = if useT3 then require("./analyze_t3") else require("../proto/analyze")
local Fx = require("../proto/fixtures")
local Shapes = require("../proto/shapes")
local Mirror = require("../proto/mirror")

local ROOT = "../../../../../../../../../Documents/RANDOM/ROBLOX/Blacksmithing Game/"
local CFG = Analyze.CFG
local fmt = string.format

local section = if useT3 then string.sub(args[1], 4) else (args[1] or "sweep")
local N = tonumber(args[2] or "") or 30
if useT3 then
	print("THETA3: tau = min(C(Z), C(local X), C(local Y), C(local Z)) in every variant")
end

local DEFAULTS = { RECOMPUTE = false, THIN_MERGE = 0.01, VOID_GAP = 0, BODY = false, THIN_LADDER = false, VOID_LATE = false,
	THICK_BUDGET = 400, THETA3 = useT3 }
local function apply(set)
	for k, v in pairs(DEFAULTS) do
		CFG[k] = v
	end
	for k, v in pairs(set) do
		CFG[k] = v
	end
end
local VARS = {
	{ name = "R0", set = {} },
	{ name = "L", set = { THIN_LADDER = true } },
	{ name = "LB", set = { THIN_LADDER = true, RECOMPUTE = true, THIN_MERGE = 0.05, VOID_GAP = 0.05, VOID_LATE = true } },
}
local FINE = { name = "FINE", set = { THICK_BUDGET = 1e9 } }
-- "b<N>" as the 4th argument: D2 (L, LB) with THICK_BUDGET = N instead of 400
if args[4] and string.sub(args[4], 1, 1) == "b" then
	local nb = tonumber(string.sub(args[4], 2))
	VARS[2].set.THICK_BUDGET = nb
	VARS[3].set.THICK_BUDGET = nb
	print("D2 variants with THICK_BUDGET " .. tostring(nb))
end

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

local function stepOf(R, name)
	for _, s in ipairs(R.steps or {}) do
		if s.step == name then
			return s
		end
	end
	return nil
end
local function factor(s, f)
	for _, fv in ipairs(s.factors) do
		if fv.factor == f then
			return fv
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
		table.insert(t, fmt("%.4f%s", s.d, string.sub(s.tier, 1, 1)))
	end
	return table.concat(t, "/")
end
local function runVar(v, b, opts)
	apply(v.set)
	local R = Analyze.run(b, opts)
	apply({})
	return R
end

-- ── T-DIF-06's real edits ───────────────────────────────────────────────────────────────────────────────────────
if section == "sweep" then
	local g = Fx.golden()
	print("F5 blade thickness: Hammering d (tier) and Thinness All raw per variant; T-DIF-06 wants 0.045 Hard, non-decreasing")
	for _, th in ipairs({ 0.060, 0.055, 0.050, 0.047, 0.045, 0.043 }) do
		local u = Fx.copy(g[5])
		for _, p in ipairs(u) do
			if p.label == "Blade" then
				p.size[3] = th
			end
		end
		local b = rankOrder(Fx.bp("F5 th", u))
		local row = {}
		for _, v in ipairs(VARS) do
			local R = runVar(v, b)
			local h = stepOf(R, "Hammering")
			table.insert(row, fmt("%s Ha %.4f %s Th %.4f", v.name, h.d, string.sub(h.tier, 1, 1), factor(h, "Thinness").raw))
		end
		print(fmt("  %.3f  %s", th, table.concat(row, " | ")))
	end
	print("C02 blade +dL: Sharpening d (tier) per variant; T-DIF-06 wants +0.20 Hard (0.2056)")
	local a = Fx.arming("Iron")
	for _, dL in ipairs({ 0.15, 0.20, 0.25 }) do
		local u = Fx.copy(a)
		for _, p in ipairs(u) do
			if p.label == "Blade" then
				p.size[2] += dL
				p.pos[2] += dL / 2
			end
			if p.label == "TipR" or p.label == "TipL" then
				p.pos[2] += dL
			end
		end
		local b = rankOrder(Fx.bp("C02 dL", u))
		local row = {}
		for _, v in ipairs(VARS) do
			local R = runVar(v, b)
			local s = stepOf(R, "Sharpening")
			table.insert(row, fmt("%s Sh %.4f %s EL %.4f", v.name, s.d, string.sub(s.tier, 1, 1), factor(s, "EdgeLength").raw))
		end
		print(fmt("  +%.2f  %s", dL, table.concat(row, " | ")))
	end
end

-- ── T-DIF-07 on N generated swords, and accuracy against the fine reference ─────────────────────────────────────
local function genContext()
	local Gen = require(ROOT .. "tests/lib/Gen")
	local TestRng = require(ROOT .. "tests/lib/TestRng")
	local Limits = require(ROOT .. "src/shared/Definitions/Limits")
	local EquipmentTypes = require(ROOT .. "src/shared/Definitions/EquipmentTypes")
	local Materials = require(ROOT .. "src/shared/Definitions/Materials")
	local Versions = require(ROOT .. "src/shared/Definitions/Versions")
	local Balance = require(ROOT .. "src/shared/Definitions/Balance")
	local ctx = Gen.context(Limits, EquipmentTypes.get("Sword"), Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)
	return Gen, TestRng, ctx
end
local MVP = { "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Volume" }
local function track(worst, key, d, tag)
	if d > (worst[key] or 0) then
		worst[key] = d
		worst[key .. "@"] = tag
	end
end
local function compare(A, B, worst, tag)
	for i, st in ipairs(A.steps) do
		local sb = B.steps[i]
		track(worst, "G", math.abs(st.g - sb.g), tag)
		track(worst, "D", math.abs(st.d - sb.d), tag)
		if st.tier ~= sb.tier then
			worst.flips = (worst.flips or 0) + 1
		end
		if st.step ~= "Smelting" then
			for _, f in ipairs(MVP) do
				track(worst, st.step:sub(1, 2) .. "." .. f, math.abs(factor(st, f).x - factor(sb, f).x), tag)
			end
		end
	end
end
local function show(name, w)
	local keys = {}
	for k in pairs(w) do
		if not string.find(k, "@") and k ~= "flips" then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	local t = {}
	for _, k in ipairs(keys) do
		table.insert(t, fmt("%s %.4f (%s)", k, w[k], tostring(w[k .. "@"])))
	end
	print(fmt("  %-26s flips %d; %s", name, w.flips or 0, table.concat(t, "; ")))
end

-- The rung D2 (THIN_LADDER) picks for a work set, and its estimate: the patched prototype's own rule.
local function d2Rung(b, sel)
	local parts = {}
	for i, part in ipairs(b.parts) do
		parts[i] = Shapes.prepare(part, i)
	end
	for _, kk in ipairs(CFG.H_LADDER) do
		local hT = CFG.H_VOL * kk
		local est = 0
		for _, p in ipairs(parts) do
			if sel == "All" or p.slot == sel then
				local a = math.max(CFG.N_MIN_AXIS, math.min(CFG.N_MAX_AXIS, math.ceil(2 * p.hx / hT)))
				local bb = math.max(CFG.N_MIN_AXIS, math.min(CFG.N_MAX_AXIS, math.ceil(2 * p.hy / hT)))
				local c = math.max(CFG.N_MIN_AXIS, math.min(CFG.N_MAX_AXIS, math.ceil(2 * p.hz / hT)))
				est += math.min(a * bb * c, CFG.N_MAX_PART)
			end
		end
		if est <= 400 then
			return hT, est
		end
	end
	return CFG.H_VOL * 16, -1
end

if section == "gen" then
	local t0 = os.clock()
	local Gen, TestRng, ctx = genContext()
	local rng = TestRng.new(0x5EED0007) -- the plan's seed: its first 30 designs are the plan's
	local seg = { R0 = {}, L = {}, LB = {}, FINE = {} }
	local acc = { R0 = {}, L = {}, LB = {} }
	local nSeg = 0
	local diag = tonumber(args[3] or "")
	local rungMoves, worstOver30 = 0, {}
	for i = 1, N do
		local core = Gen.validSword(rng, ctx)
		local s, cut = Gen.segmented(rng, ctx, core)
		Gen.translated(rng, ctx, core) -- keep the plan's stream
		if diag and i ~= diag then
			continue
		end
		-- "safe": skip designs where a cut piece comes out shorter than its part's smaller cross side (theta would flip)
		if args[3] == "safe" and #cut > 0 then
			local flips = false
			for _, id in ipairs(cut) do
				for _, p in ipairs(core.parts) do
					if p.id == id then
						local pieces = 0
						for _, q in ipairs(s.parts) do
							if q.slot == p.slot and q.size[1] == p.size[1] and q.size[3] == p.size[3] and q.shape == p.shape then
								pieces += 1
							end
						end
						local len = p.size[2] / math.max(pieces, 1)
						if len < math.min(p.size[1], p.size[3]) and p.size[2] >= math.min(p.size[1], p.size[3]) then
							flips = true
						end
					end
				end
			end
			if flips then
				continue
			end
		end
		local base = rankOrder(core)
		local fine = runVar(FINE, base)
		if i == diag then
			for _, pair in ipairs({ { "whole", core }, { "cut", s } }) do
				print("  parts of #" .. i .. " " .. pair[1])
				for _, p in ipairs(pair[2].parts) do
					local P = Shapes.prepare(p, 1)
					local theta = if p.shape == "Ball" then "X" elseif p.shape == "Cylinder" then (if P.hx <= P.r then "X" else "Y")
						elseif P.hx <= P.hy and P.hx <= P.hz then "X" elseif P.hy <= P.hz then "Y" else "Z"
					print(fmt("    id %d %-6s %-11s pos (%.4f, %.4f, %.4f) rot (%.4f, %.4f, %.4f, %.4f) size (%.4f, %.4f, %.4f) theta %s",
						p.id, p.slot, p.shape, p.pos[1], p.pos[2], p.pos[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4],
						p.size[1], p.size[2], p.size[3], theta))
				end
			end
		end
		if fine.steps then
			local cutB = if #cut > 0 then rankOrder(s) else nil
			if cutB then
				nSeg += 1
				local h0 = d2Rung(base, "All")
				local h1 = d2Rung(cutB, "All")
				if h0 ~= h1 then
					rungMoves += 1
				end
				local F2 = runVar(FINE, cutB)
				if F2.steps then
					compare(F2, fine, seg.FINE, "#" .. i)
				end
			end
			for _, v in ipairs(VARS) do
				local R = runVar(v, base)
				if v.name ~= "LB" then
					compare(R, fine, acc[v.name], "#" .. i)
				end
				if cutB then
					local S = runVar(v, cutB)
					if S.steps then
						compare(S, R, seg[v.name], "#" .. i)
						if i == diag then
							local hs = stepOf(S, "Hammering")
							local hr = stepOf(R, "Hammering")
							local h0, e0 = d2Rung(base, "All")
							local h1, e1 = d2Rung(cutB, "All")
							print(fmt("  diag #%d %s: whole %d parts Th %.4f G %.4f | cut %d parts Th %.4f G %.4f | D2 rung whole h %.4f est %d, cut h %.4f est %d",
								i, v.name, #base.parts, factor(hr, "Thinness").raw, hr.g, #cutB.parts, factor(hs, "Thinness").raw, hs.g, h0, e0, h1, e1))
						end
					end
				end
			end
		end
	end
	print(fmt("T-DIF-07 flush re-segmentation on %d Gen.validSword designs (%d cut, D2's All rung moved on %d); bounds |dx| 0.02, |dG| 0.002",
		N, nSeg, rungMoves))
	for _, v in ipairs(VARS) do
		show(v.name .. " segmented vs whole", seg[v.name])
	end
	show("FINE segmented vs whole", seg.FINE)
	print("Accuracy: each variant's whole design against FINE (every owned volume sample a probe)")
	for _, name in ipairs({ "R0", "L" }) do
		show(name .. " vs FINE", acc[name])
	end
	print(fmt("gen section %.2f s", os.clock() - t0))
end

-- ── a design against its X mirror image ─────────────────────────────────────────────────────────────────────────
if section == "mirror" then
	local t0 = os.clock()
	local Gen, TestRng, ctx = genContext()
	local rng = TestRng.new(0x5EED0008)
	local w = { R0 = {}, L = {}, LB = {} }
	local function mirrored(b)
		local t = {}
		for _, p in ipairs(b.parts) do
			table.insert(t, Mirror.reflect(p, "X"))
		end
		return Fx.bp(b.name .. " mirrored", t)
	end
	local list = {}
	for _, b in ipairs(Fx.calibration()) do
		table.insert(list, b)
	end
	for _, b in ipairs(Fx.golden()) do
		table.insert(list, b)
	end
	for i = 1, N do
		local core = Gen.validSword(rng, ctx)
		table.insert(list, { name = "gen#" .. i, parts = core.parts })
	end
	for _, b in ipairs(list) do
		local A0, B0 = rankOrder(b), rankOrder(mirrored(b))
		for _, v in ipairs(VARS) do
			local RA, RB = runVar(v, A0), runVar(v, B0)
			if RA.steps and RB.steps then
				compare(RA, RB, w[v.name], string.sub(b.name, 1, 16))
			end
		end
	end
	print(fmt("X mirror images: %d fixtures and %d Gen designs; max |d| and factor x differences", #list - N, N))
	for _, v in ipairs(VARS) do
		show(v.name, w[v.name])
	end
	print(fmt("mirror section %.2f s", os.clock() - t0))
end

-- ── the design question, with Asymmetry raising the baseline ────────────────────────────────────────────────────
if section == "lam" then
	local t0 = os.clock()
	local I, Z90 = Fx.I, Fx.Z90
	local function part(label, shape, slot, pos, rot, size, mat)
		return Fx.P(label, shape, slot, mat or "Iron", pos, rot, size)
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
	local D1 = { name = "B05late", set = { RECOMPUTE = true, THIN_MERGE = 0.05, VOID_GAP = 0.05, VOID_LATE = true } }
	local LB = VARS[3]
	print("sandwich, cheeks w x l x c (gap 0.02, Steel core wc), guard shifted dx in X: K (core kept) -> K + sheet (both cleaned)")
	for _, def in ipairs({
		{ 1.2, 2.5, 0.05, 0.90, 1.15, 0.00 },
		{ 1.2, 2.5, 0.05, 0.90, 1.15, 0.05 },
		{ 1.2, 2.5, 0.05, 0.90, 1.15, 0.10 },
		{ 1.2, 2.5, 0.05, 0.90, 1.15, 0.15 },
		{ 1.2, 2.5, 0.05, 0.90, 1.15, 0.20 },
		{ 1.2, 2.5, 0.03, 0.90, 1.15, 0.00 },
		{ 1.2, 2.5, 0.03, 0.90, 1.15, 0.10 },
		{ 1.0, 2.5, 0.04, 0.80, 0.95, 0.10 },
		{ 1.0, 2.5, 0.04, 0.80, 0.95, 0.00 },
		{ 1.1, 2.0, 0.04, 0.95, 1.08, 0.00 },
		{ 1.1, 2.0, 0.03, 0.95, 1.08, 0.00 },
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
		local K = blade(true, false)
		local KH = blade(true, true)
		local row = {}
		for _, v in ipairs({ D1, LB }) do
			local a = runVar(v, K, { forceKept = forceOff(K, {}) })
			local b2 = runVar(v, KH, { forceKept = forceOff(KH, { "LamCore", "Sheet" }) })
			local ha, hb = stepOf(a, "Hammering"), stepOf(b2, "Hammering")
			table.insert(row, fmt("%s %s -> %s [As %.3f SC %.3f->%.3f V %.4f->%.4f]", v.name, dl(a), dl(b2),
				factor(ha, "Asymmetry").raw, factor(ha, "SurfaceComplexity").raw, factor(hb, "SurfaceComplexity").raw,
				factor(ha, "Volume").raw, factor(hb, "Volume").raw))
		end
		print(fmt("  %.1f x %.1f x %.2f core %.2f dx %.2f: %s", w, l, c, wc, dx, table.concat(row, " | ")))
	end
	print(fmt("lam section %.2f s", os.clock() - t0))
end

-- ── the §5 fixtures under each variant (and FINE) ───────────────────────────────────────────────────────────────
if section == "fixtab" then
	local t0 = os.clock()
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
	local all = { VARS[1], VARS[2], VARS[3], FINE }
	for _, b0 in ipairs(list) do
		local b = rankOrder(b0)
		local row = {}
		for _, v in ipairs(all) do
			local R = runVar(v, b)
			local h = stepOf(R, "Hammering")
			table.insert(row, fmt("%s %s Th %.4f", v.name, dl(R), factor(h, "Thinness").raw))
		end
		print(fmt("%-30s %s", string.sub(b0.name, 1, 30), table.concat(row, " | ")))
	end
	print(fmt("fixtab section %.2f s", os.clock() - t0))
end

-- ── one design against its mirror image: the edge chains ────────────────────────────────────────────────────────
if section == "mirrordiag" then
	local Gen, TestRng, ctx = genContext()
	local rng = TestRng.new(0x5EED0008)
	local core
	for _ = 1, N do
		core = Gen.validSword(rng, ctx)
	end
	local b = { name = "gen#" .. N, parts = core.parts }
	local t = {}
	for _, p in ipairs(b.parts) do
		table.insert(t, Mirror.reflect(p, "X"))
	end
	local m = Fx.bp("mirrored", t)
	for _, pair in ipairs({ { "design", rankOrder(b) }, { "mirror", rankOrder(m) } }) do
		apply({})
		local R = Analyze.run(pair[2])
		local e = R.edge
		local lens = {}
		for _, ch in ipairs(e.chains) do
			table.insert(lens, fmt("%.4f(%d pts, from %.3f,%.3f)", ch.length, #ch.points, ch.points[1][1], ch.points[1][2]))
		end
		print(fmt("%s: EdgeLength %.6f cell %.3f bladeArea %.6f meanT %.6f chains %s", pair[1], e.length, e.cell, e.bladeArea,
			e.bladeMeanThickness, table.concat(lens, " ")))
	end
	for _, p in ipairs(b.parts) do
		if p.slot == "Blade" then
			print(fmt("  blade part %-11s pos (%.4f, %.4f, %.4f) rot (%.4f, %.4f, %.4f, %.4f) size (%.4f, %.4f, %.4f)", p.shape,
				p.pos[1], p.pos[2], p.pos[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4], p.size[1], p.size[2], p.size[3]))
		end
	end
end
