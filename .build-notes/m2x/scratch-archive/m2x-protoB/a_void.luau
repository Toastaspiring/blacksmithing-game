--!nocheck
-- (a) Hidden parts. A filler in a closed cavity; thin fillers covered by a polygon of flats; a core under many sheets; a flush filler larger than the part it swallows.
local L = require("./lib")
local T = L.T
local fmt = string.format
local I, Z90 = L.I, L.Z90
T.SPACING, T.MAX_LINES, T.BALL_POINTS = 0.001, 3000, 200000

local function hilt(gx, gz)
	return {
		L.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		L.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		L.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { gx or 1.10, 0.16, gz or 0.30 }),
	}
end

local function compare(name, K, F, labels)
	local KF = L.copyParts(K)
	for _, f in ipairs(F) do table.insert(KF, L.copyPart(f)) end
	local w, tier, step, Rv, Rt, shares, read, real = L.vsTruth(KF)
	local t = {}
	for i, p in ipairs(KF) do
		for _, l in ipairs(labels) do
			if p.label == l then
				table.insert(t, fmt("%s#%d(%s) true %.3f%% read %.3f%% %s", l, i, p.shape, (shares[i] or 0) * 100, (read[i] or 0) * 100, if real.kept[i] then "kept" else "CLEANED"))
			end
		end
	end
	local RK = L.emu(L.copyParts(K))
	local wk, tk, sk = L.dDiff(RK, Rv)
	print(fmt("%s [%d parts, %s]\n   %s\n   K alone %s\n   K + F   %s\n   |dD| %.4f %s%s  (truth's verdict on K + F: %s, |dD| vs build %.4f)", name, #KF, L.ok(KF), table.concat(t, "; "), L.dline(RK), L.dline(Rv), wk, sk, if tk then " TIER FLIP" else "", L.dline(Rt), w))
end

-- 1. A closed hollow blade: 6 walls; a block floats in the cavity on a strut
local function box(w, len, th, wall)
	local parts = hilt(w + 2 * wall + 0.1, math.min(0.6, th + 2 * wall + 0.1))
	local y = 1.48 + wall + len / 2
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
	table.insert(parts, L.part("Wall", "Block", "Blade", { w / 2 + wall / 2, y, 0 }, I, { wall, len, th + 2 * wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { -w / 2 - wall / 2, y, 0 }, I, { wall, len, th + 2 * wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { 0, y, th / 2 + wall / 2 }, I, { w, len, wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { 0, y, -th / 2 - wall / 2 }, I, { w, len, wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { 0, y + len / 2 + wall / 2, 0 }, I, { w + 2 * wall, wall, th + 2 * wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { 0, y - len / 2 - wall / 2, 0 }, I, { w + 2 * wall, wall, th + 2 * wall }))
	return parts, y
end
for _, c in ipairs({ { 0.6, 3.0, 0.10, 0.02, 0.03 }, { 0.6, 3.0, 0.20, 0.02, 0.03 }, { 1.0, 3.0, 0.20, 0.03, 0.03 }, { 0.3, 3.0, 0.12, 0.02, 0.02 } }) do
	local w, len, th, wall, clear = c[1], c[2], c[3], c[4], c[5]
	local K, y = box(w, len, th, wall)
	local F = {
		L.part("Fill", "Block", "Guard", { 0, y, 0 }, I, { w - 2 * clear, len - 2 * clear, th - 2 * clear }),
		L.part("Strut", "Block", "Guard", { 0, y - len / 2 + clear / 2, 0 }, I, { 0.1, clear + 0.002, 0.02 }),
	}
	compare(fmt("closed box %.2f x %.1f x %.2f, walls %.2f: a block in the cavity, %.2f clear of all but a strut", w, len, th, wall, clear), K, F, { "Fill" })
end

-- 2. A rod truly hidden: a regular polygon of flats inside the probe's reach, its seams split by a hair at the rod's directions
local function polygonTube(n, r, len, hair, roll)
	local parts = hilt(2 * r + 0.3, math.min(0.6, 2 * r + 0.2))
	local y = 1.48 + len / 2
	local a = (r + 0.012) * math.cos(math.pi / n) - 1e-5 -- apothem: the probe at a seam is inside the flats by a hair, the rod clear of them if a >= r
	if a < r then return nil end
	local half = (a + 0.04) * math.tan(math.pi / n) -- half width of a flat, flush seam on the inner plane plus the wedge of its thickness
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip" }
	for k = 0, n - 1 do
		local ang = (k + 0.5) * 360 / n + (roll or 0)
		local c, s = math.cos(math.rad(ang)), math.sin(math.rad(ang))
		local inner = a * math.tan(math.pi / n)
		-- the flat spans the side of the inner polygon less the hair
		local q = L.axisAngle(0, 1, 0, -ang + 90)
		table.insert(parts, L.part("Flat", "Block", slots[k + 1], { (a + 0.02) * c, y, (a + 0.02) * s }, q, { 2 * inner - hair, len, 0.04 }))
	end
	table.insert(parts, L.part("Cap", "Block", "Pommel", { 0, y + len / 2 + 0.02, 0 }, I, { 2 * a + 0.2, 0.04, math.min(0.6, 2 * a + 0.2) }))
	return parts, y
end
for _, c in ipairs({ { 8, 0.10, 3.0 }, { 8, 0.09, 2.5 }, { 12, 0.20, 3.0 }, { 16, 0.25, 3.0 } }) do
	local n, r, len = c[1], c[2], c[3]
	-- rod directions at 45 deg steps (nth = 8) or 22.5: seams at multiples of 360/n fall on a direction when 360/n is a multiple of 45 or 22.5...
	local K, y = polygonTube(n, r, len, 1e-5, 0)
	if K then
		local F = { L.part("Rod", "Cylinder", "Blade", { 0, y, 0 }, Z90, { len, 2 * r, 2 * r }) }
		compare(fmt("rod r %.2f x %.1f in a %d-sided tube, seams 1e-5", r, len, n), K, F, { "Rod" })
	end
end
