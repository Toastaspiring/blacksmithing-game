--!nocheck
-- Fillers that show nothing at all: wholly inside K's neighbours, an apex just touching a kept part's surface at a patch centre, a lower index. And exact copies with a lower index.
local V = require("./v1")
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
local function frame(w, L, c, k, g, y)
	local parts = hilt()
	local sw = (w - g) / 2
	local xc = g / 2 + sw / 2
	table.insert(parts, V.part("Strip", "Block", "Blade", { xc, y, k / 2 + c / 2 }, I, { sw, L, c }))
	table.insert(parts, V.part("Strip", "Block", "Blade", { -xc, y, k / 2 + c / 2 }, I, { sw, L, c }))
	table.insert(parts, V.part("Cheek", "Block", "Blade", { 0, y, -k / 2 - c / 2 }, I, { w, L, c }))
	table.insert(parts, V.part("Tip", "Block", "Blade", { 0, 1.45 + L + 0.02, 0 }, I, { w + 0.08, 0.04, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { w / 2 + 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { -w / 2 - 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
	return parts
end
local function row(title, K, KF, labels)
	local okK, okF = V.valid(K), V.valid(KF)
	local tK, tF = V.show(K, labels, 0.0005), V.show(KF, labels, 0.0002)
	local Ra, Rb = V.emu(V.copyParts(K)), V.emu(V.copyParts(KF))
	local worst, tier, step = V.dDiff(Ra, Rb)
	print(fmt("%s (valid %s, %s)\n  K      %s\n  K + F  %s\n  K: %s | K + F: %s | |dD| %.4f %s%s", title, tostring(okK), tostring(okF), tK, tF, V.dline(Ra), V.dline(Rb), worst, step, if tier then " TIER" else ""))
end

-- (1) the apex stops 1e-8 under the core's +Z face, at x = 0, y = a patch centre: nothing pokes. F comes before the core.
for _, g in ipairs({ 0.08, 0.04 }) do
	local c, k, L = 0.08, 0.02, 2.0
	local y = 1.45 + L / 2
	local K = frame(1.0, L, c, k, g, y)
	local core = V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { 1.0, L, k })
	table.insert(K, core)
	local KF = frame(1.0, L, c, k, g, y)
	for _, yc in ipairs({ 1.65, 2.05, 2.45 }) do
		table.insert(KF, apex("Pin", "Guard", 0, yc, k / 2 - 1e-8, 0.14, c + k - 2e-3))
	end
	table.insert(KF, V.copyPart(core))
	row(fmt("slit %.2f: 3 fillers inside the far cheek and the core, an apex 1e-8 under the core's surface, lower ids", g), K, KF, { "Core", "Pin" })
end

-- (2) an exact copy with the lowest id, on a real sword whose sub-grid budget runs out: the survivor is measured first
do
	local base = V.fixture("C09")
	local Ra = V.emu(V.copyParts(base))
	print("C09:", V.dline(Ra))
	local lo, hi = {}, {}
	local worst, who = 0, 0
	for i = 1, #base do
		local KF = V.copyParts(base)
		local copy = V.copyPart(base[i])
		table.insert(KF, 1, copy)
		local Rb = V.emu(KF)
		local w, tier, step = V.dDiff(Ra, Rb)
		print(fmt("  an exact copy of part %2d (%s %s) as the first part: %s | |dD| %.4f %s%s", i, base[i].slot, base[i].shape, V.dline(Rb), w, step, if tier then " TIER" else ""))
	end
	-- two copies, three, of the late ribs
	local KF = V.copyParts(base)
	for _, i in ipairs({ 13, 14, 15, 16, 17 }) do
		table.insert(KF, 1, V.copyPart(base[i]))
	end
	local Rb = V.emu(KF)
	local w, tier, step = V.dDiff(Ra, Rb)
	print(fmt("  exact copies of parts 13..17 first: %s | |dD| %.4f %s%s", V.dline(Rb), w, step, if tier then " TIER" else ""))
end

-- (2') C09 a hair closer to Hard, its blade longer: an exact copy moves a tier
do
	for _, dl in ipairs({ 0, 0.02, 0.03, 0.04, 0.05, 0.06, 0.08 }) do
		local base = V.fixture("C09")
		for _, i in ipairs({ 12, 13, 14, 15, 16 }) do
			base[i].size = if i == 12 then { base[i].size[1], base[i].size[2] + dl, base[i].size[3] } else { base[i].size[1] + dl, base[i].size[2], base[i].size[3] }
			base[i].pos = { base[i].pos[1], base[i].pos[2] + dl / 2, base[i].pos[3] }
		end
		for _, i in ipairs({ 17, 18 }) do
			base[i].pos = { base[i].pos[1], base[i].pos[2] + dl, base[i].pos[3] }
		end
		local Ra = V.emu(V.copyParts(base))
		local t = {}
		for _, j in ipairs({ 15, 16, 14, 13 }) do
			local KF = V.copyParts(base)
			table.insert(KF, 1, V.copyPart(base[j]))
			local Rb = V.emu(KF)
			local w, tier, step = V.dDiff(Ra, Rb)
			table.insert(t, fmt("copy of %d: Sh %.4f %s, |dD| %.4f%s", j, Rb.steps[3].d, string.sub(Rb.steps[3].tier, 1, 1), w, if tier then " TIER" else ""))
		end
		print(fmt("C09 blade +%.2f: %s | %s", dl, V.dline(Ra), table.concat(t, "; ")))
	end
end

-- (3) an inlay: a plate in a host, its top flush. Its lower id keeps the flush face. An exact copy of the host with a lower id still takes it.
do
	local base = V.fixture("C05")
	local host = base[4]
	local inlay = V.part("Inlay", "Block", "Blade", { 0.25, 2.58, 0.07 - 0.01 }, I, { 0.6, 1.4, 0.02 })
	local K = V.copyParts(base)
	table.insert(K, 1, V.copyPart(inlay))
	local KF = V.copyParts(K)
	table.insert(KF, 1, V.copyPart(host))
	row("C05 + an inlay flush with the blade, id first; + an exact copy of the blade with a lower id still", K, KF, { "Inlay" })
end

-- (4) a Dust speck on a reading point: nothing, and a Dust plate over all of it: nothing
do
	local c, k, L, g = 0.08, 0.02, 2.0, 0.08
	local y = 1.45 + L / 2
	local K = frame(1.0, L, c, k, g, y)
	table.insert(K, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { 1.0, L, k }))
	local KF = V.copyParts(K)
	for _, yc in ipairs({ 1.65, 2.05, 2.45, 2.85 }) do
		table.insert(KF, V.part("Dust", "Block", "Guard", { 0, yc, k / 2 + 0.02 }, I, { 0.05, 0.05, 0.05 }))
	end
	row("4 Dust specks over 4 of the core's 5 reading centres", K, KF, { "Core", "Dust" })
end
