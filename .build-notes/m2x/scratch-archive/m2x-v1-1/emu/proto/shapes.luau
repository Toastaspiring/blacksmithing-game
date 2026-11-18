--!strict
-- S2 prototype v2: primitive shapes exactly as Roblox renders them (verified in Studio, appendix E-S2.1).
-- Input = S1 PartData {id, slot, shape, material, pos {x,y,z}, rot {qx,qy,qz,qw}, size {x,y,z}}.
-- Local frame: half extents hx, hy, hz.
--   Block       |x|<=hx, |y|<=hy, |z|<=hz
--   Wedge       Block AND z/hz >= y/hy           (full bottom -Y and back +Z faces; slope faces -Z/+Y)
--   CornerWedge Block AND y/hy <= x/hx AND y/hy <= -z/hz   (pyramid, apex (+hx,+hy,-hz))
--   Cylinder    axis local X, length 2hx, radius r = hy = hz (canonical)
--   Ball        radius r = hx = hy = hz (canonical)
local Num = require("./num")
local Quat = require("./quat")

local sqrt, abs, max, min, ceil = math.sqrt, math.abs, math.max, math.min, math.ceil
local PI = Num.PI

local Shapes = {}

local BLOCK, WEDGE, CORNER, CYL, BALL = 1, 2, 3, 4, 5
Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYL, Shapes.BALL = BLOCK, WEDGE, CORNER, CYL, BALL
Shapes.CODE = { Block = BLOCK, Wedge = WEDGE, CornerWedge = CORNER, Cylinder = CYL, Ball = BALL }
Shapes.NAME = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }

-- ---------------------------------------------------------------- S1 Canonical hook (RULINGS 2.5)
-- Ball: all three sizes = min; Cylinder: sy = sz = min(sy, sz) (Roblox draws exactly this). Idempotent;
-- a no-op for editor data (the editor enforces these at edit time). Bounds are checked (rejected) by S1.
function Shapes.canonicalSize(shape: string, size: { number }): { number }
	local sx, sy, sz = size[1], size[2], size[3]
	if shape == "Ball" then
		local d = min(sx, sy, sz)
		return { d, d, d }
	elseif shape == "Cylinder" then
		local d = min(sy, sz)
		return { sx, d, d }
	end
	return { sx, sy, sz }
end

-- ---------------------------------------------------------------- prepare
local BLOCK_V = { -1, -1, -1, 1, -1, -1, -1, 1, -1, 1, 1, -1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 1 }
local BLOCK_F = { { 0, 2, 6, 4 }, { 1, 3, 7, 5 }, { 0, 1, 5, 4 }, { 2, 3, 7, 6 }, { 0, 1, 3, 2 }, { 4, 5, 7, 6 } }
local WEDGE_V = { -1, -1, -1, 1, -1, -1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 1 }
local WEDGE_F = { { 0, 1, 3, 2 }, { 2, 3, 5, 4 }, { 0, 1, 5, 4 }, { 0, 2, 4 }, { 1, 3, 5 } }
local CORNER_V = { -1, -1, -1, 1, -1, -1, -1, -1, 1, 1, -1, 1, 1, 1, -1 }
local CORNER_F = { { 0, 1, 3, 2 }, { 1, 3, 4 }, { 0, 1, 4 }, { 0, 2, 4 }, { 2, 3, 4 } }

