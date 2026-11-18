--!nocheck
-- §17.2's numbers, each design rebuilt from its words, through V1's truth and the emulator.
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
local function row(name, K, H, labels)
	local a = V.copyParts(K)
	local b = V.copyParts(K)
	for _, h in ipairs(H) do table.insert(b, V.copyPart(h)) end
	local ta = V.show(a, labels, 0.00025)
	local tb = V.show(b, labels, 0.00025)
	local Ra, Rb = V.emu(a), V.emu(b)
	local w, tier, step = V.dDiff(Ra, Rb)
	print(fmt("%s\n   K     %s | %s\n   K + H %s | %s\n   |dD| %.4f %s%s", name, ta, V.dline(Ra), tb, V.dline(Rb), w, step, if tier then " TIER" else ""))
end
-- C09 + plate, 0 and 5 hidden blocks
do
	local K = V.fixture("C09")
	table.insert(K, V.part("X", "Block", "Blade", { -0.03, 2.6, 0 }, I, { 0.12, 2, 0.05 }))
	local H = {}
	local slots = { "Guard", "Guard", "Guard", "Blade", "Blade" }
	for j = 1, 5 do
		local g = 0.8 - 0.01 * j
		table.insert(H, V.part("Fill", "Block", slots[j], { 0, 2.6, 0 }, I, { 0.12 * g, 2.4 * g, 0.06 * g }))
	end
	row("C09 + plate 0.12 x 2 x 0.05 (20.12 %, Sharpening 0.2660 H with 0 and 5 hidden)", K, H, { "X" })
end
-- the laminate
do
	local w, l, c, k = 1.1, 2.0, 0.06, 0.02
	local y = 1.45 + l / 2
	local K = hilt()
	table.insert(K, V.part("CheekA", "Block", "Blade", { 0, y, k / 2 + c / 2 }, I, { w, l, c }))
	table.insert(K, V.part("CheekB", "Block", "Blade", { 0, y, -(k / 2 + c / 2) }, I, { w, l, c }))
	table.insert(K, V.part("Top", "Block", "Blade", { 0, 1.45 + l + 0.02, 0 }, I, { w, 0.04, k + 2 * c }))
	table.insert(K, V.part("LamCore", "Block", "Blade", { 0, y, 0 }, I, { 0.95, l, k }, "Steel"))
	row("hilt + cheeks 1.1 x 2.0 x 0.06 + core 0.95 x 0.02 (2.01 % kept) + sheet 1.08 (1.77 %), both Enclosed: Ha 0.0250 -> 0.3609, |dD| 0.3359", K, { V.part("Sheet", "Block", "Blade", { 0, y, 0 }, I, { 1.08, l, k }) }, { "LamCore", "Sheet" })
end
-- C05 + strip + buried sheet
do
	local K = V.fixture("C05")
	table.insert(K, V.part("X", "Block", "Blade", { 0.75 + 0.003 - 0.1, 2.58, 0 }, I, { 0.2, 1.6, 0.02 }))
	row("C05 + strip 0.003 past (5.86 %) + sheet 1.0 x 1.8 x 0.02 rim 0.001 further: strip 1.35 % kept, sheet 1.10 % cleaned, |dD| 0", K, { V.part("Sheet", "Block", "Blade", { 0.75 + 0.004 - 0.5, 2.58, 0 }, I, { 1.0, 1.8, 0.02 }) }, { "X", "Sheet" })
end
-- false kept
for _, p in ipairs({ 0.002, 0.004 }) do
	local K = V.fixture("C05")
	row(fmt("C05 + sheet 1.0 x 2.0 x 0.02, rim %.3f past (0.004: true 1.36 %%, kept, 0.1363 -> 0.1400, |dD| 0.0037)", p), K, { V.part("Hair", "Block", "Blade", { 0.25 + p, 2.58, 0 }, I, { 1.0, 2.0, 0.02 }) }, { "Hair" })
end
-- the grip axis row
do
	local F4 = V.fixture("F4")
	local grip
	for _, p in ipairs(F4) do
		if p.slot == "Grip" then grip = p end
	end
	print("F4 grip", grip.shape, grip.pos[1], grip.pos[2], grip.pos[3], grip.size[1], grip.size[2], grip.size[3])
	local function axisRun(a, b)
		local parts = V.copyParts(F4)
		local function bar(deg)
			-- a rod on the grip, its axis deg from +Y about Z: Cylinder local X = +Y is Z90; turn further
			local q = V.Quat.mul(V.axisAngle(0, 0, 1, deg), V.Z90)
			return V.part("Strap", "Cylinder", "Grip", { grip.pos[1], grip.pos[2], grip.pos[3] }, V.Quat.hemisphere(V.Quat.normalize(q)), { 0.8, 0.1, 0.1 })
		end
		table.insert(parts, bar(a))
		table.insert(parts, bar(b))
		local ok, r = V.valid(parts)
		local ph = r.physics
		print(fmt("  parts at %.1f and %.1f deg: valid %s axis (%.5f, %.5f) = %.2f deg, balance %.3f", a, b, tostring(ok), ph.gripAxis[1], ph.gripAxis[2], math.deg(math.atan2(ph.gripAxis[1], ph.gripAxis[2])), ph.balance))
	end
	axisRun(-45.1, 44.9)
	axisRun(-45, 45)
	axisRun(-44.9, 45.1)
	axisRun(0, 0.0001)
end
