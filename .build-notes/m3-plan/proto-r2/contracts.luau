--!nocheck
-- m3-plan-r2: the numbers the T-DIF and T-EDG tests will assert, re-measured on the snapshot through the emulator in the
-- measure's rank order, the build's verdict deciding. Sections:
--   sweep   T-DIF-06's real edits (E-S2.2): F5's blade 0.060 → 0.043 thick (Hammering, Thinness All); C02's blade
--           +0.15/+0.20/+0.25 long (Sharpening, EdgeLength); PartCount C01 → C10
--   dif04   T-DIF-04's cases against their bases: steps (g, m, d, tiers, every factor raw) and edge (chains, points,
--           bladeArea, mean thickness, grip point) to the bit
--   edge    T-EDG-01's items: F5's chain, P5's chains, a 0.30-thick blade, the EdgeLength cap case, X04
--   caps    T-DIF-01's caps: A24, Volume x on P1/P2/P4, SurfaceComplexity x on F3's Blade
--   lune run <abs>/proto/contracts.luau -- sweep | dif04 | edge | caps
local L = require("./lib")
local process = require("@lune/process")
local Fx = L.Fx
local Adversarial = require("../repo/tests/fixtures/Adversarial")
local Blueprints = require("../repo/tests/fixtures/Blueprints")
local Canonical = require("../repo/src/shared/Blueprint/Canonical")
local fmt = string.format

local section = process.args[1] or "sweep"
local I = Fx.I

local function run(b)
	return L.run(L.inRankOrder(b))
end
local function stepOf(R, name)
	for _, s in ipairs(R.steps) do
		if s.step == name then
			return s
		end
	end
	error(name)
end
local function factor(s, f)
	for _, v in ipairs(s.factors) do
		if v.factor == f then
			return v
		end
	end
	error(f)
end
local function key(R)
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%s %.17g %.17g %.17g %s %s", s.step, s.g, s.m, s.d, s.tier, s.tierRaw))
		for _, f in ipairs(s.factors) do
			table.insert(t, fmt("%.17g", f.raw))
		end
	end
	local e = R.edge
	table.insert(t, fmt("%.17g %d %.17g %.17g %.17g %.17g %.17g", e.length, #e.chains, e.bladeArea, e.bladeMeanThickness,
		e.gripPoint[1], e.gripPoint[2], e.gripPoint[3]))
	for _, c in ipairs(e.chains) do
		for _, p in ipairs(c.points) do
			table.insert(t, fmt("%.17g,%.17g", p[1], p[2]))
		end
	end
	return table.concat(t, "\n")
