--!nocheck
-- V1's truth about a part's visible share, written from SPEC §3.2, §4.3 and §4.4 alone: nothing from Physics/Shapes, Sampling or VisibleOracle.
-- The hide test per point is §4.4's: buried (sd < -eps), on q's surface with q lower (|sd| <= eps), probe inside (sd(s + delta n) <= eps); against all parts but exact
-- copies of a lower index and Dust. Instead of a lattice it splits each face adaptively: sd is convex, so a flat cell whose corners are all hidden by one q is wholly hidden;
-- a half-space term of q that clears all corners, or sd - rho, proves q cannot hide the cell (1-Lipschitz). What neither settles is split down to minCell, where the centre
-- decides and the cell's area counts as uncertain. shares come with a rigorous [lo, hi] for flat faces.
local T = {}

local sqrt, abs, max, min, cos, sin, atan = math.sqrt, math.abs, math.max, math.min, math.cos, math.sin, math.atan
local PI = 3.141592653589793
local EPS = 1e-7
local DELTA = 0.012
local MIN_VOL = 0.0002

T.MIN_CELL = 0.0005

local function rotation(q)
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local s = 2 / (x * x + y * y + z * z + w * w)
	return 1 - s * (y * y + z * z), s * (x * y + z * w), s * (x * z - y * w), -- column u
		s * (x * y - z * w), 1 - s * (x * x + z * z), s * (y * z + x * w), -- column v
		s * (x * z + y * w), s * (y * z - x * w), 1 - s * (x * x + y * y) -- column w
end

function T.solid(part, index)
	local o = { index = index, shape = part.shape, part = part }
	o.cx, o.cy, o.cz = part.pos[1], part.pos[2], part.pos[3]
	o.ux, o.uy, o.uz, o.vx, o.vy, o.vz, o.wx, o.wy, o.wz = rotation(part.rot)
	local hx, hy, hz = part.size[1] / 2, part.size[2] / 2, part.size[3] / 2
	o.hx, o.hy, o.hz = hx, hy, hz
	o.planes = {}
	local function plane(a, b, c, d) -- local a x + b y + c z <= d, unit (a, b, c)
		local nx, ny, nz = a * o.ux + b * o.vx + c * o.wx, a * o.uy + b * o.vy + c * o.wy, a * o.uz + b * o.vz + c * o.wz
		table.insert(o.planes, { nx, ny, nz, d + nx * o.cx + ny * o.cy + nz * o.cz })
	end
	local verts = nil
	if part.shape == "Block" or part.shape == "Wedge" or part.shape == "CornerWedge" then
		plane(1, 0, 0, hx)
		plane(-1, 0, 0, hx)
		plane(0, 1, 0, hy)
		plane(0, -1, 0, hy)
		plane(0, 0, 1, hz)
		plane(0, 0, -1, hz)
	end
	if part.shape == "Block" then
		o.vol = 8 * hx * hy * hz
		verts = {}
		for _, a in ipairs({ -1, 1 }) do
			for _, b in ipairs({ -1, 1 }) do
				for _, c in ipairs({ -1, 1 }) do
					table.insert(verts, { a * hx, b * hy, c * hz })
				end
			end
		end
	elseif part.shape == "Wedge" then
		o.vol = 4 * hx * hy * hz
		local l = sqrt(hy * hy + hz * hz)
		o.k1 = 1 / l
		plane(0, hz / l, -hy / l, 0)
		verts = { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { -hx, hy, hz }, { hx, hy, hz } }
	elseif part.shape == "CornerWedge" then
		o.vol = 8 * hx * hy * hz / 3
		local l1, l2 = sqrt(hx * hx + hy * hy), sqrt(hy * hy + hz * hz)
		o.k1, o.k2 = 1 / l1, 1 / l2
		plane(-hy / l1, hx / l1, 0, 0)
		plane(0, hz / l2, hy / l2, 0)
		verts = { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, -hz } }
	elseif part.shape == "Cylinder" then
		o.r = min(hy, hz)
		o.vol = 2 * PI * o.r * o.r * hx
		plane(1, 0, 0, hx)
		plane(-1, 0, 0, hx)
	else
		o.r = min(hx, hy, hz)
		o.vol = 4 * PI * o.r * o.r * o.r / 3
	end
	-- world AABB
	if verts then
		o.minx, o.miny, o.minz, o.maxx, o.maxy, o.maxz = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		for _, v in ipairs(verts) do
			local x = o.cx + v[1] * o.ux + v[2] * o.vx + v[3] * o.wx
			local y = o.cy + v[1] * o.uy + v[2] * o.vy + v[3] * o.wy
			local z = o.cz + v[1] * o.uz + v[2] * o.vz + v[3] * o.wz
			o.minx, o.miny, o.minz = min(o.minx, x), min(o.miny, y), min(o.minz, z)
			o.maxx, o.maxy, o.maxz = max(o.maxx, x), max(o.maxy, y), max(o.maxz, z)
		end
	elseif part.shape == "Cylinder" then
		local ex = hx * abs(o.ux) + o.r * sqrt(max(0, 1 - o.ux * o.ux))
		local ey = hx * abs(o.uy) + o.r * sqrt(max(0, 1 - o.uy * o.uy))
		local ez = hx * abs(o.uz) + o.r * sqrt(max(0, 1 - o.uz * o.uz))
		o.minx, o.maxx, o.miny, o.maxy, o.minz, o.maxz = o.cx - ex, o.cx + ex, o.cy - ey, o.cy + ey, o.cz - ez, o.cz + ez
	else
		o.minx, o.maxx, o.miny, o.maxy, o.minz, o.maxz = o.cx - o.r, o.cx + o.r, o.cy - o.r, o.cy + o.r, o.cz - o.r, o.cz + o.r
	end
	return o
