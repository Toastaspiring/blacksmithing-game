--!strict
-- Physics/Gjk (SPEC §4.1, §4.2; owner S2): GJK between two convex prepared parts, on Shapes.support. Pure; §4.1's
-- determinism rules apply, and the only state is per call.
--
--   within(a, b, tol)  are the solids at most tol apart? (withinTol, distanceEstimate, iterations): contact for
--                      connectivity (tol = CONTACT_TOL) and overlap ownership. Early outs on the lower bound
--                      v·w/|v| > tol and the upper bound |v| ≤ tol, at most GJK_MAX_ITER iterations. Mean 3.1, max 9
--                      measured on 300 random pairs (E-S2.3).
--   distance(a, b)     no early out on a tolerance: (distance, vx, vy, vz), v = pa − pb for the closest points pa of a
--                      and pb of b, so −v/|v| is the direction that moves a toward b; 0 and a zero vector when they
--                      overlap. It gives a floating component's gap and dir (§4.2). Near convergence, rounding can make
--                      the simplex cycle between the converged v and a longer one until GJK_MAX_ITER, so it returns the
--                      shortest v seen, not the last. Every v is a point of the Minkowski difference, so that length is
--                      an upper bound on the true gap; curved pairs can stop about 4e-8 above it (T-VAL-03).
-- Simplex features are found with Ericson's closest-point tests (Real-Time Collision Detection, 5.1.5).

local Balance = require("../Definitions/Balance")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared

local sqrt, abs = math.sqrt, math.abs
local support = Shapes.support

local MAX_ITER = Balance.Geometry.GJK_MAX_ITER

-- numeric guards of the algorithm (squared lengths and volumes of the simplex), not tunables
local ZERO_LENGTH2 = 1e-24 -- two points, or a point and the origin, coincide
local CONVERGED = 1e-12 -- v·v − v·w ≤ this · v·v: v cannot get shorter
local DEGENERATE_EDGE2 = 1e-30 -- a simplex edge or triangle with no extent
local DEGENERATE_VOLUME = 1e-18 -- a tetrahedron with no volume

-- The vertices of a triangle's closest feature, by the mask closestTriangle returns: 1 a, 2 b, 3 ab, 4 c, 5 ac, 6 bc,
-- 7 abc (0-based, ascending).
local FEATURE: { { number } } = table.freeze({
	table.freeze({ 0 }),
	table.freeze({ 1 }),
	table.freeze({ 0, 1 }),
	table.freeze({ 2 }),
	table.freeze({ 0, 2 }),
	table.freeze({ 1, 2 }),
	table.freeze({ 0, 1, 2 }),
})

-- A tetrahedron's faces {a, b, c} and the vertex opposite each.
local TETRA_FACES: { { number } } = table.freeze({
	table.freeze({ 0, 1, 2, 3 }),
	table.freeze({ 0, 2, 3, 1 }),
	table.freeze({ 0, 3, 1, 2 }),
	table.freeze({ 1, 3, 2, 0 }),
})

-- The point of triangle abc closest to the origin and its feature mask.
local function closestTriangle(ax: number, ay: number, az: number, bx: number, by: number, bz: number, cx: number,
	cy: number, cz: number): (number, number, number, number)
	local abx, aby, abz = bx - ax, by - ay, bz - az
	local acx, acy, acz = cx - ax, cy - ay, cz - az
	local d1 = -(abx * ax + aby * ay + abz * az)
	local d2 = -(acx * ax + acy * ay + acz * az)
	if d1 <= 0 and d2 <= 0 then
		return ax, ay, az, 1
	end
	local d3 = -(abx * bx + aby * by + abz * bz)
	local d4 = -(acx * bx + acy * by + acz * bz)
	if d3 >= 0 and d4 <= d3 then
		return bx, by, bz, 2
	end
	local vc = d1 * d4 - d3 * d2
	if vc <= 0 and d1 >= 0 and d3 <= 0 then
		local t = d1 / (d1 - d3)
		return ax + t * abx, ay + t * aby, az + t * abz, 3
	end
	local d5 = -(abx * cx + aby * cy + abz * cz)
	local d6 = -(acx * cx + acy * cy + acz * cz)
	if d6 >= 0 and d5 <= d6 then
		return cx, cy, cz, 4
	end
	local vb = d5 * d2 - d1 * d6
	if vb <= 0 and d2 >= 0 and d6 <= 0 then
		local t = d2 / (d2 - d6)
		return ax + t * acx, ay + t * acy, az + t * acz, 5
	end
	local va = d3 * d6 - d5 * d4
	if va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0 then
		local t = (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return bx + t * (cx - bx), by + t * (cy - by), bz + t * (cz - bz), 6
	end
	local sum = va + vb + vc
	if sum <= DEGENERATE_EDGE2 then -- a degenerate triangle: its edge ab
		local t = d1 / (d1 - d3)
		return ax + t * abx, ay + t * aby, az + t * abz, 3
	end
	local v = vb / sum
	local w = vc / sum
	return ax + abx * v + acx * w, ay + aby * v + acy * w, az + abz * v + acz * w, 7
end

local function det3(ax: number, ay: number, az: number, bx: number, by: number, bz: number, cx: number, cy: number,
	cz: number): number
	return ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)
