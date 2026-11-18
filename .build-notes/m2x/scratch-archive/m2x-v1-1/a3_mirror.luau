--!nocheck
-- A3: §4.4/§17.2 say a mirror image across X or Z reads its original's "but for true twins". Two parts that are no twins
-- but tie on volume, cy and |cx| (opposite cx) swap rank under the X mirror; with a coplanar face in common, the one that
-- keeps it swaps too. Here a plate is covered so that only that shared face can show.
local L = require("./lib")
local Mirror = L.Mirror
local fmt = string.format
-- A: 0.5 x 0.25 x 1.0 at x = +0.05; B: 0.25 x 0.25 x 2.0 at x = -0.05: volumes 0.125 both, same cy, |cx|, cz
-- their top faces (y = 2.625) overlap on x in [-0.125+..] — A spans x [-0.2, 0.3], B [-0.175, 0.075], z: A [-0.5,0.5]; B [-1,1]
local function design()
	local parts = {}
	table.insert(parts, L.part("Grip", "Block", { 0, 0.75, 0 }, L.I, { 0.16, 0.9, 0.16 }))
	table.insert(parts, L.part("Guard", "Block", { 0, 1.29, 0 }, L.I, { 1.0, 0.18, 0.24 }))
	table.insert(parts, L.part("Blade", "Block", { 0, 2.0, 0 }, L.I, { 0.3, 1.3, 0.1 }))
	-- the two tied parts, thin plates lying flush on top of each other's top faces (same y extent)
	table.insert(parts, L.part("Blade", "Block", { 0.05, 2.75, 0 }, L.I, { 0.5, 0.2, 0.25 })) -- A: vol 0.025
	table.insert(parts, L.part("Blade", "Block", { -0.05, 2.75, 0 }, L.I, { 0.25, 0.2, 0.5 })) -- B: vol 0.025
	return parts
end
local parts = L.renumber(design())
local P = L.prep(parts)
print(fmt("volumes %.17g %.17g", P[4].volume, P[5].volume))
local rank = L.Sampling.ranked(P)
print("rank A, B:", rank[4], rank[5])
local function images(ps, plane)
	local out = {}
	for i, p in ipairs(ps) do out[i] = Mirror.reflect(p, plane) end
	return L.renumber(out)
end
local Q = L.prep(images(parts, "X"))
local rq = L.Sampling.ranked(Q)
print("mirror: rank A', B':", rq[4], rq[5])
for i = 4, 5 do
	print(fmt("part %d reads %.4f%% original, %.4f%% mirror", i, 100 * L.readOf(P, i), 100 * L.readOf(Q, i)))
end
