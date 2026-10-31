--!strict
-- S2 prototype: primitive shapes exactly as Roblox renders them (verified in Studio, see draft §4.1).
-- Local frame: half extents hx, hy, hz.
--   Block       |x|<=hx, |y|<=hy, |z|<=hz
--   Wedge       Block AND z/hz >= y/hy           (full bottom -Y and back +Z faces; slope faces -Z/+Y)
--   CornerWedge Block AND y/hy <= x/hx AND y/hy <= -z/hz   (pyramid, apex (+hx,+hy,-hz))
--   Cylinder    axis local X, length 2hx, radius r = min(hy,hz)
--   Ball        radius r = min(hx,hy,hz)
local Num = require("./num")

local sqrt, abs, max, min, ceil = math.sqrt, math.abs, math.max, math.min, math.ceil
local PI = Num.PI

local Shapes = {}

local BLOCK, WEDGE, CORNER, CYL, BALL = 1, 2, 3, 4, 5
Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYL, Shapes.BALL = BLOCK, WEDGE, CORNER, CYL, BALL
Shapes.CODE = { Block = BLOCK, Wedge = WEDGE, CornerWedge = CORNER, Cylinder = CYL, Ball = BALL }
Shapes.NAME = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }

Shapes.MIN_DIM = 0.05
Shapes.MAX_DIM = 6.0

-- ---------------------------------------------------------------- sanitize (prototype of §3.3)
function Shapes.sanitizePart(part: any): any
	local q = part.rot
	local w, x, y, z = q[1], q[2], q[3], q[4]
	local n = sqrt(w * w + x * x + y * y + z * z)
	assert(n >= 1e-6, "degenerate quaternion")
	w, x, y, z = w / n, x / n, y / n, z / n
	if w < 0 or (w == 0 and (x < 0 or (x == 0 and (y < 0 or (y == 0 and z < 0))))) then
		w, x, y, z = -w, -x, -y, -z
	end
	local sx = min(Shapes.MAX_DIM, max(Shapes.MIN_DIM, part.size[1]))
	local sy = min(Shapes.MAX_DIM, max(Shapes.MIN_DIM, part.size[2]))
	local sz = min(Shapes.MAX_DIM, max(Shapes.MIN_DIM, part.size[3]))
	if part.shape == "Ball" then
		local d = min(sx, sy, sz)
		sx, sy, sz = d, d, d
	elseif part.shape == "Cylinder" then
		local d = min(sy, sz)
		sy, sz = d, d
	end
	return {
		id = part.id,
		shape = part.shape,
		slot = part.slot,
		material = part.material,
		pos = { part.pos[1], part.pos[2], part.pos[3] },
		rot = { w, x, y, z },
		size = { sx, sy, sz },
	}
end

