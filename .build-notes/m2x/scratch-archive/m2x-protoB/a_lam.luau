--!nocheck
-- A solid blade against the same solid in flush layers: nothing a player can see changes. Interior layers show only their rims: under 2 % when the plate is wide and long. T-DIF-07's flush re-segmentation, along Z.
local L = require("./lib")
local T = L.T
local fmt = string.format
local I, Z90 = L.I, L.Z90
T.SPACING, T.MAX_LINES = 0.001, 3000
local function hilt(gx)
	return {
		L.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		L.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		L.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { gx or 1.60, 0.16, 0.30 }),
	}
end
for _, c in ipairs({ { 0.6, 3.0, 0.14, 7 }, { 1.0, 3.0, 0.14, 7 }, { 1.5, 3.4, 0.08, 4 }, { 1.5, 3.4, 0.12, 6 }, { 1.5, 3.4, 0.14, 7 }, { 1.6, 3.5, 0.20, 10 }, { 1.6, 3.5, 0.16, 8 } }) do
	local w, len, t, n = c[1], c[2], c[3], c[4]
	local y = 1.47 + len / 2
	local solid = hilt()
	table.insert(solid, L.part("Blade", "Block", "Blade", { 0, y, 0 }, I, { w, len, t }))
	local lam = hilt()
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
	for k = 1, n do
		local z = -t / 2 + (k - 0.5) * t / n
		table.insert(lam, L.part("Layer", "Block", slots[k], { 0, y, z }, I, { w, len, t / n }))
	end
	local Ra, Rb = L.emu(L.copyParts(solid)), L.emu(L.copyParts(lam))
	local d, tier, step = L.dDiff(Ra, Rb)
	local real, read = L.reads(L.copyParts(lam))
	local shares = T.all(L.copyParts(lam))
	local cleaned, lo, hi = 0, 1, 0
	for i = 4, #lam do
		if not real.kept[i] then cleaned += 1 end
		if i > 4 and i < #lam then
			lo, hi = math.min(lo, shares[i]), math.max(hi, shares[i])
		end
	end
	print(fmt("%.1f x %.1f x %.2f, %d layers: interior true %.2f..%.2f %%, %d cleaned | solid %s | layers %s | |dD| %.4f %s%s | %s", w, len, t, n, lo * 100, hi * 100, cleaned, L.dline(Ra), L.dline(Rb), d, step, if tier then " TIER" else "", L.ok(lam)))
end
