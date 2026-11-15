--!nocheck
-- fix-4: V2's flatband.luau (m2x-v2-2) on a tree (ROOT, default the repo). V2: a flat part's reading near a round hider. A plate s × 0.02 × s on a slab between flush walls (only its top shows), lids
-- leaving a window w × w at its centre, and a Ball of radius R hovering a gap g over the window: past HIDE_OFFSET from the
-- true sphere, so the truth reads the window whole, but within its model's over (0.026 R at a grid vertex), so the Ball's
-- half-spaces moved out by their sag reach the plate's probe. The model's reading (exact on the model), the brute force,
-- the truth (VisibleOracle), and the verdict.
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-2"
local R0 = require("@lune/process").env.ROOT or "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local H = require(R0 .. "/tests/Physics/PhysicsHelpers")
local Sampling = require(R0 .. "/src/shared/Physics/Sampling")
local Oracle = require(R0 .. "/tests/Physics/VisibleOracle")
local fmt = string.format
local function design(s, w, R, g)
	local t, FAR = 0.02, 1
	local parts = {
		H.solid(1, "Block", { 0, -t / 2, 0 }, H.I, { s, t, s }),
		H.solid(2, "Block", { 0, -t - 0.02, 0 }, H.I, { s, 0.04, s }),
		H.solid(3, "Block", { s / 2 + 0.02, -0.03, 0 }, H.I, { 0.04, 0.06, s + 0.08 }),
		H.solid(4, "Block", { -s / 2 - 0.02, -0.03, 0 }, H.I, { 0.04, 0.06, s + 0.08 }),
		H.solid(5, "Block", { 0, -0.03, s / 2 + 0.02 }, H.I, { s, 0.06, 0.04 }),
		H.solid(6, "Block", { 0, -0.03, -s / 2 - 0.02 }, H.I, { s, 0.06, 0.04 }),
	}
	local x0, x1 = -w / 2, w / 2
	for _, lid in ipairs({ { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, x0 }, { x0, x1, x1, FAR } }) do
		table.insert(parts, H.solid(#parts + 1, "Block", { (lid[1] + lid[2]) / 2, 0.05, (lid[3] + lid[4]) / 2 }, H.I,
			{ lid[2] - lid[1], 0.1, lid[4] - lid[3] }))
	end
	if R > 0 then
		table.insert(parts, H.solid(#parts + 1, "Ball", { 0, R + g, 0 }, H.I, { 2 * R, 2 * R, 2 * R }))
	end
	return H.prepared({ parts = parts })
end
for _, c in ipairs({ { 0.15, 0.07, 0.3, 0.014 }, { 0.15, 0.06, 0.3, 0.014 }, { 0.15, 0.05, 0.3, 0.013 }, { 0.1, 0.05, 0.3, 0.013 },
	{ 0.15, 0.07, 0.3, 0.0121 }, { 0.1, 0.06, 0.3, 0.0125 }, { 0.12, 0.07, 0.3, 0.0125 }, { 0.5, 0.105, 0.3, 0.013 } }) do
	local s, w, R, g = c[1], c[2], c[3], c[4]
	local P = design(s, w, R, g)
	local read = H.reads(P, 1)
	local _, _, hider = Oracle.flags(P)
	local truth = Oracle.measure(P, 1, hider, 400000)
	local without = H.reads(design(s, w, 0, g), 1)
	print(fmt("plate %.2f, window %.3f, Ball r %.2f at a gap %.4f: reads %.3f %% on its model (%.3f %% without the Ball), truly %.3f %%; kept %s",
		s, w, R, g, 100 * read, 100 * without, 100 * truth, tostring(Sampling.exposure(P).kept[1])))
end
