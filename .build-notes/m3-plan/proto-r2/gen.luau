--!nocheck
-- m3-plan-r2: T-DIF-07 and T-DIF-08's invariances on the snapshot, through the emulator in the measure's rank order, the
-- build's verdict deciding. Sections:
--   cuts      E-S2.10's F5 blade cut flush into 2, 3 and 7 pieces, and C12 against C02 (stride, and FINE: every owned
--             volume sample a probe, THICK_BUDGET 1e9)
--   seg N     N Gen.validSword designs from the critique's stream (TestRng 0x5EED0007; per design validSword, segmented,
--             translated): segmented against whole and translated against whole, on the 5 weighted factors and G, with the
--             stride and with FINE (segmented only)
--   mirror N  F1–F5, C01–C15 and N Gen designs (TestRng 0x5EED0008) against their X mirror image (Blueprint/Mirror):
--             max |ΔD|, |Δx| per factor, EdgeLength's relative change, and whether the raster (bladeArea, mean
--             thickness) is the same
--   lune run <abs>/proto/gen.luau -- cuts | seg 300 | mirror 150
local L = require("./lib")
local process = require("@lune/process")
local Fx = L.Fx
local CFG = L.Emu.CFG
local Gen = require("../repo/tests/lib/Gen")
local TestRng = require("../repo/tests/lib/TestRng")
local Limits = require("../repo/src/shared/Definitions/Limits")
local EquipmentTypes = require("../repo/src/shared/Definitions/EquipmentTypes")
local Materials = require("../repo/src/shared/Definitions/Materials")
local Versions = require("../repo/src/shared/Definitions/Versions")
local Balance = require("../repo/src/shared/Definitions/Balance")
local Mirror = require("../repo/src/shared/Blueprint/Mirror")
local fmt = string.format

local section = process.args[1] or "cuts"
local N = tonumber(process.args[2] or "") or 30
local ctx = Gen.context(Limits, EquipmentTypes.get("Sword"), Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)

local MVP = { "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Volume" }
local function factor(s, f)
	for _, v in ipairs(s.factors) do
		if v.factor == f then
			return v
		end
	end
	error(f)
end
local function run(b, fine)
	CFG.THICK_BUDGET = if fine then 1e9 else 400
	local R = L.run(L.inRankOrder(b))
	CFG.THICK_BUDGET = 400
	return R
end
local function newWorst()
	return { flips = 0 }
end
local function track(w, key, d, tag)
	if d > (w[key] or 0) then
		w[key] = d
		w[key .. "@"] = tag
	end
end
local function compare(A, B, w, tag)
	for i, s in ipairs(A.steps) do
		local t = B.steps[i]
		track(w, "G", math.abs(s.g - t.g), tag)
		track(w, "D", math.abs(s.d - t.d), tag)
		if s.tier ~= t.tier then
			w.flips += 1
		end
		if s.step ~= "Smelting" then
			for _, f in ipairs(MVP) do
				track(w, string.sub(s.step, 1, 2) .. "." .. f, math.abs(factor(s, f).x - factor(t, f).x), tag)
			end
		else
			track(w, "Sm.Volume", math.abs(factor(s, "Volume").x - factor(t, "Volume").x), tag)
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
	print(fmt("  %-28s tier flips %d; %s", name, w.flips, table.concat(t, "; ")))
end

if section == "cuts" then
	local g = Fx.golden()
	for _, fine in ipairs({ false, true }) do
		local base = run(g[5], fine)
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
			local w = newWorst()
			compare(run(Fx.bp("seg", t), fine), base, w, tostring(n))
			local mx, mk = 0, ""
			for k, v in pairs(w) do
				if type(v) == "number" and k ~= "flips" and k ~= "G" and k ~= "D" and v > mx then
					mx, mk = v, k
				end
			end
			table.insert(row, fmt("%d pieces |Δx| %.2g (%s) |ΔG| %.2g", n, mx, mk, w.G or 0))
		end
		local d = L.dline(base)
		print(fmt("F5 %-6s base %s | %s", if fine then "FINE" else "stride", d, table.concat(row, " | ")))
	end
	local cal = Fx.calibration()
	for _, fine in ipairs({ false, true }) do
		local A, B = run(cal[12], fine), run(cal[2], fine)
		local w = newWorst()
		compare(A, B, w, "C12")
		local mx, mk = 0, ""
		for k, v in pairs(w) do
			if type(v) == "number" and k ~= "flips" and k ~= "G" and k ~= "D" and v > mx then
				mx, mk = v, k
			end
		end
		print(fmt("C12 vs C02 %-6s |Δx| %.2g (%s) |ΔG| %.2g", if fine then "FINE" else "stride", mx, mk, w.G or 0))
	end