-- ---------------------------------------------------------------- prepare
function Shapes.prepare(part: any, index: number): any
	local q = part.rot
	local w, x, y, z = q[1], q[2], q[3], q[4]
	local P: any = {
		index = index,
		id = part.id,
		code = Shapes.CODE[part.shape],
		slot = part.slot,
		material = part.material,
		cx = part.pos[1],
		cy = part.pos[2],
		cz = part.pos[3],
		-- columns of R = world directions of the local axes
		ux = 1 - 2 * (y * y + z * z),
		uy = 2 * (x * y + w * z),
		uz = 2 * (x * z - w * y),
		vx = 2 * (x * y - w * z),
		vy = 1 - 2 * (x * x + z * z),
		vz = 2 * (y * z + w * x),
		wx = 2 * (x * z + w * y),
		wy = 2 * (y * z - w * x),
		wz = 1 - 2 * (x * x + y * y),
		hx = part.size[1] / 2,
		hy = part.size[2] / 2,
		hz = part.size[3] / 2,
	}
	local hx, hy, hz = P.hx, P.hy, P.hz
	local code = P.code
	P.r = 0
	P.k1, P.k2 = 0, 0
	if code == WEDGE then
		P.k1 = 1 / sqrt(hy * hy + hz * hz)
		P.lverts = { -hx, -hy, -hz, hx, -hy, -hz, -hx, -hy, hz, hx, -hy, hz, -hx, hy, hz, hx, hy, hz }
		P.volume = 4 * hx * hy * hz
		P.area = 4 * hx * hz + 4 * hx * hy + 4 * hx * sqrt(hy * hy + hz * hz) + 4 * hy * hz
		P.lcx, P.lcy, P.lcz = 0, -hy / 3, hz / 3
	elseif code == CORNER then
		P.k1 = 1 / sqrt(hx * hx + hy * hy)
		P.k2 = 1 / sqrt(hy * hy + hz * hz)
		P.lverts = { -hx, -hy, -hz, hx, -hy, -hz, -hx, -hy, hz, hx, -hy, hz, hx, hy, -hz }
		P.volume = 8 * hx * hy * hz / 3
		P.area = 4 * hx * hz + 2 * hy * hz + 2 * hx * hy + 2 * hz * sqrt(hx * hx + hy * hy) + 2 * hx * sqrt(hy * hy + hz * hz)
		P.lcx, P.lcy, P.lcz = hx / 4, -hy / 2, -hz / 4
	elseif code == BLOCK then
		P.lverts = {
			-hx, -hy, -hz, hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz,
			-hx, -hy, hz, hx, -hy, hz, -hx, hy, hz, hx, hy, hz,
		}
		P.volume = 8 * hx * hy * hz
		P.area = 8 * (hx * hy + hy * hz + hx * hz)
		P.lcx, P.lcy, P.lcz = 0, 0, 0
	elseif code == CYL then
		P.r = min(hy, hz)
		P.volume = 2 * PI * P.r * P.r * hx
		P.area = 2 * PI * P.r * P.r + 4 * PI * P.r * hx
		P.lcx, P.lcy, P.lcz = 0, 0, 0
	else
		P.r = min(hx, hy, hz)
		P.volume = 4 * PI * P.r * P.r * P.r / 3
		P.area = 4 * PI * P.r * P.r
		P.lcx, P.lcy, P.lcz = 0, 0, 0
	end
	P.gx, P.gy, P.gz = Shapes.toWorld(P, P.lcx, P.lcy, P.lcz)
	-- world vertices + AABB
	if P.lverts then
		local wv = {}
		local mnx, mny, mnz, mxx, mxy, mxz = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		local lv = P.lverts
		for i = 1, #lv, 3 do
			local a, b, c = Shapes.toWorld(P, lv[i], lv[i + 1], lv[i + 2])
			table.insert(wv, a)
			table.insert(wv, b)
			table.insert(wv, c)
			mnx, mny, mnz = min(mnx, a), min(mny, b), min(mnz, c)
			mxx, mxy, mxz = max(mxx, a), max(mxy, b), max(mxz, c)
		end
		P.wverts = wv
		P.minx, P.miny, P.minz, P.maxx, P.maxy, P.maxz = mnx, mny, mnz, mxx, mxy, mxz
	elseif code == CYL then
		local r = P.r
		local ex = hx * abs(P.ux) + r * sqrt(max(0, 1 - P.ux * P.ux))
		local ey = hx * abs(P.uy) + r * sqrt(max(0, 1 - P.uy * P.uy))
		local ez = hx * abs(P.uz) + r * sqrt(max(0, 1 - P.uz * P.uz))
		P.minx, P.maxx = P.cx - ex, P.cx + ex
		P.miny, P.maxy = P.cy - ey, P.cy + ey
		P.minz, P.maxz = P.cz - ez, P.cz + ez
	else
		local r = P.r
		P.minx, P.maxx = P.cx - r, P.cx + r
		P.miny, P.maxy = P.cy - r, P.cy + r
		P.minz, P.maxz = P.cz - r, P.cz + r
	end
	return P