end

-- §4.3's signed distance
local function sd(q, x, y, z)
	local dx, dy, dz = x - q.cx, y - q.cy, z - q.cz
	local lx = dx * q.ux + dy * q.uy + dz * q.uz
	local ly = dx * q.vx + dy * q.vy + dz * q.vz
	local lz = dx * q.wx + dy * q.wy + dz * q.wz
	local shape = q.shape
	if shape == "Ball" then
		return sqrt(lx * lx + ly * ly + lz * lz) - q.r
	elseif shape == "Cylinder" then
		return max(abs(lx) - q.hx, sqrt(ly * ly + lz * lz) - q.r)
	end
	local hx, hy, hz = q.hx, q.hy, q.hz
	local d = max(abs(lx) - hx, abs(ly) - hy, abs(lz) - hz)
	if shape == "Wedge" then
		return max(d, (ly * hz - lz * hy) * q.k1)
	elseif shape == "CornerWedge" then
		return max(d, (ly * hx - lx * hy) * q.k1, (ly * hz + lz * hy) * q.k2)
	end
	return d
end
T.sd = sd

local function sameSolid(a, b)
	if a.shape ~= b.shape then return false end
	return a.cx == b.cx and a.cy == b.cy and a.cz == b.cz and a.hx == b.hx and a.hy == b.hy and a.hz == b.hz and a.ux == b.ux and a.uy == b.uy and a.uz == b.uz
		and a.vx == b.vx and a.vy == b.vy and a.vz == b.vz and a.wx == b.wx and a.wy == b.wy and a.wz == b.wz
end

-- the hide test at one point
local function hiddenPoint(p, active, n, x, y, z, nx, ny, nz)
	local ox, oy, oz = x + DELTA * nx, y + DELTA * ny, z + DELTA * nz
	for c = 1, n do
		local q = active[c]
		local d0 = sd(q, x, y, z)
		if d0 < -EPS or (q.index < p.index and d0 <= EPS) then return true end
		if sd(q, ox, oy, oz) <= EPS then return true end
	end
	return false
end
T.hiddenPoint = hiddenPoint

