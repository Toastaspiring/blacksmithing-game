--!nocheck
-- The most samples a verdict reads on a part that is not Dust and fits the hitbox upright, per shape: every size on a dense list, and random ones.
local V = require("./v1")
local Sampling, Shapes = V.Sampling, V.Shapes
local Geo = require("./tree/src/shared/Definitions/Balance").Geometry
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
local LEN = {}
for x = 0.02, 0.2, 0.002 do table.insert(LEN, x) end
for x = 0.2, 1.6, 0.01 do table.insert(LEN, x) end
for x = 1.6, 5.0, 0.04 do table.insert(LEN, x) end
local function fits(size)
	return size[1] <= 1.6 and size[2] <= 5 and size[3] <= 0.6
end
for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder" }) do
	local top, what = 0, ""
	local function try(size)
		local P = Shapes.prepare(V.part("X", shape, "Blade", { 0, 2.5, 0 }, V.I, size), 1)
		if P.volume >= Geo.MIN_PART_VOLUME then
			local S, h = grid(P)
			if S.n > top then
				top, what = S.n, fmt("%.3f x %.3f x %.3f at h %.2f", size[1], size[2], size[3], h)
			end
		end
	end
	if shape == "Cylinder" then
		-- the axis along Y in the hitbox: local X up to 5
		for _, L in ipairs(LEN) do
			for _, d in ipairs(LEN) do
				if d <= 0.6 then try({ L, d, d }) end
			end
		end
	else
		for _, a in ipairs({ 1.6, 1.29, 1.28, 1.2, 0.96, 0.8, 0.64, 0.48, 0.32, 0.2, 0.1, 0.05, 0.03, 0.02 }) do
			for _, b in ipairs(LEN) do
				for _, c in ipairs({ 0.6, 0.48, 0.32, 0.2, 0.1, 0.05, 0.04, 0.03, 0.02 }) do
					for _, size in ipairs({ { a, b, c }, { b, a, c }, { c, b, a }, { a, c, b }, { b, c, a }, { c, a, b } }) do
						-- any axis may lie along any of the hitbox's: its sorted sizes fit sorted extents
						local s = { size[1], size[2], size[3] }
						table.sort(s)
						if s[1] <= 0.6 and s[2] <= 1.6 and s[3] <= 5 then
							try(size)
						end
					end
				end
			end
		end
	end
	print(fmt("%-12s most verdict samples: %d (%s)", shape, top, what))
end