end

function Shapes.toWorld(P: any, lx: number, ly: number, lz: number): (number, number, number)
	return P.cx + lx * P.ux + ly * P.vx + lz * P.wx,
		P.cy + lx * P.uy + ly * P.vy + lz * P.wy,
		P.cz + lx * P.uz + ly * P.vz + lz * P.wz
end

function Shapes.toLocal(P: any, x: number, y: number, z: number): (number, number, number)
	local dx, dy, dz = x - P.cx, y - P.cy, z - P.cz
	return dx * P.ux + dy * P.uy + dz * P.uz, dx * P.vx + dy * P.vy + dz * P.vz, dx * P.wx + dy * P.wy + dz * P.wz
end

-- signed "distance": exact inside, lower bound outside (max of supporting planes); <= 0 means inside
function Shapes.sdLocal(P: any, lx: number, ly: number, lz: number): number
	local code = P.code
	if code == BALL then
		return sqrt(lx * lx + ly * ly + lz * lz) - P.r
	elseif code == CYL then
		return max(abs(lx) - P.hx, sqrt(ly * ly + lz * lz) - P.r)
	end
	local hx, hy, hz = P.hx, P.hy, P.hz
	local d = max(abs(lx) - hx, abs(ly) - hy, abs(lz) - hz)
	if code == WEDGE then
		return max(d, (ly * hz - lz * hy) * P.k1)
	elseif code == CORNER then
		return max(d, (ly * hx - lx * hy) * P.k1, (ly * hz + lz * hy) * P.k2)
	end
	return d
end

function Shapes.sd(P: any, x: number, y: number, z: number): number
	local dx, dy, dz = x - P.cx, y - P.cy, z - P.cz
	return Shapes.sdLocal(
		P,
		dx * P.ux + dy * P.uy + dz * P.uz,
		dx * P.vx + dy * P.vy + dz * P.vz,
		dx * P.wx + dy * P.wy + dz * P.wz
	)
end

function Shapes.aabbContains(P: any, x: number, y: number, z: number, m: number): boolean
	return x >= P.minx - m and x <= P.maxx + m and y >= P.miny - m and y <= P.maxy + m and z >= P.minz - m and z <= P.maxz + m
end

-- ---------------------------------------------------------------- line chord (world line o + t*u)
local function clipSlab(t0: number, t1: number, o: number, u: number, h: number): (boolean, number, number)
	if u == 0 then
		return (o >= -h and o <= h), t0, t1
	end
	local a = (-h - o) / u
	local b = (h - o) / u
	if a > b then
		a, b = b, a
	end
	if a > t0 then
		t0 = a
	end
	if b < t1 then
		t1 = b
	end
	return t0 <= t1, t0, t1
end

local function clipHalf(t0: number, t1: number, no: number, nu: number): (boolean, number, number)
	-- no + t*nu <= 0
	if nu == 0 then
		return no <= 0, t0, t1
	end
	local t = -no / nu
	if nu > 0 then
		if t < t1 then
			t1 = t
		end
	else
		if t > t0 then
			t0 = t
		end
	end
	return t0 <= t1, t0, t1
end

