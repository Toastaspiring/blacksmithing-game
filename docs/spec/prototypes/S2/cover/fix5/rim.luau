--!nocheck
-- m2x-fix-5: the candidates for a cap circle's farthest point from a Cylinder's axis.
--   v1(d, r, n, u)            V1's rimFarthest as in fixA (d the centre's offset from Q's centre, whole; cutoff 1e-6)
--   search(m⊥, r, n, u, cut)  the same search on the offset across the axis taken by its parts, cutoff `cut`
--   bounds(m⊥, r, v, w, u)    (above, below): sqrt(|m⊥|² + 2r|p| + r²) and the circle's point toward p (p: m⊥ in the
--                              cap's plane, its coordinates on P's local Y and Z)
local sqrt, abs, max = math.sqrt, math.abs, math.max
local R = {}

function R.v1(dx, dy, dz, r, nx, ny, nz, ux, uy, uz)
	local du = dx * ux + dy * uy + dz * uz
	local ax, ay, az = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
	local al = sqrt(ax * ax + ay * ay + az * az)
	if al <= 1e-6 then
		local px, py, pz = dx - du * ux, dy - du * uy, dz - du * uz
		return sqrt(px * px + py * py + pz * pz) + r
	end
	ax, ay, az = ax / al, ay / al, az / al
	local ex, ey, ez = ny * az - nz * ay, nz * ax - nx * az, nx * ay - ny * ax
	local eu = ex * ux + ey * uy + ez * uz
	local K = dx * dx + dy * dy + dz * dz + r * r - du * du
	local A = 2 * r * abs(dx * ax + dy * ay + dz * az)
	local B = 2 * r * (dx * ex + dy * ey + dz * ez - du * eu)
	local C = r * r * eu * eu
	local lo, hi = -1, 1
	for _ = 1, 60 do
		local s = (lo + hi) / 2
		if (B - 2 * C * s) * sqrt(max(0, 1 - s * s)) - A * s > 0 then
			lo = s
		else
			hi = s
		end
	end
	local s = (lo + hi) / 2
	return sqrt(max(0, K + A * sqrt(max(0, 1 - s * s)) + B * s - C * s * s))
end

-- m⊥ = (mx, my, mz), already across u
function R.search(mx, my, mz, r, nx, ny, nz, ux, uy, uz, cut)
	local ax, ay, az = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
	local al = sqrt(ax * ax + ay * ay + az * az)
	if al <= cut then
		return sqrt(mx * mx + my * my + mz * mz) + r
	end
	ax, ay, az = ax / al, ay / al, az / al
	local ex, ey, ez = ny * az - nz * ay, nz * ax - nx * az, nx * ay - ny * ax
	local eu = ex * ux + ey * uy + ez * uz
	local K = mx * mx + my * my + mz * mz + r * r
	local A = 2 * r * abs(mx * ax + my * ay + mz * az)
	local B = 2 * r * (mx * ex + my * ey + mz * ez)
	local C = r * r * eu * eu
	local lo, hi = -1, 1
	for _ = 1, 60 do
		local s = (lo + hi) / 2
		if (B - 2 * C * s) * sqrt(max(0, 1 - s * s)) - A * s > 0 then
			lo = s
		else
			hi = s
		end
	end
	local s = (lo + hi) / 2
	return sqrt(max(0, K + A * sqrt(max(0, 1 - s * s)) + B * s - C * s * s))
end

-- the same, the found point taken by its parts
function R.searchPt(mx, my, mz, r, nx, ny, nz, ux, uy, uz, cut)
	local ax, ay, az = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
	local al = sqrt(ax * ax + ay * ay + az * az)
	if al <= cut then
		return sqrt(mx * mx + my * my + mz * mz) + r
	end
	ax, ay, az = ax / al, ay / al, az / al
	local ex, ey, ez = ny * az - nz * ay, nz * ax - nx * az, nx * ay - ny * ax
	local eu = ex * ux + ey * uy + ez * uz
	local ma = mx * ax + my * ay + mz * az
	local A = 2 * r * abs(ma)
	local B = 2 * r * (mx * ex + my * ey + mz * ez)
	local C = r * r * eu * eu
	local lo, hi = -1, 1
	for _ = 1, 60 do
		local s = (lo + hi) / 2
		if (B - 2 * C * s) * sqrt(max(0, 1 - s * s)) - A * s > 0 then
			lo = s
		else
			hi = s
		end
	end
	local s = (lo + hi) / 2
	local c = sqrt(max(0, 1 - s * s))
	if ma < 0 then
		c = -c
	end
	local px, py, pz = mx + r * (c * ax + s * ex), my + r * (c * ay + s * ey), mz + r * (c * az + s * ez)
	local t = px * ux + py * uy + pz * uz
	px, py, pz = px - t * ux, py - t * uy, pz - t * uz
	return sqrt(px * px + py * py + pz * pz)
end

-- (above, below) the farthest point; v, w P's local Y and Z (the cap's plane)
function R.bounds(mx, my, mz, r, vx, vy, vz, wx, wy, wz, ux, uy, uz)
	local pv, pw = mx * vx + my * vy + mz * vz, mx * wx + my * wy + mz * wz
	local pl = sqrt(pv * pv + pw * pw)
	local m2 = mx * mx + my * my + mz * mz
	local above = sqrt(m2 + 2 * r * pl + r * r)
	local c, s = 1, 0
	if pl > 0 then
		c, s = pv / pl, pw / pl
	end
	local dx, dy, dz = c * vx + s * wx, c * vy + s * wy, c * vz + s * wz
	local du = dx * ux + dy * uy + dz * uz
	local qx, qy, qz = mx + r * (dx - du * ux), my + r * (dy - du * uy), mz + r * (dz - du * uz)
	return above, sqrt(qx * qx + qy * qy + qz * qz)
end

-- the old bound and the root mean square
function R.old(mx, my, mz, r)
	return sqrt(mx * mx + my * my + mz * mz) + r
end

function R.rms(mx, my, mz, r)
	return sqrt(mx * mx + my * my + mz * mz + r * r / 2)
end

return R