-- A flat convex cell (corners flat x, y, z, 3 or 4): state { shown, uncertain, cells }. active: the parts that may still hide it.
local function flatCell(p, st, corners, m, area, active, nActive, nx, ny, nz, minCell)
	st.cells += 1
	local cx, cy, cz = 0, 0, 0
	for i = 0, m - 1 do
		cx, cy, cz = cx + corners[3 * i + 1], cy + corners[3 * i + 2], cz + corners[3 * i + 3]
	end
	cx, cy, cz = cx / m, cy / m, cz / m
	local rho2 = 0
	for i = 0, m - 1 do
		local dx, dy, dz = corners[3 * i + 1] - cx, corners[3 * i + 2] - cy, corners[3 * i + 3] - cz
		rho2 = max(rho2, dx * dx + dy * dy + dz * dz)
	end
	local rho = sqrt(rho2)
	local next, nNext = table.create(nActive), 0
	local pIndex = p.index
	for c = 1, nActive do
		local q = active[c]
		-- does q hide all of it?
		local allProbe, allBuried, allOn = true, true, true
		local lower = q.index < pIndex
		for i = 0, m - 1 do
			local x, y, z = corners[3 * i + 1], corners[3 * i + 2], corners[3 * i + 3]
			if allProbe and sd(q, x + DELTA * nx, y + DELTA * ny, z + DELTA * nz) > EPS then allProbe = false end
			if allBuried or allOn then
				local d0 = sd(q, x, y, z)
				if d0 >= -EPS then allBuried = false end
				if d0 > EPS then allOn = false end
			end
			if not allProbe and not allBuried and not (lower and allOn) then break end
		end
		if allProbe or allBuried or (lower and allOn) then
			return
		end
		-- can q hide any of it?
		local clearS, clearP = false, false
		local d0c, d1c = sd(q, cx, cy, cz), sd(q, cx + DELTA * nx, cy + DELTA * ny, cz + DELTA * nz)
		if lower then
			clearS = d0c - rho > EPS
		else
			clearS = d0c - rho >= -EPS
		end
		clearP = d1c - rho > EPS
		if not (clearS and clearP) then
			local pl = q.planes
			for k = 1, #pl do
				local plane = pl[k]
				local a, b, cc, d = plane[1], plane[2], plane[3], plane[4]
				local minS, minP = math.huge, math.huge
				for i = 0, m - 1 do
					local t = a * corners[3 * i + 1] + b * corners[3 * i + 2] + cc * corners[3 * i + 3] - d
					minS = min(minS, t)
					minP = min(minP, t + DELTA * (a * nx + b * ny + cc * nz))
				end
				if minP > EPS then clearP = true end
				if lower then
					if minS > EPS then clearS = true end
				else
					if minS >= -EPS then clearS = true end
				end
				if clearS and clearP then break end
			end
		end
		if not (clearS and clearP) then
			nNext += 1
			next[nNext] = q
		end
	end
	if nNext == 0 then
		st.shown += area
		return
	end
	if rho <= minCell * 0.7072 then
		st.uncertain += area
		st.midCells += 1
		if not hiddenPoint(p, next, nNext, cx, cy, cz, nx, ny, nz) then
			st.shown += area
		end
		return
	end
	-- split on the longest edge
	if m == 4 then
		-- corners in order o, o + a, o + a + b, o + b
		local ax, ay, az = corners[4] - corners[1], corners[5] - corners[2], corners[6] - corners[3]
		local bx, by, bz = corners[10] - corners[1], corners[11] - corners[2], corners[12] - corners[3]
		local la, lb = ax * ax + ay * ay + az * az, bx * bx + by * by + bz * bz
		if la >= lb then
			local m1x, m1y, m1z = (corners[1] + corners[4]) / 2, (corners[2] + corners[5]) / 2, (corners[3] + corners[6]) / 2
			local m2x, m2y, m2z = (corners[7] + corners[10]) / 2, (corners[8] + corners[11]) / 2, (corners[9] + corners[12]) / 2
			flatCell(p, st, { corners[1], corners[2], corners[3], m1x, m1y, m1z, m2x, m2y, m2z, corners[10], corners[11], corners[12] }, 4, area / 2, next, nNext, nx, ny, nz, minCell)
			flatCell(p, st, { m1x, m1y, m1z, corners[4], corners[5], corners[6], corners[7], corners[8], corners[9], m2x, m2y, m2z }, 4, area / 2, next, nNext, nx, ny, nz, minCell)
		else
			local m1x, m1y, m1z = (corners[4] + corners[7]) / 2, (corners[5] + corners[8]) / 2, (corners[6] + corners[9]) / 2
			local m2x, m2y, m2z = (corners[1] + corners[10]) / 2, (corners[2] + corners[11]) / 2, (corners[3] + corners[12]) / 2
			flatCell(p, st, { corners[1], corners[2], corners[3], corners[4], corners[5], corners[6], m1x, m1y, m1z, m2x, m2y, m2z }, 4, area / 2, next, nNext, nx, ny, nz, minCell)
			flatCell(p, st, { m2x, m2y, m2z, m1x, m1y, m1z, corners[7], corners[8], corners[9], corners[10], corners[11], corners[12] }, 4, area / 2, next, nNext, nx, ny, nz, minCell)
		end
	else
		-- a triangle, longest-edge bisection
		local a1, a2, a3 = corners[1], corners[2], corners[3]
		local b1, b2, b3 = corners[4], corners[5], corners[6]
		local c1, c2, c3 = corners[7], corners[8], corners[9]
		local ab = (a1 - b1) * (a1 - b1) + (a2 - b2) * (a2 - b2) + (a3 - b3) * (a3 - b3)
		local bc = (b1 - c1) * (b1 - c1) + (b2 - c2) * (b2 - c2) + (b3 - c3) * (b3 - c3)
		local ca = (c1 - a1) * (c1 - a1) + (c2 - a2) * (c2 - a2) + (c3 - a3) * (c3 - a3)
		if ab >= bc and ab >= ca then
			local mx, my, mz = (a1 + b1) / 2, (a2 + b2) / 2, (a3 + b3) / 2
			flatCell(p, st, { a1, a2, a3, mx, my, mz, c1, c2, c3 }, 3, area / 2, next, nNext, nx, ny, nz, minCell)
			flatCell(p, st, { mx, my, mz, b1, b2, b3, c1, c2, c3 }, 3, area / 2, next, nNext, nx, ny, nz, minCell)
		elseif bc >= ca then
			local mx, my, mz = (b1 + c1) / 2, (b2 + c2) / 2, (b3 + c3) / 2
			flatCell(p, st, { a1, a2, a3, b1, b2, b3, mx, my, mz }, 3, area / 2, next, nNext, nx, ny, nz, minCell)
			flatCell(p, st, { a1, a2, a3, mx, my, mz, c1, c2, c3 }, 3, area / 2, next, nNext, nx, ny, nz, minCell)
		else
			local mx, my, mz = (c1 + a1) / 2, (c2 + a2) / 2, (c3 + a3) / 2
			flatCell(p, st, { a1, a2, a3, b1, b2, b3, mx, my, mz }, 3, area / 2, next, nNext, nx, ny, nz, minCell)
			flatCell(p, st, { mx, my, mz, b1, b2, b3, c1, c2, c3 }, 3, area / 2, next, nNext, nx, ny, nz, minCell)
		end
	end