-- returns ok, t0, t1 (chord parameters along the line; u need not be unit for polyhedra, is unit for quadrics)
function Shapes.chord(P: any, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number): (boolean, number, number)
	local lox, loy, loz = Shapes.toLocal(P, ox, oy, oz)
	local lux = ux * P.ux + uy * P.uy + uz * P.uz
	local luy = ux * P.vx + uy * P.vy + uz * P.vz
	local luz = ux * P.wx + uy * P.wy + uz * P.wz
	local code = P.code
	local t0, t1 = -math.huge, math.huge
	local ok
	if code == BALL then
		local r = P.r
		local a = lux * lux + luy * luy + luz * luz
		local b = 2 * (lox * lux + loy * luy + loz * luz)
		local c = lox * lox + loy * loy + loz * loz - r * r
		local disc = b * b - 4 * a * c
		if disc < 0 then
			return false, 0, 0
		end
		local s = sqrt(disc)
		return true, (-b - s) / (2 * a), (-b + s) / (2 * a)
	elseif code == CYL then
		ok, t0, t1 = clipSlab(t0, t1, lox, lux, P.hx)
		if not ok then
			return false, 0, 0
		end
		local r = P.r
		local a = luy * luy + luz * luz
		local c = loy * loy + loz * loz - r * r
		if a <= 1e-18 then
			return c <= 0, t0, t1
		end
		local b = 2 * (loy * luy + loz * luz)
		local disc = b * b - 4 * a * c
		if disc < 0 then
			return false, 0, 0
		end
		local s = sqrt(disc)
		local q0, q1 = (-b - s) / (2 * a), (-b + s) / (2 * a)
		if q0 > t0 then
			t0 = q0
		end
		if q1 < t1 then
			t1 = q1
		end
		return t0 <= t1, t0, t1
	end
	local hx, hy, hz = P.hx, P.hy, P.hz
	ok, t0, t1 = clipSlab(t0, t1, lox, lux, hx)
	if not ok then
		return false, 0, 0
	end
	ok, t0, t1 = clipSlab(t0, t1, loy, luy, hy)
	if not ok then
		return false, 0, 0
	end
	ok, t0, t1 = clipSlab(t0, t1, loz, luz, hz)
	if not ok then
		return false, 0, 0
	end
	if code == WEDGE then
		ok, t0, t1 = clipHalf(t0, t1, loy * hz - loz * hy, luy * hz - luz * hy)
	elseif code == CORNER then
		ok, t0, t1 = clipHalf(t0, t1, loy * hx - lox * hy, luy * hx - lux * hy)
		if ok then
			ok, t0, t1 = clipHalf(t0, t1, loy * hz + loz * hy, luy * hz + luz * hy)
		end
	end
	if not ok then
		return false, 0, 0
	end
	return true, t0, t1
end

-- ---------------------------------------------------------------- support (GJK)
function Shapes.support(P: any, dx: number, dy: number, dz: number): (number, number, number)
	local lx = dx * P.ux + dy * P.uy + dz * P.uz
	local ly = dx * P.vx + dy * P.vy + dz * P.vz
	local lz = dx * P.wx + dy * P.wy + dz * P.wz
	local code = P.code
	local sx, sy, sz
	if code == BLOCK then
		sx = if lx >= 0 then P.hx else -P.hx
		sy = if ly >= 0 then P.hy else -P.hy
		sz = if lz >= 0 then P.hz else -P.hz
	elseif code == CYL then
		sx = if lx >= 0 then P.hx else -P.hx
		local m = sqrt(ly * ly + lz * lz)
		if m > 0 then
			sy, sz = ly * P.r / m, lz * P.r / m
		else
			sy, sz = 0, 0
		end
	elseif code == BALL then
		local m = sqrt(lx * lx + ly * ly + lz * lz)
		if m > 0 then
			sx, sy, sz = lx * P.r / m, ly * P.r / m, lz * P.r / m
		else
			sx, sy, sz = P.r, 0, 0
		end
	else
		local lv = P.lverts
		local best = -math.huge
		sx, sy, sz = 0, 0, 0
		for i = 1, #lv, 3 do
			local d = lx * lv[i] + ly * lv[i + 1] + lz * lv[i + 2]
			if d > best then
				best = d
				sx, sy, sz = lv[i], lv[i + 1], lv[i + 2]
			end
		end
	end
	return Shapes.toWorld(P, sx, sy, sz)
end

