--!strict
-- PROTOTYPE stand-in for S2's Physics modules, used only to measure voxel
-- discretization error and to exercise the S8 test harness. Not a spec of S2's API.
-- Shape conventions assumed from Roblox (to be confirmed by the Studio parity test):
--   Cylinder axis = local X, radius = min(sy, sz)/2
--   Ball radius = min(sx, sy, sz)/2
--   Wedge: height grows linearly from 0 at local -Z to sy at local +Z (volume 1/2 box)
--   CornerWedge: square pyramid, base = bottom face, apex above the (+X, -Z) corner (volume 1/3 box)

export type Part = {
	slot: string,
	shape: string, -- "Block" | "Wedge" | "CornerWedge" | "Cylinder" | "Ball"
	material: string,
	pos: { number }, -- {x, y, z} studs, centre of the part
	rot: { number }, -- unit quaternion {x, y, z, w}
	size: { number }, -- {sx, sy, sz} studs
}
export type Grid = { ox: number, oy: number, oz: number, h: number, nx: number, ny: number, nz: number }
export type Occupancy = { cells: { number }, filled: number, grid: Grid } -- cells[i] = owning part index or 0

local P = {}

-- Rotation matrix (row-major 9 numbers) from a unit quaternion. Only + - * : IEEE-exact.
function P.matrix(q: { number }): { number }
	local x, y, z, w = q[1], q[2], q[3], q[4]
	return {
		1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
		2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
		2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y),
	}
end

function P.qmul(a: { number }, b: { number }): { number }
	local ax, ay, az, aw = a[1], a[2], a[3], a[4]
	local bx, by, bz, bw = b[1], b[2], b[3], b[4]
	return {
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
		aw * bw - ax * bx - ay * by - az * bz,
	}
end

function P.rotate(m: { number }, v: { number }): { number }
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

-- Point-in-shape in part-local coordinates, half sizes hx, hy, hz.
function P.insideLocal(shape: string, hx: number, hy: number, hz: number, x: number, y: number, z: number): boolean
	if x < -hx or x > hx or y < -hy or y > hy or z < -hz or z > hz then return false end
	if shape == "Block" then
		return true
	elseif shape == "Ball" then
		local r = math.min(hx, hy, hz)
		return x * x + y * y + z * z <= r * r
	elseif shape == "Cylinder" then
		local r = math.min(hy, hz)
		return y * y + z * z <= r * r
	elseif shape == "Wedge" then
		return (y + hy) * hz <= (z + hz) * hy
	elseif shape == "CornerWedge" then
		local t = (y + hy) / (2 * hy)
		return x >= -hx + 2 * hx * t and z <= hz - 2 * hz * t
	end
	error("unknown shape " .. shape)
end

function P.analyticVolume(part: Part): number
	local sx, sy, sz = part.size[1], part.size[2], part.size[3]
	local s = part.shape
	if s == "Block" then return sx * sy * sz end
	if s == "Wedge" then return sx * sy * sz / 2 end
	if s == "CornerWedge" then return sx * sy * sz / 3 end
	if s == "Cylinder" then local r = math.min(sy, sz) / 2; return math.pi * r * r * sx end
	if s == "Ball" then local r = math.min(sx, sy, sz) / 2; return 4 / 3 * math.pi * r * r * r end
	error("unknown shape " .. s)
end

-- Centroid of the shape in part-local coordinates (exact).
function P.localCentroid(part: Part): { number }
	local hx, hy, hz = part.size[1] / 2, part.size[2] / 2, part.size[3] / 2
	if part.shape == "Wedge" then return { 0, -hy / 3, hz / 3 } end
	if part.shape == "CornerWedge" then return { hx / 4, -hy / 2, -hz / 4 } end
	return { 0, 0, 0 } -- Block, Ball, Cylinder are centrally symmetric
end