end

local function world(p, a, b, c)
	return p.cx + a * p.ux + b * p.vx + c * p.wx, p.cy + a * p.uy + b * p.vy + c * p.wy, p.cz + a * p.uz + b * p.vz + c * p.wz
end

-- A flat face from local vertices (3 or 4, in order); the outward normal from the solid's centroid side.
local function flatFace(p, st, lv, active, nActive, minCell, lc)
	local m = #lv
	local corners = table.create(3 * m)
	for i, v in ipairs(lv) do
		corners[3 * i - 2], corners[3 * i - 1], corners[3 * i] = world(p, v[1], v[2], v[3])
	end
	local ax, ay, az = corners[4] - corners[1], corners[5] - corners[2], corners[6] - corners[3]
	local bx, by, bz = corners[7] - corners[1], corners[8] - corners[2], corners[9] - corners[3]
	local nx, ny, nz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	local l = sqrt(nx * nx + ny * ny + nz * nz)
	nx, ny, nz = nx / l, ny / l, nz / l
	local gx, gy, gz = world(p, lc[1], lc[2], lc[3])
	if (corners[1] - gx) * nx + (corners[2] - gy) * ny + (corners[3] - gz) * nz < 0 then
		nx, ny, nz = -nx, -ny, -nz
	end
	local area = if m == 4 then l else l / 2
	st.area += area
	flatCell(p, st, corners, m, area, active, nActive, nx, ny, nz, minCell)
end