function Shapes.prepare(part: any, index: number): any
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = Quat.toMatrix(part.rot)
	local P: any = {
		index = index,
		id = part.id,
		label = part.label,
		code = Shapes.CODE[part.shape],
		shape = part.shape,
		slot = part.slot,
		material = part.material,
		cx = part.pos[1],
		cy = part.pos[2],
		cz = part.pos[3],
		-- columns of R = world directions of the local axes
		ux = r00, uy = r10, uz = r20,
		vx = r01, vy = r11, vz = r21,
		wx = r02, wy = r12, wz = r22,
		hx = part.size[1] / 2,
		hy = part.size[2] / 2,
		hz = part.size[3] / 2,
	}
	assert(P.code, "unknown shape")
	local hx, hy, hz = P.hx, P.hy, P.hz
	local code = P.code
	P.r = 0
	P.k1, P.k2 = 0, 0
	local lv, lf
	if code == WEDGE then
		P.k1 = 1 / sqrt(hy * hy + hz * hz)
		lv, lf = WEDGE_V, WEDGE_F
		P.volume = 4 * hx * hy * hz
		P.area = 4 * hx * hz + 4 * hx * hy + 4 * hx * sqrt(hy * hy + hz * hz) + 4 * hy * hz
		P.lcx, P.lcy, P.lcz = 0, -hy / 3, hz / 3
	elseif code == CORNER then
		P.k1 = 1 / sqrt(hx * hx + hy * hy)
		P.k2 = 1 / sqrt(hy * hy + hz * hz)
		lv, lf = CORNER_V, CORNER_F
		P.volume = 8 * hx * hy * hz / 3
		P.area = 4 * hx * hz + 2 * hy * hz + 2 * hx * hy + 2 * hz * sqrt(hx * hx + hy * hy) + 2 * hx * sqrt(hy * hy + hz * hz)
		P.lcx, P.lcy, P.lcz = hx / 4, -hy / 2, -hz / 4
	elseif code == BLOCK then
		lv, lf = BLOCK_V, BLOCK_F
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
	P.poly = lv ~= nil
	P.gx, P.gy, P.gz = Shapes.toWorld(P, P.lcx, P.lcy, P.lcz)
	if lv then
		local wv = {}
		local mnx, mny, mnz, mxx, mxy, mxz = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		local llv = {}
		for i = 1, #lv, 3 do
			local a, b, c = lv[i] * hx, lv[i + 1] * hy, lv[i + 2] * hz
			table.insert(llv, a)
			table.insert(llv, b)
			table.insert(llv, c)
			local x, y, z = Shapes.toWorld(P, a, b, c)
			table.insert(wv, x)
			table.insert(wv, y)
			table.insert(wv, z)
			mnx, mny, mnz = min(mnx, x), min(mny, y), min(mnz, z)
			mxx, mxy, mxz = max(mxx, x), max(mxy, y), max(mxz, z)
		end
		P.lverts, P.wverts, P.faceIdx = llv, wv, lf
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

-- Physics/Shapes.aabb(part) (replaces S6's Geometry.partExtents)
function Shapes.aabb(P: any): ({ number }, { number })
	return { P.minx, P.miny, P.minz }, { P.maxx, P.maxy, P.maxz }
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

function Shapes.aabbOverlap(A: any, B: any, m: number): boolean
	return A.minx <= B.maxx + m and B.minx <= A.maxx + m and A.miny <= B.maxy + m and B.miny <= A.maxy + m
		and A.minz <= B.maxz + m and B.minz <= A.maxz + m
end

-- ---------------------------------------------------------------- line chord (world line o + t*u), optional dilation rt
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
	-- keeps no + t*nu <= 0
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

-- returns ok, t0, t1; rt >= 0 dilates every supporting plane (and quadric radius / cylinder half-length) by rt
function Shapes.chord(P: any, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number, rt: number?): (boolean, number, number)
	local d = rt or 0
	local lox, loy, loz = Shapes.toLocal(P, ox, oy, oz)
	local lux = ux * P.ux + uy * P.uy + uz * P.uz
	local luy = ux * P.vx + uy * P.vy + uz * P.vz
	local luz = ux * P.wx + uy * P.wy + uz * P.wz
	local code = P.code
	local t0, t1 = -math.huge, math.huge
	local ok
	if code == BALL then
		local r = P.r + d
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
		ok, t0, t1 = clipSlab(t0, t1, lox, lux, P.hx + d)
		if not ok then
			return false, 0, 0
		end
		local r = P.r + d
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
	ok, t0, t1 = clipSlab(t0, t1, lox, lux, hx + d)
	if not ok then
		return false, 0, 0
	end
	ok, t0, t1 = clipSlab(t0, t1, loy, luy, hy + d)
	if not ok then
		return false, 0, 0
	end
	ok, t0, t1 = clipSlab(t0, t1, loz, luz, hz + d)
	if not ok then
		return false, 0, 0
	end
	if code == WEDGE then
		ok, t0, t1 = clipHalf(t0, t1, loy * hz - loz * hy - d / P.k1, luy * hz - luz * hy)
	elseif code == CORNER then
		ok, t0, t1 = clipHalf(t0, t1, loy * hx - lox * hy - d / P.k1, luy * hx - lux * hy)
		if ok then
			ok, t0, t1 = clipHalf(t0, t1, loy * hz + loz * hy - d / P.k2, luy * hz + luz * hy)
		end
	end
	if not ok then
		return false, 0, 0
	end
	return true, t0, t1
end

-- ---------------------------------------------------------------- support (GJK, extents)
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

-- extent of the part along unit direction a: (lo, hi) = (a.sup(-a), a.sup(a))
function Shapes.extentAlong(P: any, ax: number, ay: number, az: number): (number, number)
	local hx, hy, hz = Shapes.support(P, ax, ay, az)
	local lx, ly, lz = Shapes.support(P, -ax, -ay, -az)
	return lx * ax + ly * ay + lz * az, hx * ax + hy * ay + hz * az
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

-- ---------------------------------------------------------------- polyhedra: world planes (n.x <= d) and faces
function Shapes.planes(P: any): { { number } }
	local out = {}
	local function add(a: number, b: number, c: number, e: number)
		local nx = a * P.ux + b * P.vx + c * P.wx
		local ny = a * P.uy + b * P.vy + c * P.wy
		local nz = a * P.uz + b * P.vz + c * P.wz
		local l = sqrt(nx * nx + ny * ny + nz * nz)
		nx, ny, nz, e = nx / l, ny / l, nz / l, e / l
		table.insert(out, { nx, ny, nz, e + nx * P.cx + ny * P.cy + nz * P.cz })
	end
	local hx, hy, hz = P.hx, P.hy, P.hz
	add(1, 0, 0, hx)
	add(-1, 0, 0, hx)
	add(0, 1, 0, hy)
	add(0, -1, 0, hy)
	add(0, 0, 1, hz)
	add(0, 0, -1, hz)
	if P.code == WEDGE then
		add(0, hz, -hy, 0)
	elseif P.code == CORNER then
		add(-hy, hx, 0, 0)
		add(0, hz, hy, 0)
	end
	return out
end

-- world face polygons, each a flat {x1,y1,z1, x2,...}, oriented CCW seen from outside
function Shapes.faces(P: any): { { number } }
	local out = {}
	local wv = P.wverts
	for _, f in ipairs(P.faceIdx) do
		local poly = {}
		local fx, fy, fz = 0, 0, 0
		for _, k in ipairs(f) do
			local x, y, z = wv[3 * k + 1], wv[3 * k + 2], wv[3 * k + 3]
			table.insert(poly, x)
			table.insert(poly, y)
			table.insert(poly, z)
			fx, fy, fz = fx + x, fy + y, fz + z
		end
		local n = #f
		fx, fy, fz = fx / n, fy / n, fz / n
		-- Newell normal
		local nx, ny, nz = 0, 0, 0
		for i = 0, n - 1 do
			local j = (i + 1) % n
			local ax, ay, az = poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3]
			local bx, by, bz = poly[3 * j + 1], poly[3 * j + 2], poly[3 * j + 3]
			nx += (ay - by) * (az + bz)
			ny += (az - bz) * (ax + bx)
			nz += (ax - bx) * (ay + by)
		end
		if nx * (fx - P.gx) + ny * (fy - P.gy) + nz * (fz - P.gz) < 0 then
			local rev = {}
			for i = n - 1, 0, -1 do
				table.insert(rev, poly[3 * i + 1])
				table.insert(rev, poly[3 * i + 2])
				table.insert(rev, poly[3 * i + 3])
			end
			poly = rev
		end
		table.insert(out, poly)
	end
	return out
