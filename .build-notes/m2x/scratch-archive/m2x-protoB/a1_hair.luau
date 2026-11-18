--!nocheck
-- A filler that really does not show, kept through a hairline through its patches' centres; through the emulator.
local V = require("./v1")
local fmt = string.format
local I = V.I

local function hilt()
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end

local function sandwich(w, L, c, k, g)
	local y = 1.45 + L / 2
	local parts = hilt()
	local half = (w - g) / 4 -- centre of each strip from x = 0: g/2 + (w/2 - g/2)/2
	local sw = (w - g) / 2
	local xc = g / 2 + sw / 2
	for _, s in ipairs({ 1, -1 }) do
		local z = s * (k / 2 + c / 2)
		table.insert(parts, V.part("Strip", "Block", "Blade", { xc, y, z }, I, { sw, L, c }))
		table.insert(parts, V.part("Strip", "Block", "Blade", { -xc, y, z }, I, { sw, L, c }))
	end
	-- the frame over the core's rims
	table.insert(parts, V.part("Tip", "Block", "Blade", { 0, 1.45 + L + 0.02, 0 }, I, { w + 0.08, 0.04, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { w / 2 + 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { -w / 2 - 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	return parts, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { w, L, k })
end

print("-- K: cheeks in 2 strips each with a slit g at x = 0, a frame, a hilt, nothing between the cheeks. K + F: F, the core in that gap, its faces behind the cheeks.")
for _, def in ipairs({ { 1.0, 2.0, 0.03, 0.02 }, { 1.0, 2.0, 0.02, 0.02 }, { 1.0, 2.0, 0.05, 0.02 }, { 1.2, 2.5, 0.03, 0.02 }, { 0.6, 2.5, 0.03, 0.02 }, { 0.8, 3.0, 0.02, 0.02 } }) do
	for _, g in ipairs({ 0.002, 0.001, 0.0001, 0.00001 }) do
		local K, F = sandwich(def[1], def[2], def[3], def[4], g)
		local KF = V.copyParts(K)
		table.insert(KF, F)
		local ok = V.valid(KF)
		local Ra = V.emu(V.copyParts(K))
		local Rb = V.emu(KF)
		local text = V.show(KF, { "Core" }, 0.00025)
		local worst, tier, step = V.dDiff(Ra, Rb)
		print(fmt("w %.1f L %.1f c %.3f k %.3f slit %.5f valid %s: %s\n    K: %s | K + F: %s | |dD| %.4f %s%s", def[1], def[2], def[3], def[4], g, tostring(ok), text, V.dline(Ra), V.dline(Rb), worst, step, if tier then " TIER" else ""))
	end
end
