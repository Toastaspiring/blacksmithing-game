--!nocheck
-- V2 round 3: the model numbers SPEC §4.4, §16.10 and E-S2.12 quote, from Cover.model on the repo copy.
local R = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Cover = require(R .. "/src/shared/Physics/Cover")
local fmt = string.format

local function part(shape, size, rot)
	return { id = 1, slot = "Blade", shape = shape, material = "Iron", pos = { 0, 2, 0 }, rot = rot or { 0, 0, 0, 1 }, size = size }
end

-- a Ball r = 1
local P = Shapes.prepare(part("Ball", { 2, 2, 2 }), 1)
local m = Cover.model(P)
local largest, smallest = 0, math.huge
for f = 1, m.n do
	largest = math.max(largest, m.area[f])
	smallest = math.min(smallest, m.area[f])
end
print(fmt("Ball: %d facets, model area / sphere %.6f (%.4f %%), largest facet %.5f %% of the model, %.5f %% of the sphere", m.n, m.total / (4 * math.pi), 100 * m.total / (4 * math.pi), 100 * largest / m.total, 100 * largest / (4 * math.pi)))
local smin, smax, gmin, gmax = math.huge, 0, math.huge, 0
for f = 1, m.n do
	smin, smax = math.min(smin, m.spread[f]), math.max(smax, m.spread[f])
	gmin, gmax = math.min(gmin, m.sag[f]), math.max(gmax, m.sag[f])
end
print(fmt("Ball r 1: spread %.6f..%.6f (HIDE_OFFSET × sin), sag %.6f..%.6f r, reach %.6f, over %.4f, inner %.6f", smin, smax, gmin, gmax, m.reach, m.over, m.inner))
-- how far the probe's half-spaces (moved out by their sag) stand past the box: the support of the polytope n·x ≤ d + sag
-- along the axes, by brute force over the vertices of the half-space set... use the facets: each facet's plane moved out
-- by its sag; the max over the region of x along +X. Take a fine sample of directions near the axis tip.
local pl = m.planes
local function inside(x, y, z)
	for i = 1, m.np do
		local nx, ny, nz, d = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1], pl[4 * i]
		if nx * x + ny * y + nz * (z - 0) + 0 > d + m.sag[i] + 1e-15 + (nx * 0 + ny * 2 + nz * 0) - (ny * 2) then
			-- d is in world coordinates: the centre is (0, 2, 0)
		end
	end
	return true
end
-- the support of {x : n_i·x ≤ d_i + sag_i} along +X (centre (0, 2, 0)): bisection along rays from the centre
local function supportAlong(dx, dy, dz)
	local lo, hi = 0, 2
	for _ = 1, 200 do
		local t = (lo + hi) / 2
		local x, y, z = t * dx, 2 + t * dy, t * dz
		local ok = true
		for i = 1, m.np do
			local nx, ny, nz, d = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1], pl[4 * i]
			if nx * x + ny * y + nz * z > d + m.sag[i] then
				ok = false
				break
			end
		end
		if ok then
			lo = t
		else
			hi = t
		end
	end
	return lo
end
local best = 0
for _, dir in ipairs({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { -1, 0, 0 }, { 0, -1, 0 }, { 0, 0, -1 } }) do
	best = math.max(best, supportAlong(dir[1], dir[2], dir[3]))
end
print(fmt("Ball: the probe's half-spaces reach %.6f r along the axes (over past the box %.4f r)", best, best - 1))
-- the model's depth under the sphere along (1,1,1)/sqrt3 and at the axis tips
local function modelSupport(dx, dy, dz)
	local lo, hi = 0, 2
	for _ = 1, 200 do
		local t = (lo + hi) / 2
		local x, y, z = t * dx, 2 + t * dy, t * dz
		local ok = true
		for i = 1, m.np do
			local nx, ny, nz, d = pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1], pl[4 * i]
			if nx * x + ny * y + nz * z > d then
				ok = false
				break
			end
		end
		if ok then
			lo = t
		else
			hi = t
		end
	end
	return lo
end
local s3 = 1 / math.sqrt(3)
print(fmt("Ball model: depth under the sphere along (1,1,1)/sqrt3 %.4f r, along +X %.4f r", 1 - modelSupport(s3, s3, s3), 1 - modelSupport(1, 0, 0)))
-- largest depth over many directions
local deepest = 0
for a = 0, 90, 0.5 do
	for b = 0, 90, 0.5 do
		local ca, sa, cb, sb = math.cos(math.rad(a)), math.sin(math.rad(a)), math.cos(math.rad(b)), math.sin(math.rad(b))
		deepest = math.max(deepest, 1 - modelSupport(ca * cb, sa * cb, sb))
	end
end
print(fmt("Ball model: the largest depth under the sphere over a 0.5° grid of an octant %.4f r", deepest))

-- a Cylinder r = 1, along X
local C = Shapes.prepare(part("Cylinder", { 4, 2, 2 }), 1)
local mc = Cover.model(C)
local cs, cg = 0, 0
for f = 1, mc.n do
	cs = math.max(cs, mc.spread[f])
	cg = math.max(cg, mc.sag[f])
end
print(fmt("Cylinder r 1: %d facets, spread max %.6f (δ·sin(π/32) = %.6f), sag max %.6f r (1 − cos(π/32) = %.6f), over %.4f, sec(π/32) − 1 = %.6f", mc.n, cs, 0.012 * math.sin(math.pi / 32), cg, 1 - math.cos(math.pi / 32), mc.over, 1 / math.cos(math.pi / 32) - 1))
print(fmt("Cylinder area model/true %.6f", mc.total / (2 * math.pi * 1 * 4 + 2 * math.pi)))