end

if section == "seg" then
	local t0 = os.clock()
	local rng = TestRng.new(0x5EED0007)
	local wSeg, wSegFine, wTr = newWorst(), newWorst(), newWorst()
	local nCut, nInvalid = 0, 0
	for i = 1, N do
		local core = Gen.validSword(rng, ctx)
		local s, cut = Gen.segmented(rng, ctx, core)
		local tr = Gen.translated(rng, ctx, core)
		local base = run(core, false)
		if not base.steps then
			nInvalid += 1
			continue
		end
		compare(run(tr, false), base, wTr, "#" .. i)
		if #cut > 0 then
			nCut += 1
			local S = run(s, false)
			if S.steps then
				compare(S, base, wSeg, "#" .. i)
			end
			local SF, BF = run(s, true), run(core, true)
			if SF.steps and BF.steps then
				compare(SF, BF, wSegFine, "#" .. i)
			end
		end
	end
	print(fmt("%d Gen.validSword designs (TestRng 0x5EED0007, the critique's stream), %d with a cut, %d invalid; bounds |Δx| %.2f, |ΔG| %.3f",
		N, nCut, nInvalid, 0.02, 0.002))
	show("translated vs whole", wTr)
	show("segmented vs whole (stride)", wSeg)
	show("segmented vs whole (FINE)", wSegFine)
	print(fmt("%.1f s", os.clock() - t0))
end

if section == "mirror" then
	local t0 = os.clock()
	local rng = TestRng.new(0x5EED0008)
	local list = {}
	for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5", "C01", "C02", "C04", "C05", "C06", "C07", "C08", "C09", "C10", "C11", "C12",
		"C13", "C14", "C15" }) do
		table.insert(list, { name = id, parts = L.find(id).parts })
	end
	for i = 1, N do
		table.insert(list, { name = "gen#" .. i, parts = Gen.validSword(rng, ctx).parts })
	end
	local w = newWorst()
	local elWorst, elAt, rasterSame, rasterDiff, rasterAt = 0, "", 0, 0, ""
	for _, b in ipairs(list) do
		local m = {}
		for k, p in ipairs(b.parts) do
			m[k] = Mirror.reflect(p, "X")
		end
		local A, B = run(b, false), run({ name = b.name, parts = m }, false)
		if A.steps and B.steps then
			compare(A, B, w, b.name)
			local ea, eb = A.edge, B.edge
			local rel = if ea.length > 0 then math.abs(ea.length - eb.length) / ea.length else 0
			if rel > elWorst then
				elWorst, elAt = rel, fmt("%s %.6f/%d pts vs %.6f/%d pts", b.name, ea.length, #(ea.chains[1] or { points = {} }).points,
					eb.length, #(eb.chains[1] or { points = {} }).points)
			end
			if math.abs(ea.bladeArea - eb.bladeArea) <= 1e-12 and math.abs(ea.bladeMeanThickness - eb.bladeMeanThickness) <= 1e-12 then
				rasterSame += 1
			else
				rasterDiff += 1
				rasterAt = b.name
			end
		end
	end
	print(fmt("X mirror images: 19 fixtures and %d Gen designs (TestRng 0x5EED0008), rank order, stride", N))
	show("design vs mirror image", w)
	print(fmt("  EdgeLength largest relative change %.4f%% (%s); raster within 1e-12 on %d, not on %d %s", elWorst * 100, elAt,
		rasterSame, rasterDiff, rasterAt))
	print(fmt("%.1f s", os.clock() - t0))
end
