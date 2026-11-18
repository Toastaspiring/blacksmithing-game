--!nocheck
-- Real swords: a buried sheet with a hair past the blade's rim, by slot.
local V = require("./v1")
local fmt = string.format
local I = V.I
local function try(name, base, F, label)
	local Ra = V.emu(V.copyParts(base))
	local KF = V.copyParts(base)
	table.insert(KF, F)
	local ok = V.valid(KF)
	local text = V.show(KF, { "F" }, 0.00025)
	local Rb = V.emu(KF)
	local worst, tier, step = V.dDiff(Ra, Rb)
	print(fmt("%s %s valid %s: %s\n    K: %s | K + F: %s | |dD| %.4f %s%s", name, label, tostring(ok), text, V.dline(Ra), V.dline(Rb), worst, step, if tier then " TIER" else ""))
end
local c05 = V.fixture("C05")
for _, slot in ipairs({ "Guard", "Blade" }) do
	for _, p in ipairs({ 0.0005, 0.002, 0.0034, 0.004, 0.006, 0.01 }) do
		try("C05", c05, V.part("F", "Block", slot, { 0.25 + p, 2.58, 0 }, I, { 1.0, 2.0, 0.02 }), fmt("%s sheet 1.0 x 2.0 x 0.02, rim %.4f past", slot, p))
	end
end
local c02 = V.fixture("C02 Arming (Iron)")
for _, slot in ipairs({ "Guard", "Blade" }) do
	for _, p in ipairs({ 0.001, 0.004, 0.006, 0.01 }) do
		try("C02", c02, V.part("F", "Block", slot, { p, 2.65, 0 }, I, { 0.2, 2.3, 0.02 }), fmt("%s sheet 0.2 x 2.3 x 0.02, rim %.4f past +X", slot, p))
	end
end
local c08 = V.fixture("C08")
for _, slot in ipairs({ "Guard", "Blade" }) do
	for _, p in ipairs({ 0.001, 0.004, 0.006, 0.01 }) do
		try("C08", c08, V.part("F", "Block", slot, { p, 3.18, 0 }, I, { 0.3, 2.6, 0.02 }), fmt("%s sheet 0.3 x 2.6 x 0.02, rim %.4f past +X", slot, p))
	end
end