end
local function firstDiff(a, b)
	local la, lb = string.split(a, "\n"), string.split(b, "\n")
	for i = 1, math.max(#la, #lb) do
		if la[i] ~= lb[i] then
			return fmt("line %d: %s | %s", i, tostring(la[i]), tostring(lb[i]))
		end
	end
	return "same"
end
local function canon(variantKey)
	local r = Canonical.draft(Adversarial.variant(variantKey).draft())
	assert(r.ok, variantKey)
	return { name = variantKey, parts = r.value.parts }
end
local function fixtureCore(id)
	return { name = id, parts = Blueprints.core(id).parts }
end
local function dl(R)
	local d, t = L.dline(R)
	return d .. " " .. t
end

if section == "sweep" then
	print("F5 blade thickness: Hammering d (tier), Thinness All raw")
	for _, th in ipairs({ 0.060, 0.055, 0.050, 0.047, 0.045, 0.043 }) do
		local u = Fx.copy(L.find("F5"))
		for _, p in ipairs(u) do
			if p.label == "Blade" then
				p.size[3] = th
			end
		end
		local R = run(Fx.bp("F5 th", u))
		local h = stepOf(R, "Hammering")
		print(fmt("  %.3f  Ha %.4f %s  Thinness %.4f", th, h.d, h.tier, factor(h, "Thinness").raw))
	end
	print("C02 blade +dL (size y += dL, pos y += dL/2, tips += dL): Sharpening d (tier), EdgeLength")
	for _, dL in ipairs({ 0, 0.15, 0.20, 0.25 }) do
		local u = Fx.copy(L.find("C02"))
		for _, p in ipairs(u) do
			if p.label == "Blade" then
				p.size[2] += dL
				p.pos[2] += dL / 2
			end
			if p.label == "TipR" or p.label == "TipL" then
				p.pos[2] += dL
			end
		end
		local R = run(Fx.bp("C02 dL", u))
		local s = stepOf(R, "Sharpening")
		print(fmt("  +%.2f  Sh %.4f %s  EdgeLength %.4f", dL, s.d, s.tier, factor(s, "EdgeLength").raw))
	end
	local pcs = {}
	for _, id in ipairs({ "C01", "C02", "C04", "C05", "C06", "C07", "C08", "C09", "C10" }) do
		table.insert(pcs, fmt("%s %.3f", id, factor(stepOf(run(L.find(id)), "Hammering"), "PartCount").raw))
	end
	print("PartCount (All): " .. table.concat(pcs, ", "))
end

if section == "dif04" then
	local function case(name, base, filled, note)
		local A, B = run(base), run(filled)
		local same = key(A) == key(B)
		print(fmt("%-58s %s | base %s | filled %s cleaned %s%s", name, if same then "BIT-IDENTICAL" else "DIFFERS " .. firstDiff(key(A), key(B)),
			dl(A), dl(B), L.cleanedLine(B), if note then " | " .. note else ""))
	end
	-- C04 with a 0.075 blade + 9 nested blocks (Reference.spec's)
	do
		local base = Fx.copy(L.find("C04"))
		local blade
		for _, p in ipairs(base) do
			if p.label == "Blade" then
				p.size[3] = 0.075
				blade = p
			end
		end
		local filled = Fx.copy(Fx.bp("x", base))
		for k = 1, 9 do
			local f = 0.96 - 0.02 * k
			table.insert(filled, Fx.P("Fill" .. k, "Block", "Blade", "Iron", blade.pos, blade.rot, { blade.size[1] * f, blade.size[2] * f, blade.size[3] * f }))
		end
		case("C04 0.075 blade + 9 nested enclosed blocks", Fx.bp("x", base), Fx.bp("y", filled))
	end
	-- C09 with core, bevels and tips 0.05 longer + 6 blocks (5 Blade + 1 Pommel)
	do
		local delta = 0.05
		local base = Fx.copy(L.find("C09"))
		local core
		for _, p in ipairs(base) do
			if p.label == "Core" then
				p.pos[2] += delta / 2
				p.size[2] += delta
				core = p
			elseif string.sub(p.label, 1, 5) == "Bevel" then
				p.pos[2] += delta / 2
				p.size[1] += delta
			elseif string.sub(p.label, 1, 3) == "Tip" then
				p.pos[2] += delta
			end
		end
		local filled = Fx.copy(Fx.bp("x", base))
		for k = 1, 6 do
			local g = 0.75 - 0.005 * k
			table.insert(filled, Fx.P("Fill" .. k, "Block", if k <= 5 then "Blade" else "Pommel", "Iron", core.pos, I,
				{ core.size[1] * g, core.size[2] * g, core.size[3] * g }))
		end
		case("C09 blade 0.05 longer + 6 enclosed blocks", Fx.bp("x", base), Fx.bp("y", filled))
	end
	-- C09 + plate X + 5 hidden blocks (verdict/lines/limit2.luau)
	do
		local K = Fx.copy(L.find("C09"))
		table.insert(K, Fx.P("X", "Block", "Blade", "Iron", { -0.03, 2.6, 0 }, I, { 0.12, 2, 0.05 }))
		local KH = Fx.copy(Fx.bp("x", K))
		local slots = { "Guard", "Guard", "Guard", "Blade", "Blade" }
		for j = 1, 5 do
			local g = 0.8 - 0.01 * j
			table.insert(KH, Fx.P("Fill", "Block", slots[j], "Iron", { 0, 2.6, 0 }, I, { 0.12 * g, 2.4 * g, 0.06 * g }))
		end
		case("C09 + plate 0.12 × 2 × 0.05 + 5 hidden blocks", Fx.bp("x", K), Fx.bp("y", KH), "C09 alone " .. dl(run(L.find("C09"))))
	end
	-- X07a + a Dust hairline on the seam
	do
		local X = Fx.copy(L.find("X07a"))
		local XH = Fx.copy(Fx.bp("x", X))
		table.insert(XH, Fx.P("Hair", "Block", "Blade", "Iron", { 0, 2.68, 0 }, I, { 0.02, 0.4, 0.02 }))
		case("X07a + a Dust hairline 0.02 × 0.4 × 0.02 on the seam", Fx.bp("x", X), Fx.bp("y", XH))
	end
	-- F5, C02, C05 + 4 flush plates in the main blade (Verdict.spec's skins: Guard on the Z faces, Pommel on the X faces), first
	for _, id in ipairs({ "F5", "C02", "C05" }) do
		local base = L.find(id)
		local main
		for _, p in ipairs(base.parts) do
			if p.slot == "Blade" and p.shape == "Block" and (main == nil or p.size[1] * p.size[2] * p.size[3] > main.size[1] * main.size[2] * main.size[3]) then
				main = p
			end
		end
		local h = main
		local tz, tx = math.min(0.02, h.size[3] / 3), math.min(0.02, h.size[1] / 3)
		local plates = {
			Fx.P("S1", "Block", "Guard", "Iron", { h.pos[1], h.pos[2], h.pos[3] + (h.size[3] - tz) / 2 }, h.rot, { h.size[1], h.size[2], tz }),
			Fx.P("S2", "Block", "Guard", "Iron", { h.pos[1], h.pos[2], h.pos[3] - (h.size[3] - tz) / 2 }, h.rot, { h.size[1], h.size[2], tz }),
			Fx.P("S3", "Block", "Pommel", "Iron", { h.pos[1] + (h.size[1] - tx) / 2, h.pos[2], h.pos[3] }, h.rot, { tx, h.size[2], h.size[3] }),
			Fx.P("S4", "Block", "Pommel", "Iron", { h.pos[1] - (h.size[1] - tx) / 2, h.pos[2], h.pos[3] }, h.rot, { tx, h.size[2], h.size[3] }),
		}
		for _, p in ipairs(Fx.copy(base)) do
			table.insert(plates, p)
		end
		case(id .. " + 4 flush plates (Guard ±Z, Pommel ±X), listed first", base, Fx.bp("y", plates))
	end
	-- the A fixtures with a D relation
	case("A14 (19 dust cubes) vs F1", fixtureCore("F1"), canon("A14"))
	case("A16 (parts enclosed in blade and guard) vs F1", fixtureCore("F1"), canon("A16"))
	case("A17 (3 exact blade copies) vs F2", fixtureCore("F2"), canon("A17"))
	case("A25 (enclosed 20° grip core) vs F1", L.find("F1"), L.find("A25"))
end

if section == "edge" then
	local function chains(R)
		local t = {}
		for _, c in ipairs(R.edge.chains) do
			table.insert(t, fmt("%.3f", c.length))
		end
		return table.concat(t, ", ")
	end
	local F5 = run(L.find("F5"))
	local c = F5.edge.chains[1]
	print(fmt("F5: %d chain(s), main %.4f, %d points, first (%.3f, %.3f), last (%.3f, %.3f), cell %.2f, cutIndex %.2f", #F5.edge.chains,
		F5.edge.length, #c.points, c.points[1][1], c.points[1][2], c.points[#c.points][1], c.points[#c.points][2], F5.edge.cell,
		F5.edge.cutIndex))
	local P5 = run(L.find("P5"))
	print(fmt("P5: %d chains [%s], EdgeLength %.4f", #P5.edge.chains, chains(P5), P5.edge.length))
	local thick = Fx.copy(L.find("F2"))
	for _, p in ipairs(thick) do
		if p.slot == "Blade" then
			p.size[3] = 0.30
		end
	end
	local T = run(Fx.bp("F2 thick", thick))
	print(fmt("F2 with a 0.30-thick blade: EdgeLength %.4f, %d chains, valid %s", T.edge.length, #T.edge.chains, tostring(T.valid)))
	-- the cap case: F2's hilt with a 1.4 × 3.43 × 0.06 blade standing on the guard (top 1.55 → 4.98)
	local cap = {}
	for _, p in ipairs(Fx.copy(L.find("F2"))) do
		if p.slot ~= "Blade" then
			table.insert(cap, p)
		end
	end
	table.insert(cap, Fx.P("Blade", "Block", "Blade", "Iron", { 0, 1.55 + 3.43 / 2, 0 }, I, { 1.4, 3.43, 0.06 }))
	local C = run(Fx.bp("cap", cap))
	print(fmt("EdgeLength cap case: valid %s, EdgeLength %.4f, x %.3f (Sharpening), chains [%s]", tostring(C.valid), C.edge.length,
		factor(stepOf(C, "Sharpening"), "EdgeLength").x, chains(C)))
	local x04 = {}
	for _, f in ipairs(L.fixtures()) do
		if string.sub(f.id, 1, 3) == "X04" then
			local R = run(f.b)
			table.insert(x04, fmt("%s %.4f/%d", f.id, R.edge.length, #R.edge.chains))
		end
	end
	print("X04: " .. table.concat(x04, ", "))
end

if section == "caps" then
	local A24 = run(canon("A24"))
	print(fmt("A24: valid %s, Thinness All %.4f Blade %.4f, Hammering %.4f %s", tostring(A24.valid),
		factor(stepOf(A24, "Hammering"), "Thinness").raw, factor(stepOf(A24, "Sharpening"), "Thinness").raw, stepOf(A24, "Hammering").d,
		stepOf(A24, "Hammering").tier))
	for _, id in ipairs({ "P1", "P2", "P4", "C05", "F4" }) do
		local R = run(L.find(id))
		local v = factor(stepOf(R, "Smelting"), "Volume")
		print(fmt("%s Volume raw %.4f x %.3f", id, v.raw, v.x))
	end
	local F3 = run(L.find("F3"))
	local sc = factor(stepOf(F3, "Sharpening"), "SurfaceComplexity")
	print(fmt("F3 Blade SurfaceComplexity raw %.4f x %.3f", sc.raw, sc.x))
end