-- Sum-of-parts analytic mass properties (overlaps counted twice; exact otherwise).
function P.analyticMassProps(parts: { Part }, density: { [string]: number }): MassProps
	local m, mx, my, mz, vol, maxY = 0, 0, 0, 0, 0, -math.huge
	for _, part in parts do
		local v = P.analyticVolume(part)
		local c = P.rotate(P.matrix(part.rot), P.localCentroid(part))
		local dm = density[part.material] * v
		m += dm; vol += v
		mx += dm * (part.pos[1] + c[1]); my += dm * (part.pos[2] + c[2]); mz += dm * (part.pos[3] + c[3])
		maxY = math.max(maxY, P.supportY(part))
	end
	return { volume = vol, mass = m, com = { mx / m, my / m, mz / m }, maxY = maxY }
end

-- Highest world Y reached by the exact shape (vertices for polyhedra, closed form for curved shapes).
function P.supportY(part: Part): number
	local m = P.matrix(part.rot)
	local hx, hy, hz = part.size[1] / 2, part.size[2] / 2, part.size[3] / 2
	local s = part.shape
	if s == "Ball" then return part.pos[2] + math.min(hx, hy, hz) end
	if s == "Cylinder" then
		local r = math.min(hy, hz)
		local ay = m[4] -- world Y component of the local X (axis) direction
		return part.pos[2] + math.abs(ay) * hx + r * math.sqrt(math.max(0, 1 - ay * ay))
	end
	local verts: { { number } }
	if s == "Wedge" then
		verts = { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { -hx, hy, hz }, { hx, hy, hz } }
	elseif s == "CornerWedge" then
		verts = { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, -hz } }
	else
		verts = {}
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			table.insert(verts, { sx * hx, sy * hy, sz * hz })
		end end end
	end
	local best = -math.huge
	for _, v in verts do
		best = math.max(best, m[4] * v[1] + m[5] * v[2] + m[6] * v[3])
	end
	return part.pos[2] + best
end

-- Precomputed per-part data for fast point queries.
type Prepared = { shape: string, hx: number, hy: number, hz: number, px: number, py: number, pz: number, m: { number }, e: { number } }

local function prepare(part: Part): Prepared
	local m = P.matrix(part.rot)
	local hx, hy, hz = part.size[1] / 2, part.size[2] / 2, part.size[3] / 2
	-- world AABB half extents of the oriented box
	local e = {
		math.abs(m[1]) * hx + math.abs(m[2]) * hy + math.abs(m[3]) * hz,
		math.abs(m[4]) * hx + math.abs(m[5]) * hy + math.abs(m[6]) * hz,
		math.abs(m[7]) * hx + math.abs(m[8]) * hy + math.abs(m[9]) * hz,
	}
	return { shape = part.shape, hx = hx, hy = hy, hz = hz, px = part.pos[1], py = part.pos[2], pz = part.pos[3], m = m, e = e }
end

local function insidePrepared(q: Prepared, wx: number, wy: number, wz: number): boolean
	local dx, dy, dz = wx - q.px, wy - q.py, wz - q.pz
	local m = q.m
	-- local = R^T * d
	local lx = m[1] * dx + m[4] * dy + m[7] * dz
	local ly = m[2] * dx + m[5] * dy + m[8] * dz
	local lz = m[3] * dx + m[6] * dy + m[9] * dz
	return P.insideLocal(q.shape, q.hx, q.hy, q.hz, lx, ly, lz)
end

function P.insideDesign(parts: { Part }, wx: number, wy: number, wz: number): boolean
	for _, part in parts do
		if insidePrepared(prepare(part), wx, wy, wz) then return true end
	end
	return false
end

-- Centre-sampled voxelization: a cell is filled when its centre lies inside a part;
-- the owner is the first part (in blueprint order) that contains the centre.
function P.voxelize(parts: { Part }, grid: Grid): Occupancy
	local nx, ny, nz, h = grid.nx, grid.ny, grid.nz, grid.h
	local cells = table.create(nx * ny * nz, 0)
	local filled = 0
	for index, part in parts do
		local q = prepare(part)
		local i0 = math.max(0, math.floor((q.px - q.e[1] - grid.ox) / h))
		local i1 = math.min(nx - 1, math.floor((q.px + q.e[1] - grid.ox) / h))
		local j0 = math.max(0, math.floor((q.py - q.e[2] - grid.oy) / h))
		local j1 = math.min(ny - 1, math.floor((q.py + q.e[2] - grid.oy) / h))
		local k0 = math.max(0, math.floor((q.pz - q.e[3] - grid.oz) / h))
		local k1 = math.min(nz - 1, math.floor((q.pz + q.e[3] - grid.oz) / h))
		for k = k0, k1 do
			local wz = grid.oz + (k + 0.5) * h
			for j = j0, j1 do
				local wy = grid.oy + (j + 0.5) * h
				local base = (k * ny + j) * nx
				for i = i0, i1 do
					local idx = base + i + 1
					if cells[idx] == 0 then
						local wx = grid.ox + (i + 0.5) * h
						if insidePrepared(q, wx, wy, wz) then
							cells[idx] = index
							filled += 1
						end
					end
				end
			end
		end
	end
	return { cells = cells, filled = filled, grid = grid }
