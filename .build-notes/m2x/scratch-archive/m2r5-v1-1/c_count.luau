--!nocheck
-- The most samples a verdict can read on a part that fits the hitbox: the cost row's "about 70".
local V = require("./v1")
local Sampling, Shapes = V.Sampling, V.Shapes
local Balance = require("./tree/src/shared/Definitions/Balance")
local Geo = Balance.Geometry
local Sets = require("./b_sets")
local fmt = string.format
local R = Sets.rng(99)
local function grid(P)
	local h = Sampling.ladder(Geo.H_SURF, function(s)
		local ax = math.max(1, math.min(64, math.ceil(2 * P.hx / s)))
		local ay = math.max(1, math.min(64, math.ceil(2 * P.hy / s)))
		local az = math.max(1, math.min(64, math.ceil(2 * P.hz / s)))
		return 2 * (ax * ay + ay * az + ax * az) <= Geo.VERDICT_SAMPLES
	end)
	return Sampling.surfaceSamples(P, h, nil, Geo.VERDICT_TRIANGLE_CELLS), h
end
for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder" }) do
	local top, what = 0, ""
	for k = 1, 60000 do
		local L = if R.u() < 0.5 then R.range(0.02, 5.28) else R.range(0.02, 1.6)
		local b = if R.u() < 0.5 then R.range(0.02, 0.1) else R.range(0.02, 1.6)
		local c = if R.u() < 0.5 then R.range(0.02, 0.1) else R.range(0.02, 0.6)
		local size = if shape == "Cylinder" then { L, math.min(b, c), math.min(b, c) } else { L, b, c }
		if R.u() < 0.5 and shape ~= "Cylinder" then size = { b, L, c } end
		local P = Shapes.prepare(V.part("X", shape, "Blade", { 0, 2, 0 }, V.I, size), 1)
		if P.volume >= Geo.MIN_PART_VOLUME then
			local S, h = grid(P)
			if S.n > top then
				top, what = S.n, fmt("%.3f x %.3f x %.3f at h %.2f", size[1], size[2], size[3], h)
			end
		end
	end
	print(fmt("%-12s most verdict samples within the hitbox: %d (%s)", shape, top, what))
end
print("Ball: 96 samples, a centre verdict: no patch tests")
