--!strict
-- S2 prototype v2: GJK distance query between two convex prepared parts, with tolerance early-outs
-- (unchanged from v1) plus Gjk.distance (full convergence, separating vector) for floating components.
-- Returns (withinTol: boolean, distanceEstimate: number, iterations: number).
local Shapes = require("./shapes")
local sqrt = math.sqrt

local Gjk = {}
Gjk.MAX_ITER = 48

-- closest point to origin on triangle abc (Ericson RTCD 5.1.5); returns point and support mask (bit1=a,bit2=b,bit4=c)
local function closestTri(ax, ay, az, bx, by, bz, cx, cy, cz): (number, number, number, number)
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
	if sum <= 1e-30 then
		-- degenerate triangle: best of its edges
		local t = d1 / (d1 - d3)
		return ax + t * abx, ay + t * aby, az + t * abz, 3
	end
	local v = vb / sum
	local w = vc / sum
	return ax + abx * v + acx * w, ay + aby * v + acy * w, az + abz * v + acz * w, 7
end

local function det3(ax, ay, az, bx, by, bz, cx, cy, cz): number
	return ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)
end

-- S: flat array of up to 4 points (x,y,z)*n. Returns new n and closest point (and rewrites S).
local function closest(S: { number }, n: number): (number, number, number, number)
	if n == 1 then
		return 1, S[1], S[2], S[3]
	elseif n == 2 then
		local ax, ay, az, bx, by, bz = S[1], S[2], S[3], S[4], S[5], S[6]
		local abx, aby, abz = bx - ax, by - ay, bz - az
		local ll = abx * abx + aby * aby + abz * abz
		if ll <= 1e-30 then
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
		local px, py, pz, mask = closestTri(S[1], S[2], S[3], S[4], S[5], S[6], S[7], S[8], S[9])
		local T = { S[1], S[2], S[3], S[4], S[5], S[6], S[7], S[8], S[9] }
		local m = 0
		for i = 0, 2 do
			if bit32.band(mask, bit32.lshift(1, i)) ~= 0 then
				S[m * 3 + 1], S[m * 3 + 2], S[m * 3 + 3] = T[i * 3 + 1], T[i * 3 + 2], T[i * 3 + 3]
				m += 1
			end
		end
		return m, px, py, pz
	end
	-- tetrahedron a b c d
	local P = { S[1], S[2], S[3], S[4], S[5], S[6], S[7], S[8], S[9], S[10], S[11], S[12] }
	local faces = { { 0, 1, 2, 3 }, { 0, 2, 3, 1 }, { 0, 3, 1, 2 }, { 1, 3, 2, 0 } }
	local vol = det3(P[4] - P[1], P[5] - P[2], P[6] - P[3], P[7] - P[1], P[8] - P[2], P[9] - P[3], P[10] - P[1], P[11] - P[2], P[12] - P[3])
	local degenerate = math.abs(vol) <= 1e-18
	local bestD, bx, by, bz, bestFace, bestMask = math.huge, 0, 0, 0, 0, 0
	local anyOutside = false
	for f = 1, 4 do
		local ia, ib, ic, id = faces[f][1], faces[f][2], faces[f][3], faces[f][4]
		local ax, ay, az = P[ia * 3 + 1], P[ia * 3 + 2], P[ia * 3 + 3]
		local qx, qy, qz = P[ib * 3 + 1], P[ib * 3 + 2], P[ib * 3 + 3]
		local rx, ry, rz = P[ic * 3 + 1], P[ic * 3 + 2], P[ic * 3 + 3]
		local dx, dy, dz = P[id * 3 + 1], P[id * 3 + 2], P[id * 3 + 3]
		local nx = (qy - ay) * (rz - az) - (qz - az) * (ry - ay)
		local ny = (qz - az) * (rx - ax) - (qx - ax) * (rz - az)
		local nz = (qx - ax) * (ry - ay) - (qy - ay) * (rx - ax)
		local signP = -(ax * nx + ay * ny + az * nz)
		local signD = (dx - ax) * nx + (dy - ay) * ny + (dz - az) * nz
		if degenerate or signP * signD < 0 then
			anyOutside = true
			local px, py, pz, mask = closestTri(ax, ay, az, qx, qy, qz, rx, ry, rz)
			local d = px * px + py * py + pz * pz
			if d < bestD then
				bestD, bx, by, bz, bestFace, bestMask = d, px, py, pz, f, mask
			end
		end
	end
	if not anyOutside then
		return 4, 0, 0, 0
	end
	local idx = { faces[bestFace][1], faces[bestFace][2], faces[bestFace][3] }
	local m = 0
	for i = 0, 2 do
		if bit32.band(bestMask, bit32.lshift(1, i)) ~= 0 then
			local src = idx[i + 1]
			S[m * 3 + 1], S[m * 3 + 2], S[m * 3 + 3] = P[src * 3 + 1], P[src * 3 + 2], P[src * 3 + 3]
			m += 1
		end
	end
	return m, bx, by, bz
