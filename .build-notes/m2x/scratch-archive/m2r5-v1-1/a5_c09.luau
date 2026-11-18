--!nocheck
-- C09 sits 0.0096 under Hard on Sharpening. Its blade core split along a hairline at x = 0 (invisible, connected); fillers inside it read the hairline through their patches' centres and are kept, true 0.00 %.
-- Kept parts coarsen the measure's grid and use its sub-grid budget, so they reach the rest of the design.
local V = require("./v1")
local fmt = string.format
local I = V.I
local base = V.fixture("C09")
local g = 0.00001
local K = V.copyParts(base)
local core = K[12]
local sx = core.size[1]
local w = (sx - g) / 2
core.pos = { -g / 2 - w / 2, core.pos[2], core.pos[3] }
core.size = { w, core.size[2], core.size[3] }
local half = V.copyPart(core)
half.pos = { g / 2 + w / 2, core.pos[2], core.pos[3] }
table.insert(K, half)
local Ra0 = V.emu(V.copyParts(base))
local Ra = V.emu(V.copyParts(K))
print("C09:      ", V.dline(Ra0))
print("C09 split:", V.dline(Ra))
local P = V.prep(K)
local ex0 = V.Sampling.exposure(P)
print(fmt("split: hSurf %.3f surfSamples %d subSampled %d", ex0.hSurf, ex0.surfSamples, ex0.subSampled))
local SLOTS = { "Blade", "Blade", "Blade", "Blade", "Grip" }
for n = 1, 5 do
	local KF = V.copyParts(K)
	for i = 1, n do
		local y = 1.55 + 0.45 * i
		table.insert(KF, V.part("F" .. i, "Block", SLOTS[i], { 0, y, 0 }, I, { sx - 0.004, 0.42, 0.04 - 0.004 * i }))
	end
	local text, ex = V.show(KF, { "F1", "F" .. n }, 0.00025)
	local Rb = V.emu(KF)
	local worst, tier, step = V.dDiff(Ra, Rb)
	print(fmt("%d fillers: hSurf %.3f subSampled %d cleaned %d | %s | %s | |dD| %.4f %s%s", n, ex.hSurf, ex.subSampled, #ex.cleaned, text, V.dline(Rb), worst, step, if tier then " TIER" else ""))
end
