--!strict
-- T-VAL-03 Physics/Gjk (SPEC §4.2, E-S2.3, E-S8.5): contact and distance against brute force on random pairs of all five
-- shapes, and E-S2.3's targeted cases. The brute force is PhysicsHelpers.bruteDistance: surface samples and vertices of
-- each solid, each with its exact distance to the other solid, independent of the simplex code. At the legal extremes of
-- size, too far for the brute force's samples, far distances certify themselves with the separating plane at v, and near
-- ones answer to PhysicsHelpers.gapByProjections.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local H = require("./PhysicsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local Limits = require("../../src/shared/Definitions/Limits")
local Gjk = require("../../src/shared/Physics/Gjk")
local Shapes = require("../../src/shared/Physics/Shapes")

type Rng = TestRng.TestRng

local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local TOL = Limits.CONTACT_TOL
-- the brute force's samples are ≈ 0.0075 apart on the largest faces: it decides only outside this band around TOL
local BAND = 0.006

local function randomSize(rng: Rng, shape: string): { number }
	local size = { rng:range(0.08, 0.48), rng:range(0.08, 0.48), rng:range(0.08, 0.48) }
	if shape == "Ball" then
		size = { size[1], size[1], size[1] }
	elseif shape == "Cylinder" then
		size = { size[1], size[2], size[2] }
	end
	return size
end

type Pair = { a: Shapes.Prepared, b: Shapes.Prepared, target: number, what: string }

-- Two random solids, b moved along a random direction until GJK says they are `target` apart (0 to 0.03).
local function randomPair(rng: Rng): Pair
	local shapeA, shapeB = rng:pick(SHAPES), rng:pick(SHAPES)
	local a = H.prepare(H.solid(1, shapeA, { 0, 1, 0 }, H.randomQuat(rng), randomSize(rng, shapeA)))
	local q = H.randomQuat(rng)
	local n = math.sqrt(q[1] * q[1] + q[2] * q[2] + q[3] * q[3])
	local dx, dy, dz = q[1] / n, q[2] / n, q[3] / n
	local rotB, sizeB = H.randomQuat(rng), randomSize(rng, shapeB)
	local target = rng:float() * 0.03
	local lo, hi = 0, 1.5
	local b = H.prepare(H.solid(2, shapeB, { hi * dx, 1 + hi * dy, hi * dz }, rotB, sizeB))
	for _ = 1, 32 do
		local mid = (lo + hi) / 2
		b = H.prepare(H.solid(2, shapeB, { mid * dx, 1 + mid * dy, mid * dz }, rotB, sizeB))
		if Gjk.distance(a, b) < target then
			lo = mid
		else
			hi = mid
		end
	end
	return { a = a, b = b, target = target, what = shapeA .. "/" .. shapeB }
end

local function agreeWithBrute(count: number)
	local rng = TestRng.new(Tol.PROP_BASE_SEED)
	local decisive, totalIterations, most = 0, 0, 0
	for _ = 1, count do
		local pair = randomPair(rng)
		local within, estimate, iterations = Gjk.within(pair.a, pair.b, TOL)
		totalIterations += iterations
		most = math.max(most, iterations)
		local brute = H.bruteDistance(pair.a, pair.b)
		if math.abs(brute - TOL) > BAND then
			decisive += 1
			A.eq(within, brute <= TOL, string.format("%s: GJK estimate %.5f, brute force %.5f", pair.what, estimate, brute))
			A.near(Gjk.distance(pair.a, pair.b), brute, BAND, pair.what .. " distance vs brute force")
		end
	end
	-- randomPair's targets are uniform over 0…0.03, so about 1 − 2·BAND/0.03 = 60 % of the pairs are decisive: the floor
	-- sits well under that, or it holds only on some seeds. E-S2.3: mean 3.1, max 9 iterations
	A.truthy(decisive >= count * 0.35, "too few decisive pairs: " .. decisive .. " of " .. count)
	A.truthy(totalIterations / count <= 8, "mean iterations " .. totalIterations / count)
	A.truthy(most <= Balance.Geometry.GJK_MAX_ITER, "max iterations " .. most)
end

local function block(pos: { number }, size: { number }, rot: { number }?): Shapes.Prepared
	return H.prepare(H.solid(1, "Block", pos, rot or H.I, size))
end

return Test.suite("Physics/Gjk", function(t)
	t.it("T-VAL-03 E-S2.3's targeted cases: flush, gaps around CONTACT_TOL, edges, ball on a face, rotated, apex", function()
		local unit = block({ 0, 0, 0 }, { 1, 1, 1 })
		A.truthy((Gjk.within(unit, block({ 0, 1, 0 }, { 1, 1, 1 }), TOL)), "flush faces")
		A.truthy((Gjk.within(unit, block({ 0, 1.005, 0 }, { 1, 1, 1 }), TOL)), "gap 0.005: contact")
		A.truthy((Gjk.within(unit, block({ 0, 1.0099, 0 }, { 1, 1, 1 }), TOL)), "gap 0.0099: contact")
		A.falsy((Gjk.within(unit, block({ 0, 1.015, 0 }, { 1, 1, 1 }), TOL)), "gap 0.015: none")
		A.falsy((Gjk.within(unit, block({ 0, 1.5, 0 }, { 1, 1, 1 }), TOL)), "far apart")
		A.truthy((Gjk.within(unit, block({ 0.2, 0.3, 0 }, { 1, 1, 1 }), TOL)), "overlapping")
		A.truthy((Gjk.within(unit, block({ 0, 0, 0 }, { 0.1, 0.1, 0.1 }), TOL)), "same centroid, one inside the other")
		-- an edge on a face: a block turned 45° about Z whose lowest edge touches y = 0.5
		local turned = H.Z45
		local diagonal = math.sqrt(2) / 2
		A.truthy((Gjk.within(unit, block({ 0, 0.5 + diagonal, 0 }, { 1, 1, 1 }, turned), TOL)), "edge on a face")
		A.falsy((Gjk.within(unit, block({ 0, 0.5 + diagonal + 0.02, 0 }, { 1, 1, 1 }, turned), TOL)), "edge 0.02 off a face")
		-- crossed edges: two blocks turned 45°, one about Z and one about X, their edges crossing at a point
		local aboutX = H.axisAngle(1, 0, 0, 45)
		local a, b = block({ 0, 0, 0 }, { 1, 1, 1 }, turned), block({ 0, 2 * diagonal + 0.005, 0 }, { 1, 1, 1 }, aboutX)
		A.truthy((Gjk.within(a, b, TOL)), "crossed edges 0.005 apart")
		A.falsy((Gjk.within(a, block({ 0, 2 * diagonal + 0.015, 0 }, { 1, 1, 1 }, aboutX), TOL)), "crossed edges 0.015 apart")
		-- a ball on a face
		local ball = H.prepare(H.solid(2, "Ball", { 0, 0.5 + 0.25, 0 }, H.I, { 0.5, 0.5, 0.5 }))
		A.truthy((Gjk.within(unit, ball, TOL)), "ball on a face")
		A.near(Gjk.distance(unit, ball), 0, 1e-9, "a ball resting on a face has no gap")
		local away = H.prepare(H.solid(2, "Ball", { 0, 0.5 + 0.25 + 0.03, 0 }, H.I, { 0.5, 0.5, 0.5 }))
		A.near(Gjk.distance(unit, away), 0.03, 1e-9, "ball 0.03 off a face")
		-- a rotated cylinder 0.009 and 0.012 off a face: its lowest rim point is the support
		local q = H.axisAngle(1, 0.4, 0.3, 50)
		local cylinder = { 0.6, 0.2, 0.2 }
		local probe = H.prepare(H.solid(2, "Cylinder", { 0, 0, 0 }, q, cylinder))
		local _, low = Shapes.extentAlong(probe, 0, -1, 0)
		local base = 0.5 + low
		A.truthy((Gjk.within(unit, H.prepare(H.solid(2, "Cylinder", { 0, base + 0.009, 0 }, q, cylinder)), TOL)), "cylinder at 0.009")
		A.falsy((Gjk.within(unit, H.prepare(H.solid(2, "Cylinder", { 0, base + 0.012, 0 }, q, cylinder)), TOL)), "cylinder at 0.012")
		-- a CornerWedge's apex pointing at a face from below: its apex is the highest point
		local corner = { 0.4, 0.3, 0.2 }
		A.truthy((Gjk.within(unit, H.prepare(H.solid(2, "CornerWedge", { -0.3, -0.5 - 0.15 - 0.005, 0.1 }, H.I, corner)), TOL)),
			"apex 0.005 under a face")
		A.falsy((Gjk.within(unit, H.prepare(H.solid(2, "CornerWedge", { -0.3, -0.5 - 0.15 - 0.015, 0.1 }, H.I, corner)), TOL)),
			"apex 0.015 under a face")
	end)

	t.it("T-VAL-03 within and distance agree with brute force, 40 random pairs", function()
		agreeWithBrute(40)
	end)

	t.slow("T-VAL-03 within and distance agree with brute force, 300 random pairs", function()
		agreeWithBrute(300)
	end)

	-- The legal extremes (T-VAL-03's random pairs stay at 0.08–0.48), where the simplex can cycle near convergence and the
	-- brute force's samples lie too far apart. Two answers that share nothing with the simplex:
	--   far pairs   |v| is an upper bound on the gap and the plane at v a lower bound, so they certify each other
	--   near pairs  the plane proves little: its slack is first-order in v's direction across a long face, and v is
	--               short, while the distance's error is second-order (slack 0.00149 on a 0.15 × 0.5 × 4 CornerWedge and
	--               a 0.15 Ball, whose gap of 0.00176585 is right to 1e-8; 3.6 at a gap of 1e-9). So gapByProjections, an
	--               upper bound on the gap, says no distance is longer than it need be, and no contact is really a gap.
	t.it("T-VAL-03 distance: 6,000 pairs of MIN_DIM to MAX_DIM sides, against the plane at v and alternating projections", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED + 1)
		local SIDES = { 0.02, 0.035, 0.06, 0.15, 0.5, 1.5, 2.5, 4 }
		local function solid(id: number): Shapes.Prepared
			local shape = rng:pick(SHAPES)
			local a, b, c = rng:pick(SIDES), rng:pick(SIDES), rng:pick(SIDES)
			local size = if shape == "Ball" then { a, a, a } elseif shape == "Cylinder" then { a, b, b } else { a, b, c }
			local pos = { rng:range(-1, 1), rng:range(0, 5), rng:range(-0.3, 0.3) }
			local rot = if rng:float() < 0.5 then H.axisAngle(0, 0, 1, rng:range(-180, 180)) else H.randomQuat(rng)
			return H.prepare(H.solid(id, shape, pos, rot, size), id)
		end
		local far, near, touching = 0, 0, 0
		local worstPlane, worstNear, worstTouching = 0, 0, 0
		for _ = 1, 6000 do
			local a, b = solid(1), solid(2)
			local d, vx, vy, vz = Gjk.distance(a, b)
			if d >= 0.05 then
				far += 1
				local ax, ay, az = Shapes.support(a, -vx, -vy, -vz)
				local bx, by, bz = Shapes.support(b, vx, vy, vz)
				worstPlane = math.max(worstPlane, d - ((ax - bx) * vx + (ay - by) * vy + (az - bz) * vz) / d)
			elseif d > 0 then
				near += 1
				worstNear = math.max(worstNear, d - H.gapByProjections(a, b))
			else
				touching += 1
				worstTouching = math.max(worstTouching, H.gapByProjections(a, b))
			end
		end
		A.truthy(far >= 1000 and near >= 20 and touching >= 200, string.format("too few pairs: far %d, near %d, touching %d", far, near, touching))
		A.truthy(worstPlane <= 1e-3, "a far distance above its own lower bound by " .. worstPlane)
		A.truthy(worstNear <= 1e-6, "a near distance longer than a pair of points shows by " .. worstNear)
		-- the projections stop short of an overlap by up to 0.0075: this catches a real gap read as contact
		A.truthy(worstTouching <= 0.02, "a contact whose solids stay apart by " .. worstTouching)
	end)

	t.it("T-VAL-03 distance: a thin CornerWedge and a Cylinder 0.0138 apart (the last v of a cycle read 0.3307)", function()
		local a = H.prepare(H.solid(1, "CornerWedge", { -0.0082194630211466415, 1.8871406099707502, -0.21584628688869995 },
			{ 0, 0, -0.43203281863819104, 0.90185788438064896 }, { 2.5, 0.02, 0.15 }), 1)
		local b = H.prepare(H.solid(2, "Cylinder", { 0.16789538225807898, 2.0522677955758892, -0.083330587949603796 },
			{ 0, 0, 0.17001612042532047, 0.98544128125196939 }, { 0.5, 0.1, 0.1 }), 2)
		A.near(Gjk.distance(a, b), 0.013823519646990247, 1e-9, "the gap")
		A.near(Gjk.distance(b, a), 0.013823519646990247, 1e-9, "the gap, the other way round")
	end)

	t.it("distance: gap and separating vector of closest points; v = pa − pb, so −v moves a toward b", function()
		local a, b = block({ 0, 0, 0 }, { 1, 1, 1 }), block({ 0, 1.03, 0 }, { 1, 1, 1 })
		local d, vx, vy, vz = Gjk.distance(a, b)
		A.near(d, 0.03, 1e-12)
		A.near(vx, 0, 1e-12)
		A.near(vy, -0.03, 1e-12)
		A.near(vz, 0, 1e-12)
		-- moving a along −v by d makes them touch
		local moved = block({ 0, 0.03, 0 }, { 1, 1, 1 })
		A.near(Gjk.distance(moved, b), 0, 1e-9)
		-- the corner case: nearest points are two block corners
		local far = block({ 2, 2, 2 }, { 1, 1, 1 })
		local d2 = Gjk.distance(a, far)
		A.near(d2, math.sqrt(3), 1e-9)
		-- overlap: zero distance and a zero vector
		local d3, x3, y3, z3 = Gjk.distance(a, block({ 0.2, 0.2, 0.2 }, { 1, 1, 1 }))
		A.eq(d3, 0)
		A.deepEq({ x3, y3, z3 }, { 0, 0, 0 })
	end)

	t.it("distance is symmetric, and within(tol) holds exactly when distance ≤ tol", function()
		Prop.check(Tol.PROP_N, randomPair, function(pair: Pair)
			local ab, bc = Gjk.distance(pair.a, pair.b), Gjk.distance(pair.b, pair.a)
			A.near(ab, bc, 1e-9, pair.what .. " symmetric")
			A.near(ab, pair.target, 1e-6, pair.what .. " the bisection's target")
			if math.abs(ab - TOL) > 1e-9 then
				A.eq((Gjk.within(pair.a, pair.b, TOL)), ab <= TOL, pair.what .. " within vs distance")
			end
		end)
	end)

	t.it("the same pair gives the same bits; the module holds no state between calls", function()
		local rng = TestRng.new(7)
		for _ = 1, 50 do
			local pair = randomPair(rng)
			local d1, x1, y1, z1 = Gjk.distance(pair.a, pair.b)
			local w1, e1, i1 = Gjk.within(pair.a, pair.b, TOL)
			local d2, x2, y2, z2 = Gjk.distance(pair.a, pair.b)
			local w2, e2, i2 = Gjk.within(pair.a, pair.b, TOL)
			A.deepEq({ d1, x1, y1, z1 }, { d2, x2, y2, z2 })
			A.eq(w1, w2)
			A.eq(e1, e2)
			A.eq(i1, i2)
		end
		A.eq(Gjk.MAX_ITER, Balance.Geometry.GJK_MAX_ITER)
	end)
end)