-- max distance from point g to the part (exact)
function Shapes.maxDist(P: any, gx: number, gy: number, gz: number): number
	local code = P.code
	if P.wverts then
		local wv = P.wverts
		local best = 0
		for i = 1, #wv, 3 do
			local dx, dy, dz = wv[i] - gx, wv[i + 1] - gy, wv[i + 2] - gz
			local d2 = dx * dx + dy * dy + dz * dz
			if d2 > best then
				best = d2
			end
		end
		return sqrt(best)
	elseif code == CYL then
		local best = 0
		for s = -1, 1, 2 do
			local ccx, ccy, ccz = P.cx + s * P.hx * P.ux, P.cy + s * P.hx * P.uy, P.cz + s * P.hx * P.uz
			local dx, dy, dz = ccx - gx, ccy - gy, ccz - gz
			local dd = dx * dx + dy * dy + dz * dz
			local a = dx * P.ux + dy * P.uy + dz * P.uz
			local perp = sqrt(max(0, dd - a * a))
			local d2 = dd + P.r * P.r + 2 * P.r * perp
			if d2 > best then
				best = d2
			end
		end
		return sqrt(best)
	else
		local dx, dy, dz = P.cx - gx, P.cy - gy, P.cz - gz
		return sqrt(dx * dx + dy * dy + dz * dz) + P.r
	end
end

-- ---------------------------------------------------------------- volume samples (stratified, local frame)
-- returns flat world arrays xs, ys, zs, and the per-sample weight (analytic volume / count)
function Shapes.volumeSamples(P: any, H: number, NMIN: number, NMAX: number, NPART: number): ({ number }, { number }, { number }, number)
	local sx, sy, sz = 2 * P.hx, 2 * P.hy, 2 * P.hz
	local nx, ny, nz
	local k = 1
	while true do
		nx = max(NMIN, min(NMAX, ceil(sx / (k * H))))
		ny = max(NMIN, min(NMAX, ceil(sy / (k * H))))
		nz = max(NMIN, min(NMAX, ceil(sz / (k * H))))
		if nx * ny * nz <= NPART or (nx == NMIN and ny == NMIN and nz == NMIN) then
			break
		end
		k += 1
	end
	local xs, ys, zs = {}, {}, {}
	local n = 0
	local dx, dy, dz = sx / nx, sy / ny, sz / nz
	for i = 0, nx - 1 do
		local lx = -P.hx + (i + 0.5) * dx
		for j = 0, ny - 1 do
			local ly = -P.hy + (j + 0.5) * dy
			for kk = 0, nz - 1 do
				local lz = -P.hz + (kk + 0.5) * dz
				if Shapes.sdLocal(P, lx, ly, lz) < -1e-9 then -- strictly inside: boundary points are fragile after the frame round trip
					n += 1
					local a, b, c = Shapes.toWorld(P, lx, ly, lz)
					xs[n], ys[n], zs[n] = a, b, c
				end
			end
		end
	end
	return xs, ys, zs, P.volume / n
end

-- ---------------------------------------------------------------- surface samples
-- appends world points, weights and world outward normals; each face sampled on its own stratified grid
local function setN(P, out, n, lnx, lny, lnz)
	out.nx[n] = lnx * P.ux + lny * P.vx + lnz * P.wx
	out.ny[n] = lnx * P.uy + lny * P.vy + lnz * P.wy
	out.nz[n] = lnx * P.uz + lny * P.vz + lnz * P.wz
end

-- outward unit normal of the face spanned by (a, b) at origin o: orient away from the local centroid (convex)
local function faceNormal(P, ox, oy, oz, ax, ay, az, bx, by, bz)
	local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	local l = sqrt(cx * cx + cy * cy + cz * cz)
	cx, cy, cz = cx / l, cy / l, cz / l
	if (ox - P.lcx) * cx + (oy - P.lcy) * cy + (oz - P.lcz) * cz < 0 then
		cx, cy, cz = -cx, -cy, -cz
	end
	return cx, cy, cz
end

