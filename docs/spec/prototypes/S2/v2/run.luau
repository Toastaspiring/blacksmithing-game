--!strict
-- S2 prototype v2 runner: lune run run.luau -- [section ...]
-- sections: cal golden adv reg val inv det mirror perf (default: all)
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local Mirror = require("./mirror")
local Shapes = require("./shapes")
local Quat = require("./quat")
local process = require("@lune/process")

local fmt = string.format
local CFG = Analyze.CFG
local FACTORS = Analyze.FACTORS
local SHORT = { PartCount = "PC", Thinness = "Th", Asymmetry = "As", SurfaceComplexity = "SC", EdgeLength = "EL", Joints = "Jo", MaterialMix = "MM", Volume = "Vo" }

local want: { [string]: boolean } = {}
local any = false
for _, a in ipairs(process.args) do
	want[a] = true
	any = true
end
local function on(s: string): boolean
	return not any or want[s] == true
end

local function run(b: any, opts: any?): any
	return Analyze.run(b, opts)
end

local function errs(R: any): string
	local t = {}
	for _, e in ipairs(R.validation.errors) do
		table.insert(t, e.code .. (if e.slot then ":" .. e.slot else "") .. (if e.partId then "#" .. e.partId else ""))
	end
	return table.concat(t, ",")
end
local function cleaned(R: any): string
	local t = {}
	for _, c in ipairs(R.cleaned or {}) do
		table.insert(t, c.reason .. "#" .. c.partId)
	end
	return table.concat(t, ",")
