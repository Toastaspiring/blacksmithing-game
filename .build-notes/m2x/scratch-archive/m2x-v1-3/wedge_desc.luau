--!nocheck
-- V1 (m2x, round 3): a Wedge described another way. Wedge (sx, sy, sz) with frame R is the same solid as Wedge (sx, sz, sy)
-- with frame R·M, M the half turn about local (0, 1, −1) (x' = −x, y' = −z, z' = −y). Shapes.prepare's volume 4·hx·hy·hz
-- rounds differently for the two descriptions, and the verdict's rank goes by volume before the slot's name, so a copy
-- in the Guard described the other way can outrank the Blade original and take its faces.
local L = require("./lib")
local Quat = L.Quat
local fmt = string.format

local S = 0.70710678118654757
local M = { 0, S, -S, 0 } -- half turn about (0, 1, −1)/√2

local function other(p, slot)
	local q = Quat.hemisphere(Quat.normalize(Quat.mul(p.rot, M)))
	return L.part(slot, p.shape, p.pos, q, { p.size[1], p.size[3], p.size[2] }, p.material)
end

-- does the other description coincide? max distance between world vertex sets (as sets)
local function vdist(a, b)
	local worst = 0
	for i = 1, #a.wverts, 3 do
		local best = math.huge
		for j = 1, #b.wverts, 3 do
			local dx, dy, dz = a.wverts[i] - b.wverts[j], a.wverts[i + 1] - b.wverts[j + 1], a.wverts[i + 2] - b.wverts[j + 2]
			best = math.min(best, math.sqrt(dx * dx + dy * dy + dz * dz))
		end
		worst = math.max(worst, best)
	end
	return worst
end

local function trial(name, base, wi, slot)
	local parts = L.copyParts(base)
	local w = parts[wi]
	table.insert(parts, other(w, slot))
	L.renumber(parts)
	local P = L.prep(parts)
	local n = #parts
	local rank = L.Sampling.ranked(P)
	local R = L.run(L.copyParts(parts), { measureInvalid = false })
	local kept = R.physics and R.physics.kept or {}
	print(fmt("%s: Wedge %d vol %.17g, its copy (%s) vol %.17g, %s; vertices %.1e apart; rank %d vs %d; kept original %s, copy %s",
		name, wi, P[wi].volume, slot, P[n].volume, if P[n].volume > P[wi].volume then "copy LARGER" elseif P[n].volume < P[wi].volume
			then "copy smaller" else "equal", vdist(P[wi], P[n]), rank[wi], rank[n], tostring(kept[wi]), tostring(kept[n])))
	if kept[n] then
		local Rb = L.emu(L.copyParts(parts), nil)
		local Rbase = L.emu(L.copyParts(base), nil)
		print("   D with the copy:", L.dline(Rb), "| without:", L.dline(Rbase))
	end
end

trial("F3 tip", L.fixture("F3"), 7, "Guard")
trial("F3 tip", L.fixture("F3"), 7, "Grip")
trial("F4 tip", L.fixture("F4"), 5, "Guard")
for _, f in ipairs({ "C02", "C04", "C05", "C06", "C08", "C09", "F1", "F2" }) do
	local base = L.fixture(f)
	for i, p in ipairs(base) do
		if p.shape == "Wedge" and p.slot == "Blade" then
			trial(f .. " part " .. i, base, i, "Guard")
		end
	end
end
-- random sizes: how often do the two descriptions' volumes differ?
local rng = Random and Random.new(1) or nil
local seed = 12345
local function rnd()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local larger, smaller, equal = 0, 0, 0
for _ = 1, 10000 do
	local sx, sy, sz = 0.02 + rnd() * 2, 0.02 + rnd() * 2, 0.02 + rnd() * 2
	local a = 4 * (sx / 2) * (sy / 2) * (sz / 2)
	local b = 4 * (sx / 2) * (sz / 2) * (sy / 2)
	if b > a then
		larger += 1
	elseif b < a then
		smaller += 1
	else
		equal += 1
	end
end
print(fmt("random Wedge sizes: the other description's volume larger %d, smaller %d, equal %d of 10000", larger, smaller, equal))