local function addRect(P, out, ox, oy, oz, ax, ay, az, bx, by, bz, H, NMAX)
	local la = sqrt(ax * ax + ay * ay + az * az)
	local lb = sqrt(bx * bx + by * by + bz * bz)
	local na = max(1, min(NMAX, ceil(la / H)))
	local nb = max(1, min(NMAX, ceil(lb / H)))
	local w = la * lb / (na * nb)
	local fx, fy, fz = faceNormal(P, ox, oy, oz, ax, ay, az, bx, by, bz)
	for i = 0, na - 1 do
		local s = (i + 0.5) / na
		for j = 0, nb - 1 do
			local t = (j + 0.5) / nb
			local a, b, c = Shapes.toWorld(P, ox + s * ax + t * bx, oy + s * ay + t * by, oz + s * az + t * bz)
			local n = out.n + 1
			out.n = n
			out.x[n], out.y[n], out.z[n], out.w[n] = a, b, c, w
			setN(P, out, n, fx, fy, fz)
		end
	end
end

local function addTri(P, out, ox, oy, oz, ax, ay, az, bx, by, bz, H, NMAX)
	local la = sqrt(ax * ax + ay * ay + az * az)
	local lb = sqrt(bx * bx + by * by + bz * bz)
	local na = max(1, min(NMAX, ceil(la / H)))
	local nb = max(1, min(NMAX, ceil(lb / H)))
	-- triangle area = |a x b| / 2
	local cxp, cyp, czp = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	local area = sqrt(cxp * cxp + cyp * cyp + czp * czp) / 2
	local fx, fy, fz = faceNormal(P, ox, oy, oz, ax, ay, az, bx, by, bz)
	local first = out.n + 1
	for i = 0, na - 1 do
		local s = (i + 0.5) / na
		for j = 0, nb - 1 do
			local t = (j + 0.5) / nb
			if s + t <= 1 then
				local a, b, c = Shapes.toWorld(P, ox + s * ax + t * bx, oy + s * ay + t * by, oz + s * az + t * bz)
				local n = out.n + 1
				out.n = n
				out.x[n], out.y[n], out.z[n] = a, b, c
			end
		end
	end
	local cnt = out.n - first + 1
	if cnt == 0 then -- degenerate tiny triangle: one sample at centroid
		local a, b, c = Shapes.toWorld(P, ox + (ax + bx) / 3, oy + (ay + by) / 3, oz + (az + bz) / 3)
		local n = out.n + 1
		out.n = n
		out.x[n], out.y[n], out.z[n] = a, b, c
		cnt = 1
	end
	for i = first, out.n do
		out.w[i] = area / cnt
		setN(P, out, i, fx, fy, fz)
	end
end