-- A curved cell, by the Lipschitz bound only: point(u, v) gives the surface point and unit normal, areaOf(u0, u1, v0, v1) the exact area.
local function curvedCell(p, st, point, areaOf, u0, u1, v0, v1, rhoOf, active, nActive, minCell)
	st.cells += 1
	local um, vm = (u0 + u1) / 2, (v0 + v1) / 2
	local x, y, z, nx, ny, nz = point(um, vm)
	local rho, rhoP, du, dv = rhoOf(u0, u1, v0, v1, minCell)
	local ox, oy, oz = x + DELTA * nx, y + DELTA * ny, z + DELTA * nz
	local next, nNext = table.create(nActive), 0
	local pIndex = p.index
	for c = 1, nActive do
		local q = active[c]
		local d0, d1 = sd(q, x, y, z), sd(q, ox, oy, oz)
		local lower = q.index < pIndex
		if d1 + rhoP <= EPS or d0 + rho < -EPS or (lower and d0 + rho <= EPS) then
			return
		end
		local clearS = if lower then d0 - rho > EPS else d0 - rho >= -EPS
		local clearP = d1 - rhoP > EPS
		if not (clearS and clearP) then
			nNext += 1
			next[nNext] = q
		end
	end
	local area = areaOf(u0, u1, v0, v1)
	if nNext == 0 then
		st.shown += area
		return
	end
	if du <= 1 and dv <= 1 then
		st.uncertain += area
		st.midCells += 1
		if not hiddenPoint(p, next, nNext, x, y, z, nx, ny, nz) then
			st.shown += area
		end
		return
	end
	if du >= dv then
		curvedCell(p, st, point, areaOf, u0, um, v0, v1, rhoOf, next, nNext, minCell)
		curvedCell(p, st, point, areaOf, um, u1, v0, v1, rhoOf, next, nNext, minCell)
	else
		curvedCell(p, st, point, areaOf, u0, u1, v0, vm, rhoOf, next, nNext, minCell)
		curvedCell(p, st, point, areaOf, u0, u1, vm, v1, rhoOf, next, nNext, minCell)
	end
end

function T.hidersOf(solids, parts)
	local N = #solids
	local hider, isCopy, isDust = table.create(N), table.create(N), table.create(N)
	for i = 1, N do
		isDust[i] = solids[i].vol < MIN_VOL
		isCopy[i] = false
		for j = 1, i - 1 do
			if sameSolid(solids[i], solids[j]) then
				isCopy[i] = true
				break
			end
		end
		hider[i] = not isDust[i] and not isCopy[i]
	end
	return hider, isCopy, isDust
end