end

-- S holds n ≤ 4 simplex points, flat x, y, z. Reduces S to the feature closest to the origin and returns its size and
-- the closest point; a size of 4 means the origin is inside the tetrahedron. separated: a support has already proved
-- the solids apart (v·w > 0, a plane between the origin and the whole Minkowski difference), so the origin cannot be in
-- a simplex of it. Rounding can still say so of a nearly flat tetrahedron, whose face signs are noise: then the closest
-- of all four faces stands, and the loop goes on. Without this, a gap of 0.03 can read as 0 (T-VAL-03).
local function closest(S: { number }, n: number, separated: boolean): (number, number, number, number)
	if n == 1 then
		return 1, S[1], S[2], S[3]
	elseif n == 2 then
		local ax, ay, az, bx, by, bz = S[1], S[2], S[3], S[4], S[5], S[6]
		local abx, aby, abz = bx - ax, by - ay, bz - az
		local ll = abx * abx + aby * aby + abz * abz
		if ll <= DEGENERATE_EDGE2 then
			S[1], S[2], S[3] = bx, by, bz
			return 1, bx, by, bz
		end
		local t = -(ax * abx + ay * aby + az * abz) / ll
		if t <= 0 then
			return 1, ax, ay, az
		elseif t >= 1 then
			S[1], S[2], S[3] = bx, by, bz
			return 1, bx, by, bz
		end
		return 2, ax + t * abx, ay + t * aby, az + t * abz
	elseif n == 3 then
		local px, py, pz, mask = closestTriangle(S[1], S[2], S[3], S[4], S[5], S[6], S[7], S[8], S[9])
		local feature = FEATURE[mask]
		-- ascending indices, so copying in place never overwrites a point still to be read
		for m = 1, #feature do
			local i = feature[m]
			S[3 * m - 2], S[3 * m - 1], S[3 * m] = S[3 * i + 1], S[3 * i + 2], S[3 * i + 3]
		end
		return #feature, px, py, pz
	end
	-- a tetrahedron
	local P = { S[1], S[2], S[3], S[4], S[5], S[6], S[7], S[8], S[9], S[10], S[11], S[12] }
	local volume = det3(P[4] - P[1], P[5] - P[2], P[6] - P[3], P[7] - P[1], P[8] - P[2], P[9] - P[3], P[10] - P[1],
		P[11] - P[2], P[12] - P[3])
	local degenerate = abs(volume) <= DEGENERATE_VOLUME
	local bestD, bx, by, bz, bestFace, bestMask = math.huge, 0, 0, 0, 0, 0
	for pass = 1, 2 do
		for f = 1, 4 do
			local face = TETRA_FACES[f]
			local ia, ib, ic, id = face[1], face[2], face[3], face[4]
			local ax, ay, az = P[ia * 3 + 1], P[ia * 3 + 2], P[ia * 3 + 3]
			local qx, qy, qz = P[ib * 3 + 1], P[ib * 3 + 2], P[ib * 3 + 3]
			local rx, ry, rz = P[ic * 3 + 1], P[ic * 3 + 2], P[ic * 3 + 3]
			local dx, dy, dz = P[id * 3 + 1], P[id * 3 + 2], P[id * 3 + 3]
			local nx = (qy - ay) * (rz - az) - (qz - az) * (ry - ay)
			local ny = (qz - az) * (rx - ax) - (qx - ax) * (rz - az)
			local nz = (qx - ax) * (ry - ay) - (qy - ay) * (rx - ax)
			local signP = -(ax * nx + ay * ny + az * nz)
			local signD = (dx - ax) * nx + (dy - ay) * ny + (dz - az) * nz
			if pass == 2 or degenerate or signP * signD < 0 then -- the origin is outside this face
				local px, py, pz, mask = closestTriangle(ax, ay, az, qx, qy, qz, rx, ry, rz)
				local d = px * px + py * py + pz * pz
				if d < bestD then
					bestD, bx, by, bz, bestFace, bestMask = d, px, py, pz, f, mask
				end
			end
		end
		if bestFace ~= 0 then
			break
		elseif not separated then
			return 4, 0, 0, 0
		end
	end
	local face = TETRA_FACES[bestFace]
	local feature = FEATURE[bestMask]
	for m = 1, #feature do
		local src = face[feature[m] + 1]
		S[3 * m - 2], S[3 * m - 1], S[3 * m] = P[src * 3 + 1], P[src * 3 + 2], P[src * 3 + 3]
	end
	return #feature, bx, by, bz