end
local function stepsLine(R: any): string
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, fmt("%s %.4f %s%s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1), if s.tierRaw ~= s.tier then "(" .. string.sub(s.tierRaw, 1, 2) .. ")" else ""))
	end
	return table.concat(t, " | ")
end
local function setLine(F: any, key: string): string
	local t = {}
	for _, f in ipairs(FACTORS) do
		table.insert(t, fmt("%s %.4g/%.3f", SHORT[f], F.raw[f], F.x[f]))
	end
	return key .. ": " .. table.concat(t, " ")
end
local function report(R: any, verbose: boolean?)
	print(fmt("%-52s valid=%s err[%s] cleaned[%s] %.1f ms", R.name, tostring(R.valid), errs(R), cleaned(R), R.T.total * 1000))
	if R.physics then
		local p = R.physics
		print(fmt("    mass %.4f vol %.5f balance %.3f reach %.3f bladeLen %.3f grip (%.3f,%.3f,%.3f) axis (%.3f,%.3f) edge %.3f (all %.3f, %d chains) cut %.2f",
			p.mass, p.volume, p.balance, p.reach, p.bladeLength, p.gripPoint[1], p.gripPoint[2], p.gripPoint[3], p.gripAxis[1], p.gripAxis[2],
			R.edge.length, R.edge.allChainsLength, #R.edge.chains, R.edge.cutIndex))
	end
	if R.sets and verbose ~= false then
		for _, key in ipairs({ "All", "Blade" }) do
			if R.sets[key] then
				print("    " .. setLine(R.sets[key], key))
			end
		end
	end
	if R.steps then
		print("    " .. stepsLine(R))
	end
end

local function stepD(R: any, name: string): number
	for _, s in ipairs(R.steps) do
		if s.step == name then
			return s.d
		end
	end
	return 0 / 0
end
local function stepG(R: any, name: string): number
	for _, s in ipairs(R.steps) do
		if s.step == name then
			return s.g
		end
	end
	return 0 / 0
end

-- ---------------------------------------------------------------- calibration and golden
if on("cal") then
	print("=== Calibration swords C01-C15 ===")
	for _, b in ipairs(Fx.calibration()) do
		report(run(b))
	end
end
if on("golden") then
	print("\n=== Golden fixtures F1-F5 ===")
	for _, b in ipairs(Fx.golden()) do
		report(run(b))
	end
end

-- ---------------------------------------------------------------- adversarial A25-A27
if on("adv") then
	print("\n=== Adversarial A25-A27 (R3-01) ===")
	for _, a in ipairs(Fx.adversarial()) do
		local B, X = run(a.base), run(a.fixture)
		local worst = 0
		local t = {}
		for _, s in ipairs(X.steps) do
			if a.steps == "all" or a.steps == s.step then
				local dd = s.d - stepD(B, s.step)
				worst = math.max(worst, math.abs(dd))
				table.insert(t, fmt("%s dD %+.4f", s.step, dd))
			end
		end
		print(fmt("%-44s valid=%s cleaned[%s] %s | max |dD| %.4f (bound %.2f) %s", a.fixture.name, tostring(X.valid), cleaned(X), table.concat(t, " "), worst, a.bound, if worst <= a.bound then "PASS" else "FAIL"))
		print(fmt("    base: %s", stepsLine(B)))
		print(fmt("    fix : %s  physics axis (%.3f,%.3f) balance %.3f reach %.3f (base %.3f / %.3f)", stepsLine(X), X.physics.gripAxis[1], X.physics.gripAxis[2], X.physics.balance, X.physics.reach, B.physics.balance, B.physics.reach))
	end
end

-- ---------------------------------------------------------------- regression X01-X07
local function asymOracle(b: any): number
	local s1, s2, s3 = CFG.ASYM_N_MIN, CFG.ASYM_WORK, CFG.N_MAX_AXIS
	CFG.ASYM_N_MIN, CFG.ASYM_WORK, CFG.N_MAX_AXIS = 120, 1e9, 400
	local R = run(b)
	CFG.ASYM_N_MIN, CFG.ASYM_WORK, CFG.N_MAX_AXIS = s1, s2, s3
	return R.sets.All.raw.Asymmetry, R.sets.Blade.raw.Asymmetry
end
if on("reg") then
	print("\n=== Regression X01-X07 (base F5 unless noted) ===")
	for _, r in ipairs(Fx.regression()) do
		local B, X = run(r.base), run(r.fixture)
		local line
		if not X.valid then
			line = fmt("INVALID err[%s]", errs(X))
		elseif r.kind == "D" or r.kind == "G" then
			local w = 0
			local t = {}
			for _, s in ipairs(X.steps) do
				local dd = (if r.kind == "D" then s.d - stepD(B, s.step) else s.g - stepG(B, s.step))
				w = math.max(w, math.abs(dd))
				table.insert(t, fmt("%s %+.4f", string.sub(s.step, 1, 2), dd))
			end
			line = fmt("d%s %s | max %.4f (bound %.2f) %s", r.kind, table.concat(t, " "), w, r.bound, if w <= r.bound then "PASS" else "FAIL")
		elseif r.kind == "G+mass" then
			local w = 0
			local t = {}
			for _, s in ipairs(X.steps) do
				local dd = s.g - stepG(B, s.step)
				w = math.max(w, math.abs(dd))
				table.insert(t, fmt("%s %+.4f", string.sub(s.step, 1, 2), dd))
			end
			local dm = (X.physics.mass - B.physics.mass) / B.physics.mass
			line = fmt("dG %s | max %.4f (bound %.2f) mass %.5f vs base %.5f (%+.3f %%) %s", table.concat(t, " "), w, r.bound, X.physics.mass, B.physics.mass, dm * 100, if w <= r.bound then "PASS" else "FAIL")
		elseif r.kind == "Edge" then
			local e0, e1 = B.edge.length, X.edge.length
			local rel = (e1 - e0) / e0
			line = fmt("edge %.4f vs %.4f (%+.2f %%) chains %d | Sh dD %+.4f %s", e1, e0, rel * 100, #X.edge.chains, stepD(X, "Sharpening") - stepD(B, "Sharpening"), if math.abs(rel) <= r.bound then "PASS" else "FAIL")
		elseif r.kind == "Thinness" then
			local d = X.sets.All.raw.Thinness - B.sets.All.raw.Thinness
			line = fmt("Thinness %.4f vs %.4f (d %+.4f, bound %.2f) Ham dD %+.4f %s", X.sets.All.raw.Thinness, B.sets.All.raw.Thinness, d, r.bound, stepD(X, "Hammering") - stepD(B, "Hammering"), if math.abs(d) <= r.bound then "PASS" else "FAIL")
		elseif r.kind == "Asym" then
			local oa, ob = asymOracle(r.fixture)
			local a, bb = X.sets.All.raw.Asymmetry, X.sets.Blade.raw.Asymmetry
			local w = math.max(math.abs(a - oa), math.abs(bb - ob))
			line = fmt("Asym All %.4f (oracle %.4f) Blade %.4f (oracle %.4f) | max err %.4f %s | Ham %.4f Sh %.4f", a, oa, bb, ob, w, if w <= r.bound then "PASS" else "FAIL", stepD(X, "Hammering"), stepD(X, "Sharpening"))
		end
		print(fmt("%-44s %s", r.fixture.name, line))
	end
end

-- ---------------------------------------------------------------- validation
if on("val") then
	print("\n=== Validation cases ===")
	for _, b in ipairs(Fx.validation()) do
		local R = run(b, { measureInvalid = true })
		print(fmt("%-56s valid=%s err[%s] cleaned[%s]", b.name, tostring(R.valid), errs(R), cleaned(R)))
		if R.validation.components and #R.validation.components > 0 then
			for _, c in ipairs(R.validation.components) do
				print(fmt("    floating {%s} gap %.4f dir (%.3f,%.3f,%.3f) nearest #%d", table.concat(c.partIds, ","), c.gap, c.dir[1], c.dir[2], c.dir[3], c.nearestPartId))
			end
		end
		if R.steps and (string.find(b.name, "A23") or string.find(b.name, "A24")) then
			report(R)
		end
	end
end

-- ---------------------------------------------------------------- invariance (Y/Z translation, q -> -q, flush re-segmentation)
local MVP = { "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Volume" }
local function maxFactorDelta(A: any, B: any): (number, number)
	local w, wg = 0, 0
	for _, key in ipairs({ "All", "Blade" }) do
		for _, f in ipairs(MVP) do
			w = math.max(w, math.abs(A.sets[key].x[f] - B.sets[key].x[f]))
		end
	end
	for i, s in ipairs(A.steps) do
		wg = math.max(wg, math.abs(s.g - B.steps[i].g))
	end
	return w, wg
end
if on("inv") then
	print("\n=== Invariance ===")
	local g = Fx.golden()
	local bases = { g[5], g[1], g[3], Fx.arming("Iron"), Fx.sabre() }
	for _, b in ipairs(bases) do
		local B = run(b)
		local worst, worstG = 0, 0
		for _, d in ipairs({ { 0, 0.013, 0 }, { 0, 0.125, 0 }, { 0, 0.3317, 0 }, { 0, 0, 0.01 }, { 0, 0, -0.037 }, { 0, 0.2, 0.05 } }) do
			local X = run(Fx.transform(b, "t", Fx.I, { 0, 0, 0 }, d))
			if X.valid then
				local w, wg = maxFactorDelta(B, X)
				worst, worstG = math.max(worst, w), math.max(worstG, wg)
			end
		end
		-- q -> -q (A13): canonical form maps it back, so the analysed input is identical; check the raw path too
		local neg = Fx.copy(b)
		for _, p in ipairs(neg) do
			p.rot = { -p.rot[1], -p.rot[2], -p.rot[3], -p.rot[4] }
		end
		local N = run({ name = "neg", parts = (function()
			local t = {}
			for i, p in ipairs(neg) do
				t[i] = { id = i, shape = p.shape, slot = p.slot, material = p.material, pos = p.pos, rot = p.rot, size = p.size }
			end
			return t
		end)() })
		local wn, wgn = maxFactorDelta(B, N)
		print(fmt("%-40s Y/Z translations: max |dx_f| %.5f max |dG| %.5f | q->-q (uncanonical) |dx_f| %.2e |dG| %.2e", b.name, worst, worstG, wn, wgn))
	end
	-- flush re-segmentation of F5's blade into 2, 3, 7 flush pieces (no overlap, no gap)
	local base = g[5]
	local B = run(base)
	for _, n in ipairs({ 2, 3, 7 }) do
		local t = {}
		for _, p in ipairs(Fx.copy(base)) do
			if p.label ~= "Blade" then
				table.insert(t, p)
			end
		end
		local L = 2.60 / n
		for k = 0, n - 1 do
			table.insert(t, Fx.P("Seg" .. k, "Block", "Blade", "Iron", { 0, 1.38 + (k + 0.5) * L, 0 }, Fx.I, { 0.16, L, 0.06 }))
		end
		local X = run(Fx.bp("seg", t))
		local w, wg = maxFactorDelta(B, X)
		print(fmt("F5 blade re-segmented flush into %d: max |dx_f| %.5f max |dG| %.5f  (%s)", n, w, wg, stepsLine(X)))
	end
end

-- ---------------------------------------------------------------- determinism
if on("det") then
	print("\n=== Determinism (two runs, bit-identical) ===")
	local bad = 0
	local n = 0
	local all = {}
	for _, b in ipairs(Fx.calibration()) do table.insert(all, b) end
	for _, b in ipairs(Fx.golden()) do table.insert(all, b) end
	for _, b in ipairs(all) do
		local A, B = run(b), run(b)
		n += 1
		for i, s in ipairs(A.steps) do
			if s.d ~= B.steps[i].d or s.g ~= B.steps[i].g then
				bad += 1
			end
			for k, f in ipairs(s.factors) do
				if f.raw ~= B.steps[i].factors[k].raw then
					bad += 1
				end
			end
		end
		if A.physics.mass ~= B.physics.mass or A.edge.length ~= B.edge.length then
			bad += 1
		end
	end
	print(fmt("%d fixtures, %d mismatches", n, bad))
end

-- ---------------------------------------------------------------- mirror
if on("mirror") then
	print("\n=== Blueprint/Mirror: inside(mirror(p), x) == inside(p, reflect(x)) ===")
	local rngState = 12345
	local function rnd(): number
		rngState = (rngState * 1103515245 + 12345) % 2147483648
		return rngState / 2147483648
	end
	local worst = 0
	local mism = 0
	local total = 0
	for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
		for trial = 1, 20 do
			local size = { 0.05 + rnd() * 0.6, 0.05 + rnd() * 0.6, 0.05 + rnd() * 0.6 }
			if shape == "Ball" then size = { size[1], size[1], size[1] } end
			if shape == "Cylinder" then size = { size[1], size[2], size[2] } end
			local q = Quat.axisAngle(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5, rnd() * 360)
			local p = { id = 1, shape = shape, slot = "Guard", material = "Iron", pos = { rnd() - 0.5, 1 + rnd(), (rnd() - 0.5) * 0.3 }, rot = q, size = size }
			for _, plane in ipairs({ "X", "Z" }) do
				local m = Mirror.reflect(p, plane)
				local A, B = Shapes.prepare(p, 1), Shapes.prepare(m, 1)
				for _ = 1, 50 do
					local x, y, z = A.cx + (rnd() - 0.5) * 0.8, A.cy + (rnd() - 0.5) * 0.8, A.cz + (rnd() - 0.5) * 0.8
					local rx, rz = if plane == "X" then -x else x, if plane == "Z" then -z else z
					local d1 = Shapes.sd(A, x, y, z)
					local d2 = Shapes.sd(B, rx, y, rz)
					total += 1
					if (d1 < -1e-9) ~= (d2 < -1e-9) and math.abs(d1) > 1e-9 then
						mism += 1
					end
					if d1 < 0 then
						worst = math.max(worst, math.abs(d1 - d2))
					end
				end
			end
		end
	end
	print(fmt("%d point tests, %d membership mismatches, max |sd - sd'| inside %.2e", total, mism, worst))
	-- a design mirrored with the tool measures exactly symmetric
	local half = {}
	for _, p in ipairs(Fx.copy(Fx.armingMirrored())) do
		if p.label ~= "GuardL" and p.label ~= "FinialL" then
			table.insert(half, p)
		end
	end
	local R = run(Fx.armingMirrored())
	print(fmt("C13 (guard + finials mirrored with Blueprint/Mirror): Asymmetry All %.6f Blade %.6f", R.sets.All.raw.Asymmetry, R.sets.Blade.raw.Asymmetry))
end

-- ---------------------------------------------------------------- MIN_DIM = 0.02 checks
if on("mindim") then
	print("\n=== MIN_DIM = 0.02 checks ===")
	local g = Fx.golden()
	local F5 = g[5]
	local function swapBlade(name: string, blades: { any }): any
		local t = {}
		for _, p in ipairs(Fx.copy(F5)) do
			if p.label ~= "Blade" and p.label ~= "Tip" then
				table.insert(t, p)
			end
		end
		for _, b in ipairs(blades) do
			table.insert(t, b)
		end
		return Fx.bp(name, t)
	end
	local cases = {}
	for _, th in ipairs({ 0.06, 0.05, 0.04, 0.035, 0.03, 0.025, 0.02 }) do
		table.insert(cases, swapBlade(fmt("M1 F5 blade %.3f thick (no tip)", th), { Fx.P("Blade", "Block", "Blade", "Iron", { 0, 2.68, 0 }, Fx.I, { 0.16, 2.60, th }) }))
	end
	for _, dx in ipairs({ 0, 0.0025, 0.005, 0.0075, 0.01, 0.0125, 0.015 }) do
		table.insert(cases, swapBlade(fmt("M2 needle 0.02 x 2.6 x 0.02 at x %+.4f", dx), { Fx.P("Needle", "Block", "Blade", "Iron", { dx, 2.68, 0 }, Fx.I, { 0.02, 2.60, 0.02 }) }))
	end
	for _, w in ipairs({ 0.02, 0.03, 0.04, 0.05 }) do
		table.insert(cases, swapBlade(fmt("M3 blade %.2f wide x 0.03 thick", w), { Fx.P("Blade", "Block", "Blade", "Iron", { 0, 2.68, 0 }, Fx.I, { w, 2.60, 0.03 }) }))
	end
	for _, b in ipairs(cases) do
		local R = run(b)
		local A, Bl = R.sets and R.sets.All.raw, R.sets and R.sets.Blade.raw
		if R.valid then
			print(fmt("%-44s mass %.5f vol %.6f | Th All %.3f Blade %.3f | EL %.4f | As All %.4f | %s", b.name, R.physics.mass, R.physics.volume, A.Thinness, Bl.Thinness, R.edge.length, A.Asymmetry, stepsLine(R)))
		else
			print(fmt("%-44s INVALID err[%s] cleaned[%s]", b.name, errs(R), cleaned(R)))
		end
	end
	-- exact volume of the thin blade vs analytic (non-overlapping parts are exact)
end

-- ---------------------------------------------------------------- performance
if on("perf") then
	print("\n=== Performance (Lune best of 5; Studio estimate = x2.6) and longest uninterrupted slice ===")
	local list = {}
	for _, b in ipairs(Fx.calibration()) do table.insert(list, b) end
	for _, b in ipairs(Fx.golden()) do table.insert(list, b) end
	for _, b in ipairs(Fx.perf()) do table.insert(list, b) end
	print("| Fixture | parts | vol / surf / asym probes | overlap cells | raster cells | total ms Lune | x2.6 Studio | longest slice ms Lune | x2.6 |")
	print("|---|---|---|---|---|---|---|---|---|")
	for _, b in ipairs(list) do
		local best = math.huge
		local R
		local slice = 0
		for _ = 1, 5 do
			local last = os.clock()
			local longest = 0
			local Rr = run(b, { measureInvalid = true, checkpoint = function()
				local now = os.clock()
				longest = math.max(longest, now - last)
				last = now
			end })
			longest = math.max(longest, os.clock() - last)
			if Rr.T.total < best then
				best = Rr.T.total
				R = Rr
				slice = longest
			end
		end
		print(fmt("| %s | %d | %d / %d | %d | %d | %.1f | %.1f | %.2f | %.2f |", R.name, R.parts, R.volSamples or 0, R.surfSamples or 0, R.refinedCells or 0, R.edge and R.edge.cells or 0, best * 1000, best * 2600, slice * 1000, slice * 2600))
		if string.sub(R.name, 1, 1) == "P" then
			print(fmt("    valid=%s err[%s] cleaned[%s] T: validate %.1f surface %.1f mass %.1f edge %.1f factors %.1f ms", tostring(R.valid), errs(R), cleaned(R), (R.T.validate or 0) * 1000, (R.T.surface or 0) * 1000, (R.T.mass or 0) * 1000, (R.T.edge or 0) * 1000, (R.T.factors or 0) * 1000))
		end
	end
end
