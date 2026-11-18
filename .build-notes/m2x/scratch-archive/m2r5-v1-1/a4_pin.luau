--!nocheck
-- §17.2: "only a part that really covers another". Fillers that poke a tiny apex through a kept core's surface, at the patch centres its reading stands on. They cover nothing to speak of.
local V = require("./v1")
local fmt = string.format
local I = V.I
local S45 = 0.70710678118654757
local QP, QM = { S45, 0, 0, S45 }, { -S45, 0, 0, S45 }

local function hilt()
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end

-- A CornerWedge, apex at (ax, ay, az) pointing s·Z, its base b × b, height h, standing away toward -x and (s = 1: -y, s = -1: +y).
local function apex(label, slot, ax, ay, az, s, b, h)
	local hx, hy, hz = b / 2, h / 2, b / 2
	if s > 0 then
		return V.part(label, "CornerWedge", slot, { ax - hx, ay - hz, az - hy }, QP, { b, h, b })
	end
	return V.part(label, "CornerWedge", slot, { ax - hx, ay + hz, az + hy }, QM, { b, h, b })
end

local function design(w, L, c, k, g, twoFaces)
	local y = 1.45 + L / 2
	local parts = hilt()
	local sw = (w - g) / 2
	local xc = g / 2 + sw / 2
	table.insert(parts, V.part("Strip", "Block", "Blade", { xc, y, k / 2 + c / 2 }, I, { sw, L, c }))
	table.insert(parts, V.part("Strip", "Block", "Blade", { -xc, y, k / 2 + c / 2 }, I, { sw, L, c }))
	if twoFaces then
		table.insert(parts, V.part("Strip", "Block", "Blade", { xc, y, -k / 2 - c / 2 }, I, { sw, L, c }))
		table.insert(parts, V.part("Strip", "Block", "Blade", { -xc, y, -k / 2 - c / 2 }, I, { sw, L, c }))
	else
		table.insert(parts, V.part("Cheek", "Block", "Blade", { 0, y, -k / 2 - c / 2 }, I, { w, L, c }))
	end
	table.insert(parts, V.part("Tip", "Block", "Blade", { 0, 1.45 + L + 0.02, 0 }, I, { w + 0.08, 0.04, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { w / 2 + 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { -w / 2 - 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	table.insert(parts, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { w, L, k }))
	return parts
end

local function report(title, K, KF)
	local okK = V.valid(K)
	local okF = V.valid(KF)
	local tK = V.show(K, { "Core" }, 0.0005)
	local tF = V.show(KF, { "Core", "Pin" }, 0.0002)
	local Ra, Rb = V.emu(V.copyParts(K)), V.emu(V.copyParts(KF))
	local worst, tier, step = V.dDiff(Ra, Rb)
	print(fmt("%s (valid %s, %s)\n  K      %s\n  K + F  %s\n  K: %s | K + F: %s | |dD| %.4f %s%s", title, tostring(okK), tostring(okF), tK, tF, V.dline(Ra), V.dline(Rb), worst, step, if tier then " TIER" else ""))
end

-- the core 1.0 x 2.0 x 0.02: 3 x 5 patches of 0.333 x 0.4 on its faces, centres at x = 0, y = 1.65 ... 3.25
for _, def in ipairs({ { 0.05, 0.08, false, 3 }, { 0.05, 0.08, true, 8 }, { 0.08, 0.08, false, 3 }, { 0.08, 0.08, true, 8 } }) do
	local c, g, two, nF = def[1], def[2], def[3], def[4]
	local k = 0.02
	local K = design(1.0, 2.0, c, k, g, two)
	local KF = V.copyParts(K)
	local h = 2 * c + 0.002 -- never out of the far cheek
	h = c + k + 0.0125 - 0.0005
	local placed = 0
	local ys = { 1.65, 2.05, 2.45, 2.85, 3.25 }
	for i = 1, 5 do
		if placed < nF then
			table.insert(KF, apex("Pin", if placed < 5 then "Guard" else "Pommel", 0.0003, ys[i] + 0.0003, k / 2 + 0.0125, 1, 0.12, h))
			placed += 1
		end
		if two and placed < nF then
			table.insert(KF, apex("Pin", if placed < 5 then "Guard" else "Pommel", 0.0003, ys[i] - 0.0003, -k / 2 - 0.0125, -1, 0.12, h))
			placed += 1
		end
	end
	report(fmt("cheeks %.3f, slit %.3f, %s, %d fillers", c, g, if two then "both faces" else "one face", nF), K, KF)
end