end

local Gjk = {}

Gjk.MAX_ITER = MAX_ITER

function Gjk.within(a: Prepared, b: Prepared, tol: number): (boolean, number, number)
	local vx, vy, vz = a.gx - b.gx, a.gy - b.gy, a.gz - b.gz
	if vx * vx + vy * vy + vz * vz <= ZERO_LENGTH2 then
		return true, 0, 0
	end
	local S: { number } = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	local n = 0
	local tol2 = tol * tol
	local separated = false
	for iter = 1, MAX_ITER do
		local ax, ay, az = support(a, -vx, -vy, -vz)
		local bx, by, bz = support(b, vx, vy, vz)
		local wx, wy, wz = ax - bx, ay - by, az - bz
		local vv = vx * vx + vy * vy + vz * vz
		local vw = vx * wx + vy * wy + vz * wz
		if vw > 0 and vw * vw > tol2 * vv then
			return false, vw / sqrt(vv), iter -- the lower bound already exceeds tol: separated
		end
		if vv - vw <= CONVERGED * vv then
			return vv <= tol2, sqrt(vv), iter
		end
		separated = separated or vw > 0
		n += 1
		S[n * 3 - 2], S[n * 3 - 1], S[n * 3] = wx, wy, wz
		n, vx, vy, vz = closest(S, n, separated)
		local d2 = vx * vx + vy * vy + vz * vz
		if n == 4 or d2 <= ZERO_LENGTH2 then
			return true, 0, iter
		end
		if d2 <= tol2 then
			return true, sqrt(d2), iter -- the upper bound is below tol: touching
		end
	end
	local d2 = vx * vx + vy * vy + vz * vz
	return d2 <= tol2, sqrt(d2), MAX_ITER
end

function Gjk.distance(a: Prepared, b: Prepared): (number, number, number, number)
	local vx, vy, vz = a.gx - b.gx, a.gy - b.gy, a.gz - b.gz
	if vx * vx + vy * vy + vz * vz <= ZERO_LENGTH2 then
		return 0, 0, 0, 0
	end
	local S: { number } = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	local n = 0
	local separated = false
	-- the shortest v seen: no break when |v| stops falling, since it can legitimately grow in the first iterations
	local bestVV, bestX, bestY, bestZ = vx * vx + vy * vy + vz * vz, vx, vy, vz
	for _ = 1, MAX_ITER do
		local ax, ay, az = support(a, -vx, -vy, -vz)
		local bx, by, bz = support(b, vx, vy, vz)
		local wx, wy, wz = ax - bx, ay - by, az - bz
		local vv = vx * vx + vy * vy + vz * vz
		local vw = vx * wx + vy * wy + vz * wz
		if vv - vw <= CONVERGED * vv then
			break
		end
		separated = separated or vw > 0
		n += 1
		S[n * 3 - 2], S[n * 3 - 1], S[n * 3] = wx, wy, wz
		n, vx, vy, vz = closest(S, n, separated)
		local d2 = vx * vx + vy * vy + vz * vz
		if n == 4 or d2 <= ZERO_LENGTH2 then
			return 0, 0, 0, 0
		end
		if d2 < bestVV then
			bestVV, bestX, bestY, bestZ = d2, vx, vy, vz
		end
	end
	return sqrt(bestVV), bestX, bestY, bestZ
end

return table.freeze(Gjk)