function Shapes.surfaceSamples(P: any, H: number, NMAX: number): any
	local out = { n = 0, x = {}, y = {}, z = {}, w = {}, nx = {}, ny = {}, nz = {} }
	local hx, hy, hz = P.hx, P.hy, P.hz
	local code = P.code
	if code == BLOCK then
		addRect(P, out, hx, -hy, -hz, 0, 2 * hy, 0, 0, 0, 2 * hz, H, NMAX)
		addRect(P, out, -hx, -hy, -hz, 0, 2 * hy, 0, 0, 0, 2 * hz, H, NMAX)
		addRect(P, out, -hx, hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, H, NMAX)
		addRect(P, out, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, H, NMAX)
		addRect(P, out, -hx, -hy, hz, 2 * hx, 0, 0, 0, 2 * hy, 0, H, NMAX)
		addRect(P, out, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 2 * hy, 0, H, NMAX)
	elseif code == WEDGE then
		addRect(P, out, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, H, NMAX) -- bottom
		addRect(P, out, -hx, -hy, hz, 2 * hx, 0, 0, 0, 2 * hy, 0, H, NMAX) -- back
		addRect(P, out, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 2 * hy, 2 * hz, H, NMAX) -- slope
		addTri(P, out, hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, H, NMAX) -- +X side
		addTri(P, out, -hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, H, NMAX) -- -X side
	elseif code == CORNER then
		addRect(P, out, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, H, NMAX) -- bottom
		addTri(P, out, hx, -hy, -hz, 0, 0, 2 * hz, 0, 2 * hy, 0, H, NMAX) -- right x=+hx
		addTri(P, out, hx, -hy, -hz, -2 * hx, 0, 0, 0, 2 * hy, 0, H, NMAX) -- front z=-hz
		addTri(P, out, -hx, -hy, -hz, 0, 0, 2 * hz, 2 * hx, 2 * hy, 0, H, NMAX) -- slope y/hy=x/hx
		addTri(P, out, -hx, -hy, hz, 2 * hx, 0, 0, 2 * hx, 2 * hy, -2 * hz, H, NMAX) -- slope y/hy=-z/hz
	elseif code == CYL then
		local r = P.r
		-- caps
		local nc = max(2, min(NMAX, ceil(2 * r / H)))
		for s = -1, 1, 2 do
			local first = out.n + 1
			for i = 0, nc - 1 do
				local ly = -r + (i + 0.5) * (2 * r / nc)
				for j = 0, nc - 1 do
					local lz = -r + (j + 0.5) * (2 * r / nc)
					if ly * ly + lz * lz <= r * r then
						local a, b, c = Shapes.toWorld(P, s * hx, ly, lz)
						local n = out.n + 1
						out.n = n
						out.x[n], out.y[n], out.z[n] = a, b, c
						setN(P, out, n, s, 0, 0)
					end
				end
			end
			local cnt = out.n - first + 1
			for i = first, out.n do
				out.w[i] = PI * r * r / cnt
			end
		end
		-- lateral
		local circ = 2 * PI * r
		local nth = if circ / H <= 8 then 8 elseif circ / H <= 16 then 16 else 32
		local stride = 32 // nth
		local nax = max(1, min(NMAX, ceil(2 * hx / H)))
		local w = circ * 2 * hx / (nth * nax)
		for i = 0, nax - 1 do
			local lx = -hx + (i + 0.5) * (2 * hx / nax)
			for k = 1, 32, stride do
				local a, b, c = Shapes.toWorld(P, lx, r * Num.COS[k], r * Num.SIN[k])
				local n = out.n + 1
				out.n = n
				out.x[n], out.y[n], out.z[n], out.w[n] = a, b, c, w
				setN(P, out, n, 0, Num.COS[k], Num.SIN[k])
			end
		end
	else
		-- ball: cube-sphere projection with Jacobian weights, normalized to 4*pi*r^2
		local r = P.r
		local nf = max(2, min(NMAX, ceil((PI * r / 2) / H)))
		local first = out.n + 1
		local tot = 0
		for face = 1, 6 do
			for i = 0, nf - 1 do
				local a = -1 + (i + 0.5) * (2 / nf)
				for j = 0, nf - 1 do
					local b = -1 + (j + 0.5) * (2 / nf)
					local px, py, pz
					if face == 1 then
						px, py, pz = 1, a, b
					elseif face == 2 then
						px, py, pz = -1, a, b
					elseif face == 3 then
						px, py, pz = a, 1, b
					elseif face == 4 then
						px, py, pz = a, -1, b
					elseif face == 5 then
						px, py, pz = a, b, 1
					else
						px, py, pz = a, b, -1
					end
					local s2 = 1 + a * a + b * b
					local inv = 1 / sqrt(s2)
					local wt = inv / s2 -- (1+a^2+b^2)^(-3/2)
					local wx, wy, wz = Shapes.toWorld(P, r * px * inv, r * py * inv, r * pz * inv)
					local n = out.n + 1
					out.n = n
					out.x[n], out.y[n], out.z[n], out.w[n] = wx, wy, wz, wt
					setN(P, out, n, px * inv, py * inv, pz * inv)
					tot += wt
				end
			end
		end
		local scale = 4 * PI * r * r / tot
		for i = first, out.n do
			out.w[i] *= scale
		end
	end
	return out
end

return Shapes
