--!nocheck
-- A real sword, its main blade block split flush at x = c along a hairline g: a filler inside it reads the hairline through its patches' centres.
local V = require("./v1")
local fmt = string.format
local I = V.I
local function run(name, bladeIndex, g, e, slot)
	local base = V.fixture(name)
	local blade = base[bladeIndex]
	assert(blade.shape == "Block" and blade.rot[4] == 1 or true)
	local sx = blade.size[1]
	local K = V.copyParts(base)
	local bx = blade.pos[1]
	local w = (sx - g) / 2
	K[bladeIndex].pos = { bx - g / 2 - w / 2, blade.pos[2], blade.pos[3] }
	K[bladeIndex].size = { w, blade.size[2], blade.size[3] }
	local half = V.copyPart(K[bladeIndex])
	half.pos = { bx + g / 2 + w / 2, blade.pos[2], blade.pos[3] }
	table.insert(K, half)
	local Rbase = V.emu(V.copyParts(base))
	local Ra = V.emu(V.copyParts(K))
	local KF = V.copyParts(K)
	local F = V.part("F", "Block", slot, { bx, blade.pos[2], blade.pos[3] }, I, { sx - 2 * e, blade.size[2] - 0.2, 0.02 })
	table.insert(KF, F)
	local ok = V.valid(KF)
	local text = V.show(KF, { "F" }, 0.0005)
	local Rb = V.emu(KF)
	local worst, tier, step = V.dDiff(Ra, Rb)
	print(fmt("%s split g %.5f, %s filler rim %.3f inside, valid %s: %s\n    base %s\n    K    %s\n    K+F  %s | |dD| %.4f %s%s", name, g, slot, e, tostring(ok), text, V.dline(Rbase), V.dline(Ra), V.dline(Rb), worst, step, if tier then " TIER" else ""))
end
for _, def in ipairs({ { "F3", 6 }, { "C04", 0 }, { "C08", 4 }, { "C02 Arming (Iron)", 4 }, { "F5", 4 }, { "C05", 4 } }) do
	local index = def[2]
	if index == 0 then
		for i, p in ipairs(V.fixture(def[1])) do
			if p.slot == "Blade" and p.shape == "Block" and index == 0 then index = i end
		end
	end
	for _, slot in ipairs({ "Guard", "Blade" }) do
		for _, e in ipairs({ 0.002, 0.004 }) do
			run(def[1], index, 0.00001, e, slot)
		end
	end
end
