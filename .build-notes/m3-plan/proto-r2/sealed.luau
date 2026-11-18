--!nocheck
-- m3-plan-r2: what the 2 % rule itself admits (§5.6's last row, §17.2 "M3 and the designer: whether the rule should look
-- through a sealed cavity or a stack of layers"), re-measured on the snapshot through the emulator, in part order (how
-- E-S2.12 measured) and in the measure's rank order (the plan). Designs ported from the r2 verifier's a_void.luau (closed
-- box + a block in its cavity on a strut), a_lam.luau (a solid blade against the same blade in flush layers) and
-- a_sheets.luau (a core under k sheets), scratch m2r5-v1-2/.
--   lune run <abs>/proto/sealed.luau
local L = require("./lib")
local Fx = L.Fx
local fmt = string.format

local I, Z90 = Fx.I, Fx.Z90
local function part(label, shape, slot, pos, rot, size, mat)
	return Fx.P(label, shape, slot, mat or "Iron", pos, rot, size)
end
local function hilt(gx, gz)
	return {
		part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { gx or 1.10, 0.16, gz or 0.30 }),
	}
end
local function both(t)
	local b = Fx.bp("x", t)
	return L.run(b), L.run(L.inRankOrder(b))
end
local function dl(R)
	if not R.steps then
		return "INVALID " .. L.cleanedLine(R)
	end
	local d, t = L.dline(R)
	return d .. " " .. t
end
local function worst(a, b)
	local w = 0
	for i, s in ipairs(a.steps) do
		w = math.max(w, math.abs(b.steps[i].d - s.d))
	end
	return w
end

print("1. closed box (6 walls) + a block in the cavity on a strut: K → K + F; part order | rank order")
for _, c in ipairs({ { 0.6, 3.0, 0.10, 0.02, 0.03 }, { 0.6, 3.0, 0.20, 0.02, 0.03 }, { 1.0, 3.0, 0.20, 0.03, 0.03 }, { 0.3, 3.0, 0.12, 0.02, 0.02 } }) do
	local w, len, th, wall, clear = c[1], c[2], c[3], c[4], c[5]
	local K = hilt(w + 2 * wall + 0.1, math.min(0.6, th + 2 * wall + 0.1))
	local y = 1.48 + wall + len / 2
	table.insert(K, part("Wall", "Block", "Blade", { w / 2 + wall / 2, y, 0 }, I, { wall, len, th + 2 * wall }))
	table.insert(K, part("Wall", "Block", "Blade", { -w / 2 - wall / 2, y, 0 }, I, { wall, len, th + 2 * wall }))
	table.insert(K, part("Wall", "Block", "Blade", { 0, y, th / 2 + wall / 2 }, I, { w, len, wall }))
	table.insert(K, part("Wall", "Block", "Blade", { 0, y, -th / 2 - wall / 2 }, I, { w, len, wall }))
	table.insert(K, part("Wall", "Block", "Blade", { 0, y + len / 2 + wall / 2, 0 }, I, { w + 2 * wall, wall, th + 2 * wall }))
	table.insert(K, part("Wall", "Block", "Blade", { 0, y - len / 2 - wall / 2, 0 }, I, { w + 2 * wall, wall, th + 2 * wall }))
	local KF = table.clone(K)
	table.insert(KF, part("Fill", "Block", "Guard", { 0, y, 0 }, I, { w - 2 * clear, len - 2 * clear, th - 2 * clear }))
	table.insert(KF, part("Strut", "Block", "Guard", { 0, y - len / 2 + clear / 2, 0 }, I, { 0.1, clear + 0.002, 0.02 }))
	local a1, a2 = both(K)
	local b1, b2 = both(KF)
	print(fmt("  %.2f × %.1f × %.2f walls %.2f clear %.2f: K %s → K+F %s |ΔD| %.4f  |  rank: K %s → K+F %s |ΔD| %.4f", w, len, th,
		wall, clear, dl(a1), dl(b1), worst(a1, b1), dl(a2), dl(b2), worst(a2, b2)))
end

print("2. a solid blade against the same blade in n flush layers (along Z): part order | rank order")
for _, c in ipairs({ { 0.6, 3.0, 0.14, 7 }, { 1.0, 3.0, 0.14, 7 }, { 1.5, 3.4, 0.08, 4 }, { 1.5, 3.4, 0.12, 6 }, { 1.5, 3.4, 0.14, 7 }, { 1.6, 3.5, 0.20, 10 }, { 1.6, 3.5, 0.16, 8 } }) do
	local w, len, t, n = c[1], c[2], c[3], c[4]
	local y = 1.47 + len / 2
	local solid = hilt(1.60)
	table.insert(solid, part("Blade", "Block", "Blade", { 0, y, 0 }, I, { w, len, t }))
	local lam = hilt(1.60)
	for k = 1, n do
		local z = -t / 2 + (k - 0.5) * t / n
		table.insert(lam, part("Layer", "Block", "Blade", { 0, y, z }, I, { w, len, t / n }))
	end
	local a1, a2 = both(solid)
	local b1, b2 = both(lam)
	print(fmt("  %.1f × %.1f × %.2f, %d layers: solid %s → layers %s cleaned %s |ΔD| %.4f  |  rank: %s → %s |ΔD| %.4f", w, len, t, n,
		dl(a1), dl(b1), L.cleanedLine(b1), worst(a1, b1), dl(a2), dl(b2), worst(a2, b2)))
end

print("3. a laminate whose core shows, under k sheets in its gap: K → K + sheets; part order | rank order")
for _, c in ipairs({ { 0.04, 4, 0.02 }, { 0.06, 6, 0.02 }, { 0.10, 10, 0.02 }, { 0.14, 14, 0.02 } }) do
	local gap, n, t = c[1], c[2], c[3]
	local w, len, ch = 1.1, 2.0, 0.06
	local y = 1.45 + len / 2
	local K = hilt()
	table.insert(K, part("Cheek", "Block", "Blade", { 0, y, gap / 2 + ch / 2 }, I, { w, len, ch }))
	table.insert(K, part("Cheek", "Block", "Blade", { 0, y, -(gap / 2 + ch / 2) }, I, { w, len, ch }))
	table.insert(K, part("Top", "Block", "Blade", { 0, 1.45 + len + 0.02, 0 }, I, { w, 0.04, gap + 2 * ch }))
	table.insert(K, part("Core", "Block", "Blade", { 0, y, 0 }, I, { 0.95, len, gap }))
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard",
		"Guard", "Guard", "Grip", "Grip" }
	local KF = table.clone(K)
	for k = 1, n do
		local z = -gap / 2 + t / 2 + (k - 1) * (gap - t) / math.max(1, n - 1)
		table.insert(KF, part("Sheet", "Block", slots[k], { 0, y, z }, I, { 0.95 + 2 * 0.016, len, t }))
	end
	local a1, a2 = both(K)
	local b1, b2 = both(KF)
	print(fmt("  gap %.2f, core 0.95 + %d sheets: K %s → K+S %s cleaned %s |ΔD| %.4f  |  rank: %s → %s |ΔD| %.4f", gap, n, dl(a1),
		dl(b1), L.cleanedLine(b1), worst(a1, b1), dl(a2), dl(b2), worst(a2, b2)))
end
