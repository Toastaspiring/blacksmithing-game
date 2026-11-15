--!strict
-- T-PHY-01 and the geometry of Physics/Shapes (SPEC §3.2, §4.2, §4.3, §4.5, E-S2.1, E-S8.5): volumes and centroids
-- against Monte Carlo and the engine's own numbers, signed distances, exact extents, chords, supports, max distances,
-- half-spaces and faces. Membership comes from PhysicsHelpers.insideLocal, written from §3.2's table, and the extents
-- from tests/lib/Gen, an implementation independent of Physics/Shapes.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local H = require("./PhysicsHelpers")
local Shapes = require("../../src/shared/Physics/Shapes")

type Rng = TestRng.TestRng

local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }

local function randomPart(rng: Rng, shape: string, maxSide: number?): any
	local top = maxSide or 0.6
	local size = { rng:range(0.02, top), rng:range(0.02, top), rng:range(0.02, top) }
	if shape == "Ball" then
		size = { size[1], size[1], size[1] }
	elseif shape == "Cylinder" then
		size = { size[1], size[2], size[2] }
	end
	return H.solid(1, shape, { rng:range(-1, 1), rng:range(0, 5), rng:range(-1, 1) }, H.randomQuat(rng), size)
end

-- 47³ = 103,823 ≥ 10⁵ points, jittered in a grid over the part's local box: T-PHY-01's Monte Carlo, whose stratification
-- keeps the error far under the bound. Membership from §3.2; Shapes.sd must agree at every point off the boundary.
local function monteCarlo(shape: string, pos: { number }, rot: { number }, size: { number }, seed: number)
	local part = H.solid(1, shape, pos, rot, size)
	local P = Shapes.prepare(part, 1)
	local rng = TestRng.new(seed)
	local n = 47
	local hx, hy, hz = size[1] / 2, size[2] / 2, size[3] / 2
	local dx, dy, dz = size[1] / n, size[2] / n, size[3] / n
	local count, sumX, sumY, sumZ = 0, 0, 0, 0
	local cell = dx * dy * dz
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			for k = 0, n - 1 do
				local lx = -hx + (i + rng:float()) * dx
				local ly = -hy + (j + rng:float()) * dy
				local lz = -hz + (k + rng:float()) * dz
				local x, y, z = Shapes.toWorld(P, lx, ly, lz)
				local inside = H.insideLocal(shape, size, lx, ly, lz)
				local d = Shapes.sd(P, x, y, z)
				if inside ~= (d <= 0) and math.abs(d) > 1e-12 then
					A.fail(string.format("%s: sd %.17g disagrees with §3.2 at local (%.5f, %.5f, %.5f)", shape, d, lx, ly, lz))
				end
				if inside then
					count += 1
					sumX += x
					sumY += y
					sumZ += z
				end
			end
		end
	end
	local volume = count * cell
	local bound = 0.005 * math.max(size[1], size[2], size[3])
	A.rel(P.volume, volume, 0.005, shape .. " volume")
	A.near(P.gx, sumX / count, bound, shape .. " centroid x")
	A.near(P.gy, sumY / count, bound, shape .. " centroid y")
	A.near(P.gz, sumZ / count, bound, shape .. " centroid z")
end

