--!nocheck
-- m3-plan-r2: §17.2's design question ("a core sandwiched between cheeks that crosses 2 %") on the snapshot, through the
-- emulator in the measure's rank order, the build's own verdict deciding (nothing forced). Designs: the old plan's
-- verify/v_m3.luau lam0 sandwiches (verdict/lines/limit2.luau's hilt: Ball d 0.30 at y 0.30, Cylinder 0.90 × 0.16 at y 0.88,
-- Guard 1.10 × 0.16 × 0.30 at y 1.40; two cheeks w × l × c at z ±(0.01 + c/2), a top cap w × 0.04 × (0.02 + 2c); a Steel
-- core wc × l × 0.02 in the 0.02 gap; a sheet wh × l × 0.02 over the core's rims). For each: K = with the core, K+S = with
-- core and sheet, H = hollow (no core, no sheet). Prints the cleaned list, d per step with tiers, and per step which
-- weighted factors carry the change K → K+S.
--   lune run <abs>/proto/sandwich.luau
local L = require("./lib")
local Fx = L.Fx
local fmt = string.format

local I, Z90 = Fx.I, Fx.Z90
local function part(label, shape, slot, pos, rot, size, mat)
	return Fx.P(label, shape, slot, mat or "Iron", pos, rot, size)
end

local function design(w, l, c, wc, wh, withCore, withSheet, dx)
	local k = 0.02
	local y = 1.45 + l / 2
	local t = {
		part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		part("Guard", "Block", "Guard", { dx or 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
		part("CheekA", "Block", "Blade", { 0, y, k / 2 + c / 2 }, I, { w, l, c }),
		part("CheekB", "Block", "Blade", { 0, y, -(k / 2 + c / 2) }, I, { w, l, c }),
		part("Top", "Block", "Blade", { 0, 1.45 + l + 0.02, 0 }, I, { w, 0.04, k + 2 * c }),
	}
	if withCore then
		table.insert(t, part("LamCore", "Block", "Blade", { 0, y, 0 }, I, { wc, l, k }, "Steel"))
	end
	if withSheet then
		table.insert(t, part("Sheet", "Block", "Blade", { 0, y, 0 }, I, { wh, l, k }))
	end
	return L.inRankOrder(Fx.bp("lam", t))
end

local W = { Smelting = { Volume = 1 }, Hammering = { Thinness = 0.4, Asymmetry = 0.3, SurfaceComplexity = 0.3 },
	Sharpening = { Asymmetry = 0.3, SurfaceComplexity = 0.2, EdgeLength = 0.5 } }
local function carriers(a, b)
	local out = {}
	for si, s in ipairs(a.steps) do
		local t = b.steps[si]
		local parts = {}
		for fi, f in ipairs(s.factors) do
			local w = W[s.step][f.factor]
			if w then
				local dx = t.factors[fi].x - f.x
				if math.abs(dx) > 5e-5 then
					table.insert(parts, fmt("%s %+.4f (x %.3f→%.3f)", string.sub(f.factor, 1, 4), w * dx, f.x, t.factors[fi].x))
				end
			end
		end
		table.insert(out, fmt("%s Δd %+.4f: %s", string.sub(s.step, 1, 2), t.d - s.d, table.concat(parts, ", ")))
	end
	return table.concat(out, " | ")
end
local function dl(R)
	if not R.steps then
		return "INVALID"
	end
	local d, t = L.dline(R)
	return d .. " " .. t
end
local function flips(a, b)
	local n = 0
	for i, s in ipairs(a.steps) do
		if s.tier ~= b.steps[i].tier then
			n += 1
		end
	end
	return n
end

print("sandwich: K (core) → K+S (core + sheet); H hollow; the build's verdict; rank order; d Sm / Ha / Sh, tiers")
local total, biggest = 0, 0
for _, def in ipairs({
	{ 1.1, 2.0, 0.06, 0.95, 1.08 },
	{ 1.1, 2.0, 0.04, 0.95, 1.08 },
	{ 1.1, 2.0, 0.03, 0.95, 1.08 },
	{ 1.1, 2.0, 0.02, 0.95, 1.08 },
	{ 1.2, 2.5, 0.05, 0.90, 1.15 },
	{ 1.2, 2.5, 0.03, 0.90, 1.15 },
	{ 1.0, 2.5, 0.06, 0.80, 0.95 },
	{ 1.0, 2.5, 0.04, 0.80, 0.95 },
	{ 0.8, 2.5, 0.04, 0.60, 0.75 },
}) do
	local w, l, c, wc, wh = def[1], def[2], def[3], def[4], def[5]
	local K = L.run(design(w, l, c, wc, wh, true, false))
	local KS = L.run(design(w, l, c, wc, wh, true, true))
	local H = L.run(design(w, l, c, wc, wh, false, false))
	local n = if K.steps and KS.steps then flips(K, KS) else -1
	total += math.max(n, 0)
	local big = 0
	if K.steps and KS.steps then
		for i, s in ipairs(K.steps) do
			big = math.max(big, math.abs(KS.steps[i].d - s.d))
		end
	end
	biggest = math.max(biggest, big)
	print(fmt("%.1f × %.1f × %.2f core %.2f: K %s cleaned %s → K+S %s cleaned %s (%d flips, |ΔD| %.4f); hollow %s %s", w, l, c,
		wc, dl(K), L.cleanedLine(K), dl(KS), L.cleanedLine(KS), n, big, dl(H), L.cleanedLine(H)))
	if K.steps and KS.steps then
		print("    " .. carriers(K, KS))
	end
end
print(fmt("total flips %d, largest |ΔD| %.4f", total, biggest))
