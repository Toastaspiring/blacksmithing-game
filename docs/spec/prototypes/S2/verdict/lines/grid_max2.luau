--!nocheck
local V = require("./v1")
local Sampling, Shapes = V.Sampling, V.Shapes
local Geo = require("./tree/src/shared/Definitions/Balance").Geometry
local Sets = require("./b_sets")
local R = Sets.rng(4242)
local fmt = string.format
local function grid(P)
	local h = Sampling.ladder(Geo.H_SURF, function(s)
		local ax = math.max(1, math.min(64, math.ceil(2 * P.hx / s)))
		local ay = math.max(1, math.min(64, math.ceil(2 * P.hy / s)))
		local az = math.max(1, math.min(64, math.ceil(2 * P.hz / s)))
		return 2 * (ax * ay + ay * az + ax * az) <= Geo.VERDICT_SAMPLES
	end)
	return Sampling.surfaceSamples(P, h, nil, Geo.VERDICT_TRIANGLE_CELLS), h
end
local function logr(a, b) return a * math.exp(R.u() * math.log(b / a)) end
for _, shape in ipairs({ "CornerWedge", "Wedge", "Block" }) do
	local top, what = 0, ""
	for k = 1, 150000 do
		local s = { logr(0.02, 5), logr(0.02, 5), logr(0.02, 1.6) }
		local t = table.clone(s)
		table.sort(t)
		if t[1] <= 0.6 and t[2] <= 1.6 and t[3] <= 5 then
			local P = Shapes.prepare(V.part("X", shape, "Blade", { 0, 2.5, 0 }, V.I, s), 1)
			if P.volume >= Geo.MIN_PART_VOLUME then
				local S, h = grid(P)
				if S.n > top then
					top, what = S.n, fmt("%.3f x %.3f x %.3f at h %.2f", s[1], s[2], s[3], h)
				end
			end
		end
	end
	print(fmt("%-12s most verdict samples: %d (%s)", shape, top, what))
end