return Test.suite("Physics/Shapes", function(t)
	t.it("T-PHY-01 the engine's numbers: mass and CenterOfMass of Studio's probe parts (E-S2.1, Plastic 0.7)", function()
		local rho = 0.7
		local function probe(shape: string, size: { number }): any
			return H.prepare(H.solid(1, shape, { 0, 0, 0 }, H.I, size))
		end
		local wedge = probe("Wedge", { 2, 4, 6 })
		A.near(rho * wedge.volume, 16.80, 1e-9, "Wedge mass")
		A.near(wedge.gx, 0, 1e-12)
		A.near(wedge.gy, -0.6667, 5e-5, "Wedge CoM y")
		A.near(wedge.gz, 1.0000, 1e-9, "Wedge CoM z")
		local corner = probe("CornerWedge", { 2, 4, 6 })
		A.near(rho * corner.volume, 11.20, 1e-9, "CornerWedge mass")
		A.near(corner.gx, 0.25, 1e-12)
		A.near(corner.gy, -1.00, 1e-12)
		A.near(corner.gz, -0.75, 1e-12)
		A.near(rho * probe("Cylinder", { 4, 2, 3 }).volume, 8.79646, 5e-6, "Cylinder 4×2×3: diameter = min(Y, Z), length = X")
		A.near(rho * probe("Cylinder", { 4, 3, 2 }).volume, 8.79646, 5e-6, "Cylinder 4×3×2")
		A.near(rho * probe("Ball", { 1, 2, 3 }).volume, 0.36652, 5e-6, "Ball 1×2×3: diameter = min")
		A.near(rho * probe("Ball", { 3, 2, 1 }).volume, 0.36652, 5e-6, "Ball 3×2×1")
		A.eq(probe("Block", { 2, 4, 6 }).volume, 48)
	end)

	t.it("T-PHY-01 Block: Monte Carlo volume and centroid, 10⁵ points", function()
		monteCarlo("Block", { 0.3, 2, -0.1 }, H.axisAngle(1, 2, 3, 33), { 0.16, 2.6, 0.06 }, 101)
	end)
	t.it("T-PHY-01 Wedge: Monte Carlo volume and centroid, 10⁵ points", function()
		monteCarlo("Wedge", { -0.2, 1.5, 0.1 }, H.axisAngle(3, -1, 2, 71), { 0.4, 0.7, 0.5 }, 102)
	end)
	t.it("T-PHY-01 CornerWedge: Monte Carlo volume and centroid, 10⁵ points", function()
		monteCarlo("CornerWedge", { 0.5, 3, 0 }, H.axisAngle(-2, 1, 1, 128), { 0.6, 0.35, 0.25 }, 103)
	end)
	t.it("T-PHY-01 Cylinder: Monte Carlo volume and centroid, 10⁵ points", function()
		monteCarlo("Cylinder", { 0, 1, 0.2 }, H.axisAngle(1, 1, -1, 200), { 0.9, 0.3, 0.3 }, 104)
	end)
	t.it("T-PHY-01 Ball: Monte Carlo volume and centroid, 10⁵ points", function()
		monteCarlo("Ball", { 0.1, 0.2, 0.3 }, H.axisAngle(0, 1, 0, 45), { 0.5, 0.5, 0.5 }, 105)
	end)

	t.it("prepare's analytic areas equal the areas of its faces (polyhedra) and the closed forms", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return randomPart(rng, SHAPES[rng:int(1, 3)])
		end, function(part: any)
			local P = Shapes.prepare(part, 1)
			local area = 0
			for _, poly in ipairs(Shapes.faces(P)) do
				local nx, ny, nz = 0, 0, 0
				local n = #poly / 3
				for i = 0, n - 1 do
					local j = if i == n - 1 then 0 else i + 1
					local ax, ay, az = poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3]
					local bx, by, bz = poly[3 * j + 1], poly[3 * j + 2], poly[3 * j + 3]
					nx += ay * bz - az * by
					ny += az * bx - ax * bz
					nz += ax * by - ay * bx
				end
				area += math.sqrt(nx * nx + ny * ny + nz * nz) / 2
			end
			A.rel(P.area, area, 1e-9, part.shape .. " area")
		end)
		local pi = Shapes.PI
		A.rel(H.prepare(H.solid(1, "Ball", { 0, 0, 0 }, H.I, { 1, 1, 1 })).area, pi, 1e-15)
		A.rel(H.prepare(H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { 3, 2, 2 })).area, 2 * pi + 2 * pi * 3, 1e-15)
		A.eq(Shapes.PI, 3.141592653589793, "SPEC §4.1's literal")
	end)

	t.it("§4.3 sd: sign agrees with §3.2, 1-Lipschitz, a lower bound of the distance outside, exact inside", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return { part = randomPart(rng, SHAPES[rng:int(1, 5)]), rng = rng }
		end, function(c: any)
			local part, rng = c.part, c.rng
			local P = Shapes.prepare(part, 1)
			local reach = math.max(part.size[1], part.size[2], part.size[3])
			local px, py, pz, pd
			for _ = 1, 50 do
				local lx, ly, lz = rng:range(-reach, reach), rng:range(-reach, reach), rng:range(-reach, reach)
				local x, y, z = Shapes.toWorld(P, lx, ly, lz)
				local d = Shapes.sd(P, x, y, z)
				A.near(d, Shapes.sdLocal(P, lx, ly, lz), 1e-12, "sd vs sdLocal")
				local inside = H.insideLocal(part.shape, part.size, lx, ly, lz)
				if math.abs(d) > 1e-12 then
					A.eq(d <= 0, inside, part.shape .. " sign of sd")
				end
				local exact = H.distanceToSolid(P, x, y, z)
				if d > 0 then
					A.truthy(d <= exact + 1e-9, part.shape .. " sd must be a lower bound outside")
				end
				if px then
					local dist = math.sqrt((x - px) * (x - px) + (y - py) * (y - py) + (z - pz) * (z - pz))
					A.truthy(math.abs(d - pd) <= dist + 1e-9, part.shape .. " sd must be 1-Lipschitz")
				end
				px, py, pz, pd = x, y, z, d
			end
		end)
	end)

	t.it("toWorld and toLocal are inverses", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return { part = randomPart(rng, SHAPES[rng:int(1, 5)]), a = rng:range(-1, 1), b = rng:range(-1, 1), c = rng:range(-1, 1) }
		end, function(k: any)
			local P = Shapes.prepare(k.part, 1)
			local x, y, z = Shapes.toWorld(P, k.a, k.b, k.c)
			local a, b, c = Shapes.toLocal(P, x, y, z)
			A.near(a, k.a, 1e-12)
			A.near(b, k.b, 1e-12)
			A.near(c, k.c, 1e-12)
		end)
	end)

	t.it("§4.2 exact extents: Shapes.aabb(PartData) = tests/lib/Gen's independent AABB, every shape", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return randomPart(rng, SHAPES[rng:int(1, 5)])
		end, function(part: any)
			local lo, hi = Shapes.aabb(part)
			local gl, gh = Gen.aabb(part)
			for k = 1, 3 do
				A.near(lo[k], gl[k], 1e-12, part.shape .. " min")
				A.near(hi[k], gh[k], 1e-12, part.shape .. " max")
			end
			local P = Shapes.prepare(part, 1)
			A.deepEq({ P.minx, P.miny, P.minz }, lo)
			A.deepEq({ P.maxx, P.maxy, P.maxz }, hi)
		end)
	end)

	t.it("§4.2 a cylinder's extents: hx·|u_k| + r·sqrt(1 − u_k²), tighter than its Size box when turned", function()
		-- A03's disc: axis along Z, spun 45°: the solid spans y 0.03–0.35, its turned Size box reaches −0.036
		local disc = H.solid(1, "Cylinder", { 0, 0.19, 0 }, Gen.hemisphere(Gen.mul(H.Z45, H.Y90)), { 0.20, 0.32, 0.32 })
		local lo, hi = Shapes.aabb(disc)
		A.near(lo[2], 0.03, 1e-12)
		A.near(hi[2], 0.35, 1e-12)
		A.near(lo[3], -0.10, 1e-12)
		A.near(hi[3], 0.10, 1e-12)
		-- dense sweep of both caps: nothing beyond the extents, and the extents are reached
		local P = Shapes.prepare(disc, 1)
		local top = -math.huge
		for k = 0, 2047 do
			local a = 2 * Shapes.PI * k / 2048
			local _, y = Shapes.toWorld(P, P.hx, P.r * math.cos(a), P.r * math.sin(a))
			top = math.max(top, y)
		end
		A.near(top, 0.35, 1e-5)
		A.truthy(top <= 0.35 + 1e-12)
	end)

	t.it("chord: the ends lie on the surface, the middle inside; a miss stays outside; dilation widens", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			local part = randomPart(rng, SHAPES[rng:int(1, 5)])
			local q = H.randomQuat(rng)
			return { part = part, dir = { 2 * (q[1] * q[3] + q[2] * q[4]), 2 * (q[2] * q[3] - q[1] * q[4]), 1 - 2 * (q[1] * q[1] + q[2] * q[2]) },
				o = { part.pos[1] + rng:range(-0.5, 0.5), part.pos[2] + rng:range(-0.5, 0.5), part.pos[3] + rng:range(-0.5, 0.5) } }
		end, function(c: any)
			local P = Shapes.prepare(c.part, 1)
			local o, u = c.o, c.dir
			local hit, t0, t1 = Shapes.chord(P, o[1], o[2], o[3], u[1], u[2], u[3])
			local tol = 1e-9
			if hit then
				A.truthy(t0 <= t1)
				for _, s in ipairs({ t0, t1 }) do
					A.near(Shapes.sd(P, o[1] + s * u[1], o[2] + s * u[2], o[3] + s * u[3]), 0, tol, c.part.shape .. " chord end")
				end
				local m = (t0 + t1) / 2
				A.truthy(Shapes.sd(P, o[1] + m * u[1], o[2] + m * u[2], o[3] + m * u[3]) <= tol, c.part.shape .. " chord middle")
			else
				for s = -2, 2, 0.05 do
					A.truthy(Shapes.sd(P, o[1] + s * u[1], o[2] + s * u[2], o[3] + s * u[3]) > -tol, c.part.shape .. " a miss has no point inside")
				end
			end
			local hitD, d0, d1 = Shapes.chord(P, o[1], o[2], o[3], u[1], u[2], u[3], 0.005)
			if hit then
				A.truthy(hitD, "a hit stays a hit when dilated")
				A.truthy(d0 <= t0 + tol and d1 >= t1 - tol, "dilation contains the chord")
			end
		end)
	end)

	t.it("chord: a dilation d gives exactly sd ≤ d along the line", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			local part = randomPart(rng, SHAPES[rng:int(1, 5)])
			local q = H.randomQuat(rng)
			return { part = part, dir = { 2 * (q[1] * q[3] + q[2] * q[4]), 2 * (q[2] * q[3] - q[1] * q[4]), 1 - 2 * (q[1] * q[1] + q[2] * q[2]) },
				o = { part.pos[1] + rng:range(-0.5, 0.5), part.pos[2] + rng:range(-0.5, 0.5), part.pos[3] + rng:range(-0.5, 0.5) } }
		end, function(c: any)
			local P = Shapes.prepare(c.part, 1)
			local o, u = c.o, c.dir
			for _, d in ipairs({ 0, 1e-7, 0.005 }) do
				local hit, t0, t1 = Shapes.chord(P, o[1], o[2], o[3], u[1], u[2], u[3], d)
				if hit then
					for _, s in ipairs({ t0, t1 }) do
						A.near(Shapes.sd(P, o[1] + s * u[1], o[2] + s * u[2], o[3] + s * u[3]), d, 1e-9, c.part.shape .. " an end at sd = " .. d)
					end
				end
			end
		end)
	end)

	t.it("chord along Z through a blade measures its thickness, and a line along a cylinder's axis its length", function()
		local blade = H.prepare(H.solid(1, "Block", { 0, 2.68, 0 }, H.I, { 0.16, 2.6, 0.06 }))
		local hit, t0, t1 = Shapes.chord(blade, 0, 2.68, 0, 0, 0, 1)
		A.truthy(hit)
		A.near(t1 - t0, 0.06, 1e-12)
		A.falsy((Shapes.chord(blade, 0.081, 2.68, 0, 0, 0, 1)), "beyond the width")
		A.truthy((Shapes.chord(blade, 0.081, 2.68, 0, 0, 0, 1, 0.005)), "within the raster's dilation")
		local cylinder = H.prepare(H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { 0.9, 0.2, 0.2 }))
		local hit2, a0, a1 = Shapes.chord(cylinder, 0, 0.05, 0, 1, 0, 0)
		A.truthy(hit2)
		A.near(a1 - a0, 0.9, 1e-12)
		A.falsy((Shapes.chord(cylinder, 0, 0.11, 0, 1, 0, 0)), "outside the radius")
	end)

	t.it("chord: every slope moves out by the dilation", function()
		-- Is the line through local point l along local direction u within `dilate` of the solid?
		local function hits(part: any, l: { number }, u: { number }, dilate: number): boolean
			local P = H.prepare(part)
			local x, y, z = Shapes.toWorld(P, l[1], l[2], l[3])
			local dx, dy, dz = Shapes.toWorld(P, u[1], u[2], u[3])
			return (Shapes.chord(P, x, y, z, dx - P.cx, dy - P.cy, dz - P.cz, dilate))
		end
		local q = H.axisAngle(1, 2, 3, 40)
		local hx, hy, hz = 0.2, 0.3, 0.4
		local size = { 2 * hx, 2 * hy, 2 * hz }
		local out = 0.003 -- how far the lines run outside the slope, between the two dilations below
		local wedge = H.solid(1, "Wedge", { 0.1, 2, 0 }, q, size)
		local l = math.sqrt(hy * hy + hz * hz)
		-- the slope's centre, moved out along its normal (0, hz, −hy)/l, a line across along local X
		local overWedge = { 0, out * hz / l, -out * hy / l }
		A.truthy(hits(wedge, overWedge, { 1, 0, 0 }, 0.005), "Wedge slope, within the dilation")
		A.falsy(hits(wedge, overWedge, { 1, 0, 0 }, 0.001), "Wedge slope, beyond it")
		local corner = H.solid(1, "CornerWedge", { 0.1, 2, 0 }, q, size)
		-- the slope y/hy = −z/hz at (0.5 hx, −0.5 hy, 0.5 hz), normal (0, hz, hy)/l, a line along local X
		local overSecond = { 0.5 * hx, -0.5 * hy + out * hz / l, 0.5 * hz + out * hy / l }
		A.truthy(hits(corner, overSecond, { 1, 0, 0 }, 0.005), "CornerWedge's second slope, within")
		A.falsy(hits(corner, overSecond, { 1, 0, 0 }, 0.001), "CornerWedge's second slope, beyond")
		-- the slope y/hy = x/hx at (−0.5 hx, −0.5 hy, 0), normal (−hy, hx, 0)/m, a line along local Z
		local m = math.sqrt(hx * hx + hy * hy)
		local overFirst = { -0.5 * hx - out * hy / m, -0.5 * hy + out * hx / m, 0 }
		A.truthy(hits(corner, overFirst, { 0, 0, 1 }, 0.005), "CornerWedge's first slope, within")
		A.falsy(hits(corner, overFirst, { 0, 0, 1 }, 0.001), "CornerWedge's first slope, beyond")
	end)

	t.it("chord: a ball's and a cylinder's radius, and a cylinder's caps, move out by the dilation", function()
		local ball = H.prepare(H.solid(1, "Ball", { 0, 1, 0 }, H.I, { 0.2, 0.2, 0.2 }))
		A.falsy((Shapes.chord(ball, 0.103, 1, 0, 0, 0, 1)), "the ball, 0.003 off")
		A.truthy((Shapes.chord(ball, 0.103, 1, 0, 0, 0, 1, 0.005)), "the ball, within the dilation")
		local cylinder = H.prepare(H.solid(1, "Cylinder", { 0, 1, 0 }, H.I, { 0.6, 0.2, 0.2 }))
		A.falsy((Shapes.chord(cylinder, 0, 1.103, 0, 0, 0, 1)), "the cylinder, 0.003 off its side")
		A.truthy((Shapes.chord(cylinder, 0, 1.103, 0, 0, 0, 1, 0.005)), "the cylinder, within the dilation")
		A.falsy((Shapes.chord(cylinder, 0.303, 1, 0, 0, 0, 1)), "0.003 past its cap")
		A.truthy((Shapes.chord(cylinder, 0.303, 1, 0, 0, 0, 1, 0.005)), "the cap, within the dilation")
	end)

	t.it("§4.4 sameSolid: every position, size and rotation component decides, and the shape", function()
		local base = H.solid(1, "Block", { 0.1, 2, 0.05 }, H.axisAngle(1, 2, 3, 40), { 0.3, 0.4, 0.5 })
		local P = H.prepare(base)
		local function same(shape: string, pos: { number }, rot: { number }, size: { number }): boolean
			return Shapes.sameSolid(P, H.prepare(H.solid(2, shape, pos, rot, size), 2))
		end
		A.truthy(same("Block", base.pos, base.rot, base.size), "the same record with another id")
		for k = 1, 3 do
			local moved: { number } = table.clone(base.pos)
			moved[k] += 1e-9
			A.falsy(same("Block", moved, base.rot, base.size), "pos " .. k)
			local grown: { number } = table.clone(base.size)
			grown[k] += 1e-9
			A.falsy(same("Block", base.pos, base.rot, grown), "size " .. k)
		end
		A.falsy(same("Wedge", base.pos, base.rot, base.size), "shape")
		A.falsy(same("Block", base.pos, H.axisAngle(1, 2, 3, 40.000001), base.size), "rotation")
	end)

	t.it("§4.2 support: on the surface, and the farthest point along the direction", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return { part = randomPart(rng, SHAPES[rng:int(1, 5)]), rng = rng }
		end, function(c: any)
			local part, rng = c.part, c.rng
			local P = Shapes.prepare(part, 1)
			local q = H.randomQuat(rng)
			local dx, dy, dz = q[1], q[2], q[3]
			local sx, sy, sz = Shapes.support(P, dx, dy, dz)
			A.near(Shapes.sd(P, sx, sy, sz), 0, 1e-9, part.shape .. " support on the surface")
			local best = sx * dx + sy * dy + sz * dz
			local reach = math.max(part.size[1], part.size[2], part.size[3])
			for _ = 1, 100 do
				local x, y, z = Shapes.toWorld(P, rng:range(-reach, reach), rng:range(-reach, reach), rng:range(-reach, reach))
				if Shapes.sd(P, x, y, z) <= 0 then
					A.truthy(x * dx + y * dy + z * dz <= best + 1e-9, part.shape .. " a point of the solid beyond its support")
				end
			end
			-- any length of the direction gives the same point
			local tx, ty, tz = Shapes.support(P, 3 * dx, 3 * dy, 3 * dz)
			A.near(tx, sx, 1e-9)
			A.near(ty, sy, 1e-9)
			A.near(tz, sz, 1e-9)
		end)
		-- a zero local direction component or a zero direction stays on the solid
		local ball = H.prepare(H.solid(1, "Ball", { 1, 2, 3 }, H.I, { 1, 1, 1 }))
		local x, y, z = Shapes.support(ball, 0, 0, 0)
		A.near(Shapes.sd(ball, x, y, z), 0, 1e-12, "a ball's support for a zero direction")
		local cylinder = H.prepare(H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { 2, 1, 1 }))
		local cx, cy, cz = Shapes.support(cylinder, 1, 0, 0)
		A.deepEq({ cx, cy, cz }, { 1, 0, 0 }, "along its axis, a cylinder's support is the cap's centre")
	end)

	t.it("extentAlong: the projection of the support, equal to the vertices' range for polyhedra", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			local q = H.randomQuat(rng)
			local n = math.sqrt(q[1] * q[1] + q[2] * q[2] + q[3] * q[3])
			return { part = randomPart(rng, SHAPES[rng:int(1, 3)]), dir = { q[1] / n, q[2] / n, q[3] / n } }
		end, function(c: any)
			local P = Shapes.prepare(c.part, 1)
			local d = c.dir
			local lo, hi = Shapes.extentAlong(P, d[1], d[2], d[3])
			local vlo, vhi = math.huge, -math.huge
			for _, v in ipairs(Gen.vertices(c.part) :: { { number } }) do
				local s = v[1] * d[1] + v[2] * d[2] + v[3] * d[3]
				vlo, vhi = math.min(vlo, s), math.max(vhi, s)
			end
			A.near(lo, vlo, 1e-12)
			A.near(hi, vhi, 1e-12)
		end)
		local ball = H.prepare(H.solid(1, "Ball", { 0, 2, 0 }, H.I, { 0.5, 0.5, 0.5 }))
		local lo, hi = Shapes.extentAlong(ball, 0, 1, 0)
		A.near(lo, 1.75, 1e-12)
		A.near(hi, 2.25, 1e-12)
	end)

	t.it("§4.5 maxDist: exact for every shape, against dense sweeps", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return { part = randomPart(rng, SHAPES[rng:int(1, 5)]), g = { rng:range(-1, 1), rng:range(0, 5), rng:range(-1, 1) } }
		end, function(c: any)
			local part, g = c.part, c.g
			local P = Shapes.prepare(part, 1)
			local d = Shapes.maxDist(P, g[1], g[2], g[3])
			local best = 0
			local function see(x: number, y: number, z: number)
				local dx, dy, dz = x - g[1], y - g[2], z - g[3]
				best = math.max(best, math.sqrt(dx * dx + dy * dy + dz * dz))
			end
			if part.shape == "Cylinder" then
				for k = 0, 719 do
					local a = 2 * Shapes.PI * k / 720
					see(Shapes.toWorld(P, P.hx, P.r * math.cos(a), P.r * math.sin(a)))
					see(Shapes.toWorld(P, -P.hx, P.r * math.cos(a), P.r * math.sin(a)))
				end
				A.truthy(d >= best - 1e-9, "Cylinder: a rim point beyond maxDist")
				A.near(d, best, 1e-4, "Cylinder")
			elseif part.shape == "Ball" then
				local dx, dy, dz = part.pos[1] - g[1], part.pos[2] - g[2], part.pos[3] - g[3]
				A.near(d, math.sqrt(dx * dx + dy * dy + dz * dz) + P.r, 1e-12, "Ball")
			else
				for _, v in ipairs(Gen.vertices(part) :: { { number } }) do
					see(v[1], v[2], v[3])
				end
				A.near(d, best, 1e-12, part.shape)
			end
		end)
	end)

	t.it("§4.3 planes: unit normals, the solid is exactly their intersection; Cylinder and Ball have none", function()
		A.eq(#Shapes.planes(H.prepare(H.solid(1, "Block", { 0, 0, 0 }, H.I, { 1, 1, 1 }))), 6)
		A.eq(#Shapes.planes(H.prepare(H.solid(1, "Wedge", { 0, 0, 0 }, H.I, { 1, 1, 1 }))), 7)
		A.eq(#Shapes.planes(H.prepare(H.solid(1, "CornerWedge", { 0, 0, 0 }, H.I, { 1, 1, 1 }))), 8)
		A.eq(#Shapes.planes(H.prepare(H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { 1, 1, 1 }))), 0)
		A.eq(#Shapes.planes(H.prepare(H.solid(1, "Ball", { 0, 0, 0 }, H.I, { 1, 1, 1 }))), 0)
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return { part = randomPart(rng, SHAPES[rng:int(1, 3)]), rng = rng }
		end, function(c: any)
			local part, rng = c.part, c.rng
			local P = Shapes.prepare(part, 1)
			local planes = Shapes.planes(P)
			for _, n in ipairs(planes) do
				A.near(n[1] * n[1] + n[2] * n[2] + n[3] * n[3], 1, 1e-12, "unit normal")
			end
			local reach = math.max(part.size[1], part.size[2], part.size[3])
			for _ = 1, 50 do
				local x, y, z = Shapes.toWorld(P, rng:range(-reach, reach), rng:range(-reach, reach), rng:range(-reach, reach))
				local worst = -math.huge
				for _, n in ipairs(planes) do
					worst = math.max(worst, n[1] * x + n[2] * y + n[3] * z - n[4])
				end
				local d = Shapes.sd(P, x, y, z)
				if math.abs(d) > 1e-9 then
					A.eq(worst <= 0, d <= 0, part.shape .. " planes vs sd")
				end
			end
		end)
	end)

	t.it("§4.3 faces: outward polygons of a closed solid, whose divergence volume and moment are the analytic ones", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return randomPart(rng, SHAPES[rng:int(1, 3)])
		end, function(part: any)
			local P = Shapes.prepare(part, 1)
			local V, Mx, My, Mz = 0, 0, 0, 0
			for _, poly in ipairs(Shapes.faces(P)) do
				for i = 1, #poly / 3 - 2 do
					local ax, ay, az = poly[1], poly[2], poly[3]
					local bx, by, bz = poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3]
					local cx, cy, cz = poly[3 * i + 4], poly[3 * i + 5], poly[3 * i + 6]
					local v = (ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)) / 6
					V += v
					Mx += v * (ax + bx + cx) / 4
					My += v * (ay + by + cy) / 4
					Mz += v * (az + bz + cz) / 4
				end
			end
			A.rel(V, P.volume, 1e-9, part.shape .. " volume")
			A.near(Mx / V, P.gx, 1e-9, part.shape .. " centroid")
			A.near(My / V, P.gy, 1e-9, part.shape .. " centroid")
			A.near(Mz / V, P.gz, 1e-9, part.shape .. " centroid")
		end)
		A.eq(#Shapes.faces(H.prepare(H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { 1, 1, 1 }))), 0)
	end)

	t.it("prepare: q and −q give the same bits, no input is written to, an unknown shape is a bug", function()
		local part = H.solid(7, "Wedge", { 0.1, 0.2, 0.3 }, H.axisAngle(1, 2, 3, 40), { 0.3, 0.4, 0.5 }, "Guard")
		table.freeze(part)
		table.freeze(part.pos)
		table.freeze(part.rot)
		table.freeze(part.size)
		local P = Shapes.prepare(part, 3) :: any
		A.eq(P.id, 7)
		A.eq(P.index, 3)
		A.eq(P.slot, "Guard")
		local negated = H.solid(7, "Wedge", part.pos, { -part.rot[1], -part.rot[2], -part.rot[3], -part.rot[4] }, part.size, "Guard")
		A.eq(Dump.canonical(Shapes.prepare(negated, 3)), Dump.canonical(P))
		A.throws(function()
			Shapes.prepare(H.solid(1, "Sphere", { 0, 0, 0 }, H.I, { 1, 1, 1 }), 1)
		end, "unknown shape")
	end)
end)
