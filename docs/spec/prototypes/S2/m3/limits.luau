--!nocheck
-- M3 (E-S2.13): what the 2 % rule itself admits, and two invariance figures, through Analyze.run as built (not the M3
-- plan's emulator). Lune 0.8.9, from the repo's root: lune run docs/spec/prototypes/S2/m3/limits.luau > docs/spec/prototypes/S2/m3/out/limits.txt
--   proud    the M3 plan critic's family (the M2 verifier's laminate, m2r4-va/c_lam.luau): two cheeks w × l × c at
--            z = ±(k/2 + c/2), a Steel core (w + 2p) × l × k between them, an optional top cap; 96 families, the core's
--            overhang p swept; where the core goes kept <-> cleaned between neighbouring p: |ΔD|, flips, and which
--            weighted factors carry each jump (cleaned − kept)
--   sandwich the M3 plan's recessed cores (verdict/lines/limit2.luau's hilt; a core wc × l × 0.02 in the cheeks' 0.02 gap,
--            a sheet over its rims): K (core) -> K+S (core + sheet), and the hollow design
--   g131     TestRng 0x5EED0001's Gen.validSword design 131 moved +0.2 in Y (Gen.translate): G per step
local Analyze = require("../../../../../src/shared/Physics/Analyze")
local Canonical = require("../../../../../src/shared/Blueprint/Canonical")
local Gen = require("../../../../../tests/lib/Gen")
local TestRng = require("../../../../../tests/lib/TestRng")
local Limits = require("../../../../../src/shared/Definitions/Limits")
local EquipmentTypes = require("../../../../../src/shared/Definitions/EquipmentTypes")
local Materials = require("../../../../../src/shared/Definitions/Materials")
local Versions = require("../../../../../src/shared/Definitions/Versions")
local Balance = require("../../../../../src/shared/Definitions/Balance")
local fmt = string.format
local I = { 0, 0, 0, 1 }
local Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }

local function P(id, slot, shape, mat, pos, rot, size)
	return { id = id, slot = slot, shape = shape, material = mat, pos = pos, rot = rot, size = size }
end
local function run(parts)
	local r = Canonical.draft({ schema = 1, name = "lam", type = "Sword", parts = parts }) :: any
	assert(r.ok, "canonical: " .. tostring(r.code) .. " " .. tostring(r.path))
	return Analyze.run(r.value)
end
local function dline(R)
	if not R.steps then
		return "INVALID"
	end
	local d, t = {}, {}
	for _, s in R.steps do
		table.insert(d, fmt("%.4f", s.d))
		table.insert(t, string.sub(s.tier, 1, 1) .. (if s.tierRaw ~= s.tier then "(" .. string.sub(s.tierRaw, 1, 2) .. ")" else ""))
	end
	return table.concat(d, " / ") .. " " .. table.concat(t, " ")
end
local function cleanedOf(R)
	local ids = {}
	for _, c in R.cleaned do
		table.insert(ids, string.sub(c.reason, 1, 1) .. c.partId)
	end
	return "[" .. table.concat(ids, ",") .. "]"
end
-- b − a per step, by weighted factor
local function carriers(a, b)
	local out = {}
	for si, s in a.steps do
		local t = b.steps[si]
		local parts = {}
		for ti, term in s.terms do
			local dx = t.terms[ti].x - term.x
			if math.abs(dx) > 5e-5 then
				table.insert(parts, fmt("%s %+.4f", string.sub(term.factor, 1, 4), term.w * dx))
			end
		end
		table.insert(out, fmt("%s Δd %+.4f: %s", string.sub(s.step, 1, 2), t.d - s.d, table.concat(parts, ", ")))
	end
	return table.concat(out, " | ")
end
local function worstFlips(a, b)
	local worst, flips = 0, 0
	for i, s in a.steps do
		worst = math.max(worst, math.abs(b.steps[i].d - s.d))
		if b.steps[i].tier ~= s.tier then
			flips += 1
		end
	end
	return worst, flips
end