end

function Gjk.within(A: any, B: any, tol: number): (boolean, number, number)
	local vx, vy, vz = A.gx - B.gx, A.gy - B.gy, A.gz - B.gz
	if vx * vx + vy * vy + vz * vz <= 1e-24 then
		return true, 0, 0
	end
	local S = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	local n = 0
	local tol2 = tol * tol
	for iter = 1, Gjk.MAX_ITER do
		local ax, ay, az = Shapes.support(A, -vx, -vy, -vz)
		local bx, by, bz = Shapes.support(B, vx, vy, vz)
		local wx, wy, wz = ax - bx, ay - by, az - bz
		local vv = vx * vx + vy * vy + vz * vz
		local vw = vx * wx + vy * wy + vz * wz
		if vw > 0 and vw * vw > tol2 * vv then
			return false, vw / sqrt(vv), iter -- lower bound already exceeds tol: separated
		end
		if vv - vw <= 1e-12 * vv then
			return vv <= tol2, sqrt(vv), iter -- converged
		end
		n += 1
		S[n * 3 - 2], S[n * 3 - 1], S[n * 3] = wx, wy, wz
		n, vx, vy, vz = closest(S, n)
		local d2 = vx * vx + vy * vy + vz * vz
		if n == 4 or d2 <= 1e-24 then
			return true, 0, iter
		end
		if d2 <= tol2 then
			return true, sqrt(d2), iter -- upper bound below tol: touching
		end
	end
	local d2 = vx * vx + vy * vy + vz * vz
	return d2 <= tol2, sqrt(d2), Gjk.MAX_ITER
end

-- full GJK distance: returns (distance, vx, vy, vz) with v = a - b for the closest points a in A, b in B
-- (0 and a zero vector when the parts overlap). The direction that moves A toward B is -v/|v|.
function Gjk.distance(A: any, B: any): (number, number, number, number)
	local vx, vy, vz = A.gx - B.gx, A.gy - B.gy, A.gz - B.gz
	if vx * vx + vy * vy + vz * vz <= 1e-24 then
		return 0, 0, 0, 0
	end
	local S = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	local n = 0
	for _ = 1, Gjk.MAX_ITER do
		local ax, ay, az = Shapes.support(A, -vx, -vy, -vz)
		local bx, by, bz = Shapes.support(B, vx, vy, vz)
		local wx, wy, wz = ax - bx, ay - by, az - bz
		local vv = vx * vx + vy * vy + vz * vz
		local vw = vx * wx + vy * wy + vz * wz
		if vv - vw <= 1e-12 * vv then
			break
		end
		n += 1
		S[n * 3 - 2], S[n * 3 - 1], S[n * 3] = wx, wy, wz
		n, vx, vy, vz = closest(S, n)
		if n == 4 or vx * vx + vy * vy + vz * vz <= 1e-24 then
			return 0, 0, 0, 0
		end
	end
	return sqrt(vx * vx + vy * vy + vz * vz), vx, vy, vz
end

return Gjk