end

-- ---------------------------------------------------------------- volume samples (stratified, local frame)
-- Loops: i (local X) outermost, then j (Y), then k (Z); cell centre l_k = -h_k + (i + 1/2) * 2h_k / n_k.
-- n_k = clamp(ceil(size_k / H), NMIN, NMAX); if n_x n_y n_z > NPART, H is multiplied by 2, 3, ... until it fits.
-- Kept iff strictly inside (sd < -INSIDE_MARGIN). Returns world xs, ys, zs and the uniform weight V / count.
function Shapes.volumeSamples(P: any, H: number, NMIN: number, NMAX: number, NPART: number, NMINX: number?, NMINY: number?, NMINZ: number?, tick: ((number) -> ())?): ({ number }, { number }, { number }, number)
	local sx, sy, sz = 2 * P.hx, 2 * P.hy, 2 * P.hz
	local mx, my, mz = NMINX or NMIN, NMINY or NMIN, NMINZ or NMIN
	local nx, ny, nz
	local k = 1
	while true do
		nx = max(mx, min(NMAX, ceil(sx / (k * H))))
		ny = max(my, min(NMAX, ceil(sy / (k * H))))
		nz = max(mz, min(NMAX, ceil(sz / (k * H))))
		if nx * ny * nz <= NPART or (nx == mx and ny == my and nz == mz) then
			break
		end
		k += 1
	end
	local xs, ys, zs = {}, {}, {}
	local n = 0
	local dx, dy, dz = sx / nx, sy / ny, sz / nz
	for i = 0, nx - 1 do
		local lx = -P.hx + (i + 0.5) * dx
		if tick then
			tick(ny * nz)
		end
		for j = 0, ny - 1 do
			local ly = -P.hy + (j + 0.5) * dy
			for kk = 0, nz - 1 do
				local lz = -P.hz + (kk + 0.5) * dz
				if Shapes.sdLocal(P, lx, ly, lz) < -1e-9 then
					n += 1
					local a, b, c = Shapes.toWorld(P, lx, ly, lz)
					xs[n], ys[n], zs[n] = a, b, c
				end
			end
		end
	end
	if n == 0 then
		-- degenerate (cannot happen above MIN_DIM): one sample at the centroid
		n = 1
		xs[1], ys[1], zs[1] = P.gx, P.gy, P.gz
	end
	return xs, ys, zs, P.volume / n