-- proud: c_proud's design (ids 1–5, the cap 6, the core 7)
local function proud(w, l, c, k, p, cap)
	local y = 1.45 + l / 2
	local parts = {
		P(1, "Pommel", "Ball", "Iron", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		P(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		P(3, "Guard", "Block", "Iron", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
		P(4, "Blade", "Block", "Iron", { 0, y, k / 2 + c / 2 }, I, { w, l, c }),
		P(5, "Blade", "Block", "Iron", { 0, y, -(k / 2 + c / 2) }, I, { w, l, c }),
	}
	if cap then
		table.insert(parts, P(6, "Blade", "Block", "Iron", { 0, 1.45 + l + 0.02, 0 }, I, { w, 0.04, k + 2 * c }))
	end
	table.insert(parts, P(7, "Blade", "Block", "Steel", { 0, y, 0 }, I, { w + 2 * p, l, k }))
	return parts
end
local PS = { -0.02, -0.01, -0.005, 0, 0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.0075, 0.01, 0.0125, 0.015, 0.02, 0.03 }
local rows, families, crossings = {}, 0, 0
for _, w in { 0.3, 0.5, 0.8, 1.2 } do
	for _, l in { 2.0, 3.0 } do
		for _, c in { 0.02, 0.03, 0.05 } do
			for _, k in { 0.02, 0.04 } do
				for _, cap in { false, true } do
					families += 1
					local prev = nil
					for _, p in PS do
						if w + 2 * p <= 1.58 then
							local R = run(proud(w, l, c, k, p, cap))
							if R.steps then
								local kept = true
								for _, x in R.cleaned do
									if x.partId == 7 then
										kept = false
									end
								end
								if prev and prev.kept ~= kept then
									crossings += 1
									local worst, flips = worstFlips(prev.R, R)
									local cleanedR = if kept then prev.R else R
									local keptR = if kept then R else prev.R
									table.insert(rows, {
										worst = worst,
										flips = flips,
										text = fmt("w %.1f l %.1f c %.2f k %.2f cap %s: p %+.4f (%s) -> %+.4f (%s): %s -> %s, |ΔD| %.4f, %d flips",
											w, l, c, k, tostring(cap), prev.p, if prev.kept then "kept" else "cleaned", p,
											if kept then "kept" else "cleaned", dline(prev.R), dline(R), worst, flips),
										why = "      cleaned - kept: " .. carriers(keptR, cleanedR),
									})
								end
								prev = { p = p, kept = kept, R = R }
							end
						end
					end
				end
			end
		end
	end
end
table.sort(rows, function(a, b)
	return a.worst > b.worst
end)
local flipsAll, withFlip, lo, hi = 0, 0, math.huge, 0
for _, r in rows do
	flipsAll += r.flips
	if r.flips > 0 then
		withFlip += 1
	end
	lo, hi = math.min(lo, r.worst), math.max(hi, r.worst)
end
print(fmt("proud: %d families, %d crossings, |ΔD| %.4f–%.4f, %d tier flips on %d crossings", families, crossings, lo,
	hi, flipsAll, withFlip))
for _, r in rows do
	print("  " .. r.text)
	print(r.why)
end

-- sandwich: the plan's rows
local function sandwich(w, l, c, wc, wh, withCore, withSheet)
	local k, y = 0.02, 1.45 + l / 2
	local parts = {
		P(1, "Pommel", "Ball", "Iron", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		P(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		P(3, "Guard", "Block", "Iron", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
		P(4, "Blade", "Block", "Iron", { 0, y, k / 2 + c / 2 }, I, { w, l, c }),
		P(5, "Blade", "Block", "Iron", { 0, y, -(k / 2 + c / 2) }, I, { w, l, c }),
		P(6, "Blade", "Block", "Iron", { 0, 1.45 + l + 0.02, 0 }, I, { w, 0.04, k + 2 * c }),
	}
	if withCore then
		table.insert(parts, P(7, "Blade", "Block", "Steel", { 0, y, 0 }, I, { wc, l, k }))
	end
	if withSheet then
		table.insert(parts, P(8, "Blade", "Block", "Iron", { 0, y, 0 }, I, { wh, l, k }))
	end
	return parts
end
print("sandwich: K -> K+S, hollow")
local sBig, sFlips = 0, 0
for _, def in {
	{ 1.1, 2.0, 0.06, 0.95, 1.08 },
	{ 1.1, 2.0, 0.04, 0.95, 1.08 },
	{ 1.1, 2.0, 0.03, 0.95, 1.08 },
	{ 1.1, 2.0, 0.02, 0.95, 1.08 },
	{ 1.2, 2.5, 0.05, 0.90, 1.15 },
	{ 1.2, 2.5, 0.03, 0.90, 1.15 },
	{ 1.0, 2.5, 0.06, 0.80, 0.95 },
	{ 1.0, 2.5, 0.04, 0.80, 0.95 },
	{ 0.8, 2.5, 0.04, 0.60, 0.75 },
} do
	local K = run(sandwich(def[1], def[2], def[3], def[4], def[5], true, false))
	local KS = run(sandwich(def[1], def[2], def[3], def[4], def[5], true, true))
	local H = run(sandwich(def[1], def[2], def[3], def[4], def[5], false, false))
	local worst, flips = worstFlips(K, KS)
	sBig, sFlips = math.max(sBig, worst), sFlips + flips
	print(fmt("  %.1f × %.1f × %.2f core %.2f: K %s %s -> K+S %s %s (%d flips, |ΔD| %.4f); hollow %s", def[1], def[2],
		def[3], def[4], dline(K), cleanedOf(K), dline(KS), cleanedOf(KS), flips, worst, dline(H)))
	print("      " .. carriers(K, KS))
end
print(fmt("sandwich: %d flips, largest |ΔD| %.4f", sFlips, sBig))

-- g131
local ctx = Gen.context(Limits, EquipmentTypes.get("Sword"), Materials.enabled, Versions.BLUEPRINT_SCHEMA,
	Balance.Geometry)
local rng = TestRng.new(0x5EED0001)
local core
for _ = 1, 131 do
	core = Gen.validSword(rng, ctx)
end
local A = Analyze.run(core :: any)
local B = Analyze.run(Gen.translate(core, 0.2, 0) :: any)
print(fmt("g131 +0.2: EdgeLength %.6f (%d pts) -> %.6f (%d pts); bladeArea equal %s", A.edge.length,
	#A.edge.chains[1].points, B.edge.length, #B.edge.chains[1].points, tostring(A.edge.bladeArea == B.edge.bladeArea)))
for si, s in A.steps do
	print(fmt("  %s g %.4f -> %.4f |ΔG| %.4f %s -> %s", s.step, s.g, B.steps[si].g, math.abs(B.steps[si].g - s.g),
		s.tier, B.steps[si].tier))
end
