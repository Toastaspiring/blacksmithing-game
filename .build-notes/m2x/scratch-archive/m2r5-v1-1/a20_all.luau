--!nocheck
-- Every attack, one line each: run in the base folder and in each alt folder.
local V = require("./v1")
local Sets = require("./b_sets")
local fmt = string.format
local I = V.I
local S45 = 0.70710678118654757
local QP = { S45, 0, 0, S45 }

local function hilt()
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end
local function apex(label, slot, ax, ay, az, b, h)
	local hx, hy, hz = b / 2, h / 2, b / 2
	return V.part(label, "CornerWedge", slot, { ax - hx, ay - hz, az - hy }, QP, { b, h, b })
end
local function cheeks(w, L, c, k, g, y, oneFace)
	local parts = hilt()
	local sw = (w - g) / 2
	local xc = g / 2 + sw / 2
	table.insert(parts, V.part("Strip", "Block", "Blade", { xc, y, k / 2 + c / 2 }, I, { sw, L, c }))
	table.insert(parts, V.part("Strip", "Block", "Blade", { -xc, y, k / 2 + c / 2 }, I, { sw, L, c }))
	if oneFace then
		table.insert(parts, V.part("Cheek", "Block", "Blade", { 0, y, -k / 2 - c / 2 }, I, { w, L, c }))
	else
		table.insert(parts, V.part("Strip", "Block", "Blade", { xc, y, -k / 2 - c / 2 }, I, { sw, L, c }))
		table.insert(parts, V.part("Strip", "Block", "Blade", { -xc, y, -k / 2 - c / 2 }, I, { sw, L, c }))
	end
	table.insert(parts, V.part("Tip", "Block", "Blade", { 0, 1.45 + L + 0.02, 0 }, I, { w + 0.08, 0.04, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { w / 2 + 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { -w / 2 - 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	return parts
end
local function row(name, K, KF)
	local Ra, Rb = V.emu(V.copyParts(K)), V.emu(V.copyParts(KF))
	local w, tier = V.dDiff(Ra, Rb)
	print(fmt("%-44s |dD| %.4f%s   K %s | K+ %s", name, w, if tier then " TIER" else "     ", V.dline(Ra), V.dline(Rb)))
end
-- 1 the hairline: a hollow blade, a filler behind a hairline through its patches' centres
do
	local L, c, k, g = 2.0, 0.05, 0.02, 0.00001
	local y = 1.45 + L / 2
	local K = cheeks(1.0, L, c, k, g, y, false)
	local KF = V.copyParts(K)
	table.insert(KF, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { 1.0, L, k }))
	row("hairline: hidden core, true 0.00 %", K, KF)
end
-- 2 pins: a kept core, tiny apices poking at the reading points
do
	local L, c, k, g = 2.0, 0.05, 0.02, 0.08
	local y = 1.45 + L / 2
	local K = cheeks(1.0, L, c, k, g, y, true)
	table.insert(K, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { 1.0, L, k }))
	local KF = V.copyParts(K)
	for _, yc in ipairs({ 1.65, 2.05, 2.45 }) do
		table.insert(KF, apex("Pin", "Guard", 0.0003, yc + 0.0003, k / 2 + 0.0125, 0.12, c + k + 0.0125 - 0.0005))
	end
	row("pins: 3 apices, core true 3.8 %", K, KF)
end
-- 3 no poke: the apex 1e-8 under the surface, lower ids
do
	local L, c, k, g = 2.0, 0.08, 0.02, 0.08
	local y = 1.45 + L / 2
	local K = cheeks(1.0, L, c, k, g, y, true)
	local core = V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { 1.0, L, k })
	local KF = V.copyParts(K)
	table.insert(K, V.copyPart(core))
	for _, yc in ipairs({ 1.65, 2.05, 2.45 }) do
		table.insert(KF, apex("Pin", "Guard", 0, yc, k / 2 - 1e-8, 0.14, c + k - 2e-3))
	end
	table.insert(KF, V.copyPart(core))
	row("no poke: 3 apices 1e-8 under, lower ids", K, KF)
end
-- 4 the skin: plates wholly inside a real blade, flush, lower ids
local function skin(h, t)
	local sx, sy, sz = h.size[1], h.size[2], h.size[3]
	local cx, cy, cz = h.pos[1], h.pos[2], h.pos[3]
	return {
		V.part("Skin", "Block", "Guard", { cx, cy, cz + sz / 2 - t / 2 }, I, { sx, sy, t }),
		V.part("Skin", "Block", "Guard", { cx, cy, cz - sz / 2 + t / 2 }, I, { sx, sy, t }),
		V.part("Skin", "Block", "Pommel", { cx + sx / 2 - t / 2, cy, cz }, I, { t, sy, sz }),
		V.part("Skin", "Block", "Pommel", { cx - sx / 2 + t / 2, cy, cz }, I, { t, sy, sz }),
	}
end
for _, def in ipairs({ { "F5", 4 }, { "C02 Arming (Iron)", 4 }, { "C05", 4 } }) do
	local base = V.fixture(def[1])
	local KF = skin(base[def[2]], 0.02)
	for _, p in ipairs(base) do table.insert(KF, V.copyPart(p)) end
	row(def[1] .. ": 4 flush plates inside, lower ids", base, KF)
end
-- 5 ids and copies, C09 a hair closer to Hard
local function longer(dl)
	local base = V.fixture("C09")
	for _, i in ipairs({ 12, 13, 14, 15, 16 }) do
		base[i].size = if i == 12 then { base[i].size[1], base[i].size[2] + dl, base[i].size[3] } else { base[i].size[1] + dl, base[i].size[2], base[i].size[3] }
		base[i].pos = { base[i].pos[1], base[i].pos[2] + dl / 2, base[i].pos[3] }
	end
	for _, i in ipairs({ 17, 18 }) do
		base[i].pos = { base[i].pos[1], base[i].pos[2] + dl, base[i].pos[3] }
	end
	return base
end
do
	local base = longer(0.03)
	local p = V.copyParts(base)
	local q = table.remove(p, 15)
	table.insert(p, 1, q)
	row("C09 + 0.03: part 15's id first", base, p)
	local c = V.copyParts(base)
	table.insert(c, 1, V.copyPart(base[15]))
	row("C09 + 0.03: an exact copy of 15 first", base, c)
	local c9 = V.fixture("C09")
	local d = V.copyParts(c9)
	for _, i in ipairs({ 13, 14, 15, 16, 17 }) do table.insert(d, 1, V.copyPart(c9[i])) end
	row("C09: exact copies of 13..17 first", c9, d)
end
-- 6 the fuller: the build's verdict against truth's
local function fuller(name)
	for _, d in ipairs(Sets.get("fuller")) do
		if d.name == name then
			local parts = d.parts
			V.renumber(parts)
			local shares = V.T.all(parts, 0.0005)
			local row2 = {}
			for i = 1, #parts do row2[i] = shares[i] ~= false and shares[i] >= 0.02 end
			local real, read = V.reads(parts)
			local Rv, Rt = V.emu(parts), V.emu(parts, row2)
			local w, tier = V.dDiff(Rv, Rt)
			print(fmt("%-44s |dD| %.4f%s   build %s | truth %s | core true %.2f %% read %.2f %% %s", "fuller " .. name, w, if tier then " TIER" else "     ", V.dline(Rv), V.dline(Rt), shares[4] * 100, read[4] * 100, if real.kept[4] then "kept" else "CLEANED"))
		end
	end
end
fuller("w0.3 L2.5 t0.04 c0.030 g0.03 at0.5 twin")
fuller("w0.2 L2.5 t0.04 c0.030 g0.02 at0.5 twin")
fuller("w0.8 L2.5 t0.08 c0.030 g0.01 at0.5 one")
