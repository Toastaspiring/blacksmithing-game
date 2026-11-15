--!nocheck
-- fix-2: the attack designs' readings against their truth, and the two caged-Ball swords, on a tree (LAB_ROOT, default the repo)
local process = require("@lune/process")
local ROOT = process.env.LAB_ROOT or "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local function req(p) return (require :: any)(ROOT .. "/" .. p) end
local H = req("tests/Physics/PhysicsHelpers")
local Attacks = req("tests/Physics/CoverAttacks")
local Sampling = req("src/shared/Physics/Sampling")
local Shapes = req("src/shared/Physics/Shapes")
local Oracle = req("tests/Physics/VisibleOracle")
local fmt = string.format
local function prep(parts) local P = {} for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end return P end
local worst = 0
for _, d in ipairs(Attacks) do
	local P = prep(d.parts)
	local r = H.reads(P, d.target)
	local kept = Sampling.exposure(P).kept[d.target]
	worst = math.max(worst, math.abs(r - d.truth))
	print(fmt("%-55s %-8s reads %7.3f %%  truth %7.3f %%  diff %+7.3f  kept %s (truth's %s)", string.sub(d.name, 1, 55), P[d.target].shape, 100 * r, 100 * d.truth, 100 * (r - d.truth), tostring(kept), tostring(d.kept)))
end
print(fmt("largest |reading - truth| %.4f", worst))
local function cagedSword(r, g, b, thick)
	local c = { 0, 2.4, 0 }
	local wall, span, E = 0.02, 2 * r + 0.1, r + 0.06
	local low, high = c[2] - (r + g + wall), c[2] + (r + g + wall)
	local parts = {
		H.part(1, "Grip", "Block", "Iron", { 0, 0.75, 0 }, H.I, { 0.16, 0.9, 0.16 }),
		H.part(2, "Guard", "Block", "Iron", { 0, 1.29, 0 }, H.I, { 1, 0.18, 0.24 }),
		H.part(3, "Blade", "Block", "Iron", { 0, (1.38 + low) / 2, 0 }, H.I, { 0.16, low - 1.38, thick }),
		H.part(4, "Blade", "Block", "Iron", { 0, (high + 4) / 2, 0 }, H.I, { 0.16, 4 - high, thick }),
		H.part(5, "Blade", "Ball", "Iron", c, H.I, { 2 * r, 2 * r, 2 * r }),
	}
	local wallSlots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Pommel" }
	for a = 1, 3 do
		for _, s in ipairs({ -1, 1 }) do
			local pos, size = table.clone(c), { span, span, span }
			pos[a] += s * (r + g + wall / 2)
			size[a] = wall
			table.insert(parts, H.part(#parts + 1, wallSlots[#parts - 4], "Block", "Iron", pos, H.I, size))
		end
	end
	local edgeSlots = { "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip" }
	for a = 1, 3 do
		for o = a + 1, 3 do
			for _, sa in ipairs({ -1, 1 }) do
				for _, so in ipairs({ -1, 1 }) do
					local lo, hi = { -E, -E, -E }, { E, E, E }
					lo[a], hi[a] = if sa > 0 then b else -E, if sa > 0 then E else -b
					lo[o], hi[o] = if so > 0 then b else -E, if so > 0 then E else -b
					local pos, size = {}, {}
					for k = 1, 3 do
						pos[k], size[k] = c[k] + (lo[k] + hi[k]) / 2, hi[k] - lo[k]
					end
					table.insert(parts, H.part(#parts + 1, edgeSlots[#parts - 10], "Block", "Iron", pos, H.I, size))
				end
			end
		end
	end
	return parts
end
for _, def in ipairs({ { 0.2, 0.002769, 0.051018, 0.06 }, { 0.08, 0.00537, 0.0302, 0.05 } }) do
	local parts = cagedSword(def[1], def[2], def[3], def[4])
	local P = prep(parts)
	local _, _, hider = Oracle.flags(P)
	print(fmt("caged sword r %.2f: reads %.4f %%, kept %s, truth %.4f %%", def[1], 100 * H.reads(P, 5), tostring(Sampling.exposure(P).kept[5]), 100 * Oracle.measure(P, 5, hider, 2000000)))
end