end

-- ---------------------------------------------------------------- surface samples
local function setN(P, out, n, lnx, lny, lnz)
	out.nx[n] = lnx * P.ux + lny * P.vx + lnz * P.wx
	out.ny[n] = lnx * P.uy + lny * P.vy + lnz * P.wy
	out.nz[n] = lnx * P.uz + lny * P.vz + lnz * P.wz
end

-- patch half-vectors of sample n (local -> world rotation only) and whether the face is planar
local function setE(P, out, n, ax, ay, az, bx, by, bz, flat)
	out.e1x[n] = ax * P.ux + ay * P.vx + az * P.wx
	out.e1y[n] = ax * P.uy + ay * P.vy + az * P.wy
	out.e1z[n] = ax * P.uz + ay * P.vz + az * P.wz
	out.e2x[n] = bx * P.ux + by * P.vx + bz * P.wx
	out.e2y[n] = bx * P.uy + by * P.vy + bz * P.wy
	out.e2z[n] = bx * P.uz + by * P.vz + bz * P.wz
	out.flat[n] = flat
end

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
		if out.tick then
			out.tick(nb)
		end
		for j = 0, nb - 1 do
			local t = (j + 0.5) / nb
			local a, b, c = Shapes.toWorld(P, ox + s * ax + t * bx, oy + s * ay + t * by, oz + s * az + t * bz)
			local n = out.n + 1
			out.n = n
			out.x[n], out.y[n], out.z[n], out.w[n] = a, b, c, w
			setN(P, out, n, fx, fy, fz)
			setE(P, out, n, ax / (2 * na), ay / (2 * na), az / (2 * na), bx / (2 * nb), by / (2 * nb), bz / (2 * nb), true)
		end
	end
end

local function addTri(P, out, ox, oy, oz, ax, ay, az, bx, by, bz, H, NMAX)
	local la = sqrt(ax * ax + ay * ay + az * az)
	local lb = sqrt(bx * bx + by * by + bz * bz)
	local na = max(1, min(NMAX, ceil(la / H)))
	local nb = max(1, min(NMAX, ceil(lb / H)))
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
	if cnt == 0 then
		local a, b, c = Shapes.toWorld(P, ox + (ax + bx) / 3, oy + (ay + by) / 3, oz + (az + bz) / 3)
		local n = out.n + 1
		out.n = n
		out.x[n], out.y[n], out.z[n] = a, b, c
		cnt = 1
	end
	for i = first, out.n do
		out.w[i] = area / cnt
		setN(P, out, i, fx, fy, fz)
		setE(P, out, i, ax / (2 * na), ay / (2 * na), az / (2 * na), bx / (2 * nb), by / (2 * nb), bz / (2 * nb), true)
	end
end

-- estimated sample count at spacing H (for the budget ladder)
function Shapes.surfaceEstimate(P: any, H: number, NMAX: number): number
	local a = max(1, min(NMAX, ceil(2 * P.hx / H)))
	local b = max(1, min(NMAX, ceil(2 * P.hy / H)))
	local c = max(1, min(NMAX, ceil(2 * P.hz / H)))
	return 2 * (a * b + b * c + a * c)
end

function Shapes.surfaceSamples(P: any, H: number, NMAX: number, tick: ((number) -> ())?): any
	local out = { tick = tick, n = 0, x = {}, y = {}, z = {}, w = {}, nx = {}, ny = {}, nz = {}, e1x = {}, e1y = {}, e1z = {}, e2x = {}, e2y = {}, e2z = {}, flat = {} }
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
						setE(P, out, n, 0, r / nc, 0, 0, 0, r / nc, true)
					end
				end
			end
			local cnt = out.n - first + 1
			for i = first, out.n do
				out.w[i] = PI * r * r / cnt
			end
		end
		-- lateral: nth = 8 / 16 / 32 directions when circumference / H <= 8 / <= 16 / above
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
				local ht = circ / (2 * nth)
				setE(P, out, n, hx / nax, 0, 0, 0, -ht * Num.SIN[k], ht * Num.COS[k], false)
			end
		end
	else
		-- ball: cube-sphere projection, nf = clamp(ceil((pi r / 2) / H), 2, NMAX) per cube-face axis,
		-- Jacobian weights (1+a^2+b^2)^(-3/2) normalized to 4 pi r^2
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
					local wt = inv / s2
					local wx, wy, wz = Shapes.toWorld(P, r * px * inv, r * py * inv, r * pz * inv)
					local n = out.n + 1
					out.n = n
					out.x[n], out.y[n], out.z[n], out.w[n] = wx, wy, wz, wt
					setN(P, out, n, px * inv, py * inv, pz * inv)
					setE(P, out, n, 0, 0, 0, 0, 0, 0, false)
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
