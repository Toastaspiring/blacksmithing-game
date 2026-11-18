--!nocheck
-- (a) "The limit is the 2 % rule itself": how far above 2 % can a kept part be, and be cleaned by parts each under 2 %? k sheets in the gap of a laminate, each poking past the core's rim.
local L = require("./lib")
local T = L.T
local fmt = string.format
local I, Z90 = L.I, L.Z90
T.SPACING, T.MAX_LINES = 0.001, 3000

local function hilt()
	return {
		L.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		L.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		L.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end

local function show(name, K, F, labels)
	local KF = L.copyParts(K)
	for _, f in ipairs(F) do table.insert(KF, L.copyPart(f)) end
	local w, tier, step, Rv, Rt, shares, read, real = L.vsTruth(KF)
	local sK = T.all(K)
	local t = {}
	for i, p in ipairs(KF) do
		for _, l in ipairs(labels) do
			if p.label == l then
				table.insert(t, fmt("%s#%d true %.2f%% (alone %s) read %.2f%% %s", l, i, (shares[i] or 0) * 100, if sK[i] then fmt("%.2f%%", sK[i] * 100) else "-", (read[i] or 0) * 100, if real.kept[i] then "kept" else "CLEANED"))
			end
		end
	end
	local RK = L.emu(L.copyParts(K))
	local wk, tk, sk = L.dDiff(RK, Rv)
	print(fmt("%s [%d parts, %s]\n   %s\n   K alone %s\n   K + F   %s\n   |dD| %.4f %s%s", name, #KF, L.ok(KF), table.concat(t, "; "), L.dline(RK), L.dline(Rv), wk, sk, if tk then " TIER FLIP" else ""))
end

for _, c in ipairs({ { 0.04, 4, 0.02 }, { 0.06, 6, 0.02 }, { 0.10, 10, 0.02 }, { 0.14, 14, 0.02 } }) do
	local gap, n, t = c[1], c[2], c[3]
	local w, len, ch = 1.1, 2.0, 0.06
	local y = 1.45 + len / 2
	local K = hilt()
	table.insert(K, L.part("Cheek", "Block", "Blade", { 0, y, gap / 2 + ch / 2 }, I, { w, len, ch }))
	table.insert(K, L.part("Cheek", "Block", "Blade", { 0, y, -(gap / 2 + ch / 2) }, I, { w, len, ch }))
	table.insert(K, L.part("Top", "Block", "Blade", { 0, 1.45 + len + 0.02, 0 }, I, { w, 0.04, gap + 2 * ch }))
	table.insert(K, L.part("Core", "Block", "Blade", { 0, y, 0 }, I, { 0.95, len, gap }))
	-- n sheets, overlapping in z, each 0.016 wider than the core per side
	local F = {}
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip", "Grip" }
	for k = 1, n do
		local z = -gap / 2 + t / 2 + (k - 1) * (gap - t) / math.max(1, n - 1)
		table.insert(F, L.part("Sheet", "Block", slots[k], { 0, y, z }, I, { 0.95 + 2 * 0.016, len, t }))
	end
	show(fmt("laminate gap %.2f: core %.2f wide + %d sheets", gap, 0.95, n), K, F, { "Core", "Sheet" })
end