-- share, lo, hi, cells of solids[i]
function T.share(solids, i, hider, minCell)
	minCell = minCell or T.MIN_CELL
	local p = solids[i]
	local active, nActive = {}, 0
	local M = DELTA + 1e-6
	for j = 1, #solids do
		local q = solids[j]
		if j ~= i and hider[j] and p.minx <= q.maxx + M and q.minx <= p.maxx + M and p.miny <= q.maxy + M and q.miny <= p.maxy + M and p.minz <= q.maxz + M and q.minz <= p.maxz + M then
			nActive += 1
			active[nActive] = q
		end
	end
	local st = { shown = 0, uncertain = 0, cells = 0, midCells = 0, area = 0 }
	local hx, hy, hz = p.hx, p.hy, p.hz
	if p.shape == "Block" then
		local lc = { 0, 0, 0 }
		flatFace(p, st, { { hx, -hy, -hz }, { hx, hy, -hz }, { hx, hy, hz }, { hx, -hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, -hz }, { -hx, hy, -hz }, { -hx, hy, hz }, { -hx, -hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, hy, -hz }, { hx, hy, -hz }, { hx, hy, hz }, { -hx, hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, -hy, hz }, { -hx, -hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, hz }, { -hx, hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, hy, -hz }, { -hx, hy, -hz } }, active, nActive, minCell, lc)
	elseif p.shape == "Wedge" then
		-- z/hz >= y/hy: full -Y, +Z faces, a slope from (y = -hy, z = -hz) to (y = hy, z = hz), triangles at +-X
		local lc = { 0, -hy / 3, hz / 3 }
		flatFace(p, st, { { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, -hy, hz }, { -hx, -hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, hz }, { -hx, hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, hy, hz }, { -hx, hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { hx, -hy, -hz }, { hx, -hy, hz }, { hx, hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, -hz }, { -hx, -hy, hz }, { -hx, hy, hz } }, active, nActive, minCell, lc)
	elseif p.shape == "CornerWedge" then
		-- y/hy <= x/hx, y/hy <= -z/hz: apex (hx, hy, -hz) over the -Y rectangle
		local lc = { hx / 4, -hy / 2, -hz / 4 }
		local A = { hx, hy, -hz }
		flatFace(p, st, { { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, -hy, hz }, { -hx, -hy, hz } }, active, nActive, minCell, lc)
		flatFace(p, st, { { hx, -hy, -hz }, { hx, -hy, hz }, A }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, -hz }, { hx, -hy, -hz }, A }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, -hz }, { -hx, -hy, hz }, A }, active, nActive, minCell, lc)
		flatFace(p, st, { { -hx, -hy, hz }, { hx, -hy, hz }, A }, active, nActive, minCell, lc)
	elseif p.shape == "Cylinder" then
		local r = p.r
		-- the side: (x, angle)
		local function sidePoint(x, a)
			local ca, sa = cos(a), sin(a)
			local wx, wy, wz = world(p, x, r * ca, r * sa)
			return wx, wy, wz, ca * p.vx + sa * p.wx, ca * p.vy + sa * p.wy, ca * p.vz + sa * p.wz
		end
		local function sideArea(x0, x1, a0, a1)
			return (x1 - x0) * r * (a1 - a0)
		end
		local arcMin = min(minCell, 0.0015 * 2 * PI * r) -- a boundary along the axis errs by half a cell, all along it: thin rods need finer arcs
		local function sideRho(x0, x1, a0, a1, cell)
			local dx, da = (x1 - x0) / 2, (a1 - a0) / 2
			return sqrt(dx * dx + r * r * da * da), sqrt(dx * dx + (r + DELTA) * (r + DELTA) * da * da), (x1 - x0) / cell, r * (a1 - a0) / arcMin
		end
		st.area += 2 * PI * r * 2 * hx
		curvedCell(p, st, sidePoint, sideArea, -hx, hx, 0, 2 * PI, sideRho, active, nActive, minCell)
		-- the caps: polar cells, flat, the outer arc inside a circumscribed quad
		for side = -1, 1, 2 do
			local nx, ny, nz = side * p.ux, side * p.uy, side * p.uz
			st.area += PI * r * r
			local function polar(r0, r1, a0, a1, active2, n2)
				local rr = r1 / cos((a1 - a0) / 2)
				local c = table.create(12)
				local function put(k, rad, ang)
					c[3 * k + 1], c[3 * k + 2], c[3 * k + 3] = world(p, side * hx, rad * cos(ang), rad * sin(ang))
				end
				put(0, r0, a0)
				put(1, rr, a0)
				put(2, rr, a1)
				put(3, r0, a1)
				-- the area of the annular sector stands in for the quad's in the bookkeeping: split it in polar, not on the quad
				local cx, cy, cz = world(p, side * hx, (r0 + r1) / 2 * cos((a0 + a1) / 2), (r0 + r1) / 2 * sin((a0 + a1) / 2))
				local rho2 = 0
				for i = 0, 3 do
					local dx, dy, dz = c[3 * i + 1] - cx, c[3 * i + 2] - cy, c[3 * i + 3] - cz
					rho2 = max(rho2, dx * dx + dy * dy + dz * dz)
				end
				local rho = sqrt(rho2)
				local area = (r1 * r1 - r0 * r0) / 2 * (a1 - a0)
				local next2, m2 = table.create(n2), 0
				st.cells += 1
				for k = 1, n2 do
					local q = active2[k]
					local lower = q.index < p.index
					local allProbe, allBuried, allOn = true, true, true
					for i = 0, 3 do
						local x, y, z = c[3 * i + 1], c[3 * i + 2], c[3 * i + 3]
						if sd(q, x + DELTA * nx, y + DELTA * ny, z + DELTA * nz) > EPS then allProbe = false end
						local d0 = sd(q, x, y, z)
						if d0 >= -EPS then allBuried = false end
						if d0 > EPS then allOn = false end
					end
					if allProbe or allBuried or (lower and allOn) then
						return
					end
					local d0c, d1c = sd(q, cx, cy, cz), sd(q, cx + DELTA * nx, cy + DELTA * ny, cz + DELTA * nz)
					local clearS = if lower then d0c - rho > EPS else d0c - rho >= -EPS
					local clearP = d1c - rho > EPS
					if not (clearS and clearP) then
						for _, plane in ipairs(q.planes) do
							local minS, minP = math.huge, math.huge
							local shift = DELTA * (plane[1] * nx + plane[2] * ny + plane[3] * nz)
							for i = 0, 3 do
								local t = plane[1] * c[3 * i + 1] + plane[2] * c[3 * i + 2] + plane[3] * c[3 * i + 3] - plane[4]
								minS, minP = min(minS, t), min(minP, t + shift)
							end
							if minP > EPS then clearP = true end
							if lower then
								if minS > EPS then clearS = true end
							elseif minS >= -EPS then
								clearS = true
							end
							if clearS and clearP then break end
						end
					end
					if not (clearS and clearP) then
						m2 += 1
						next2[m2] = q
					end
				end
				if m2 == 0 then
					st.shown += area
					return
				end
				if rho <= minCell * 0.7072 then
					st.uncertain += area
					st.midCells += 1
					if not hiddenPoint(p, next2, m2, cx, cy, cz, nx, ny, nz) then
						st.shown += area
					end
					return
				end
				local rm, am = (r0 + r1) / 2, (a0 + a1) / 2
				if r1 - r0 >= rm * (a1 - a0) then
					polar(r0, rm, a0, a1, next2, m2)
					polar(rm, r1, a0, a1, next2, m2)
				else
					polar(r0, r1, a0, am, next2, m2)
					polar(r0, r1, am, a1, next2, m2)
				end
			end
			for s = 0, 7 do
				polar(0, r, s * PI / 4, (s + 1) * PI / 4, active, nActive)
			end
		end
	else
		-- a Ball: six cube faces, (a, b) in [-1, 1]^2
		local r = p.r
		local function F(a, b)
			return atan(a * b / sqrt(1 + a * a + b * b))
		end
		for face = 1, 6 do
			local function point(a, b)
				local px, py, pz
				if face == 1 then px, py, pz = 1, a, b
				elseif face == 2 then px, py, pz = -1, a, b
				elseif face == 3 then px, py, pz = a, 1, b
				elseif face == 4 then px, py, pz = a, -1, b
				elseif face == 5 then px, py, pz = a, b, 1
				else px, py, pz = a, b, -1 end
				local inv = 1 / sqrt(1 + a * a + b * b)
				px, py, pz = px * inv, py * inv, pz * inv
				local x, y, z = world(p, r * px, r * py, r * pz)
				return x, y, z, px * p.ux + py * p.vx + pz * p.wx, px * p.uy + py * p.vy + pz * p.wy, px * p.uz + py * p.vz + pz * p.wz
			end
			local function areaOf(a0, a1, b0, b1)
				return r * r * (F(a1, b1) - F(a0, b1) - F(a1, b0) + F(a0, b0))
			end
			local function rhoOf(a0, a1, b0, b1, cell)
				-- the farthest corner from the centre direction, on the sphere and on the probe's sphere
				local ax, ay, az = point((a0 + a1) / 2, (b0 + b1) / 2)
				local best = 0
				for _, c in ipairs({ { a0, b0 }, { a0, b1 }, { a1, b0 }, { a1, b1 } }) do
					local x, y, z = point(c[1], c[2])
					best = max(best, (x - ax) * (x - ax) + (y - ay) * (y - ay) + (z - az) * (z - az))
				end
				local rho = sqrt(best) * 1.02 -- a geodesic cell: the arc is a hair longer than the chord
				return rho, rho * (r + DELTA) / r, (a1 - a0) * r / cell, (b1 - b0) * r / cell
			end
			st.area += 0
			curvedCell(p, st, point, areaOf, -1, 1, -1, 1, rhoOf, active, nActive, minCell)
		end
		st.area = 4 * PI * r * r
	end
	return st.shown / st.area, (st.shown - st.uncertain) / st.area, (st.shown + st.uncertain) / st.area, st.cells, st.midCells
end

function T.solids(parts)
	local S = table.create(#parts)
	for i, part in ipairs(parts) do
		S[i] = T.solid(part, i)
	end
	return S
end

-- every part: its share, or false for a copy or Dust
function T.all(parts, minCell)
	local S = T.solids(parts)
	local hider, isCopy, isDust = T.hidersOf(S)
	local out, lo, hi = table.create(#parts), table.create(#parts), table.create(#parts)
	for i = 1, #parts do
		if isCopy[i] or isDust[i] then
			out[i], lo[i], hi[i] = false, false, false
		else
			out[i], lo[i], hi[i] = T.share(S, i, hider, minCell)
		end
	end
	return out, lo, hi
end

return T