end

export type MassProps = { volume: number, mass: number, com: { number }, maxY: number }

-- density: material id -> density (mass units per stud^3)
function P.massProps(parts: { Part }, occ: Occupancy, density: { [string]: number }): MassProps
	local g = occ.grid
	local h3 = g.h * g.h * g.h
	local m, mx, my, mz, vol, maxY = 0, 0, 0, 0, 0, -math.huge
	local nx, ny = g.nx, g.ny
	for idx, owner in occ.cells do
		if owner ~= 0 then
			local lin = idx - 1
			local i = lin % nx
			local j = (lin // nx) % ny
			local k = lin // (nx * ny)
			local wx, wy, wz = g.ox + (i + 0.5) * g.h, g.oy + (j + 0.5) * g.h, g.oz + (k + 0.5) * g.h
			local dm = density[parts[owner].material] * h3
			m += dm; mx += dm * wx; my += dm * wy; mz += dm * wz; vol += h3
			if wy > maxY then maxY = wy end
		end
	end
	return { volume = vol, mass = m, com = { mx / m, my / m, mz / m }, maxY = maxY }
end

-- Asymmetry = 1 - |V ∩ mirror_x=c(V)| / |V|, mirror evaluated exactly on the shapes.
function P.asymmetryExact(parts: { Part }, occ: Occupancy, planeX: number): number
	local g = occ.grid
	local prepared = {}
	for i, part in parts do prepared[i] = prepare(part) end
	local overlap = 0
	local nx, ny = g.nx, g.ny
	for idx, owner in occ.cells do
		if owner ~= 0 then
			local lin = idx - 1
			local i = lin % nx
			local j = (lin // nx) % ny
			local k = lin // (nx * ny)
			local wx, wy, wz = g.ox + (i + 0.5) * g.h, g.oy + (j + 0.5) * g.h, g.oz + (k + 0.5) * g.h
			local mxw = 2 * planeX - wx
			for _, q in prepared do
				if insidePrepared(q, mxw, wy, wz) then overlap += 1; break end
			end
		end
	end
	return 1 - overlap / occ.filled
end

-- Asymmetry on the grid only: mirror cell i -> nx-1-i (plane fixed at the grid centre).
function P.asymmetryGrid(occ: Occupancy): number
	local g = occ.grid
	local nx, ny, nz = g.nx, g.ny, g.nz
	local overlap = 0
	for k = 0, nz - 1 do
		for j = 0, ny - 1 do
			local base = (k * ny + j) * nx
			for i = 0, nx - 1 do
				if occ.cells[base + i + 1] ~= 0 and occ.cells[base + (nx - 1 - i) + 1] ~= 0 then overlap += 1 end
			end
		end
	end
	return 1 - overlap / occ.filled
end

function P.transformDesign(parts: { Part }, q: { number }, t: { number }): { Part }
	-- world' = R(q) * world + t   (rotation about the fixture origin, then translation)
	local m = P.matrix(q)
	local out = {}
	for i, part in parts do
		local p = P.rotate(m, part.pos)
		out[i] = {
			slot = part.slot, shape = part.shape, material = part.material,
			pos = { p[1] + t[1], p[2] + t[2], p[3] + t[3] },
			rot = P.qmul(q, part.rot),
			size = { part.size[1], part.size[2], part.size[3] },
		}
	end
	return out
end

return P
