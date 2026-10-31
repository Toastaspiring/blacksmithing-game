--!strict
-- S6 prototype: rough cost of a voxel-based live preview (to size the editor's debounce / time slicing).
-- NOT S2's algorithm - a stand-in with similar work: voxelize N OBB parts, count surface faces,
-- 2-pass chamfer distance transform (thickness proxy). Lune interpreter timing ~ Roblox client (no native codegen).
-- Run: lune run preview_cost.luau

local HB = { x = 1.6, y = 5.0, z = 0.6 } -- S2 prototype hitbox: x [-0.8,0.8], y [0,5], z [-0.3,0.3] -- ASSUMED hitbox (S2 owns)

local seed = 4242
local function rnd(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function rot(ax: number, ay: number, az: number, ang: number): { number }
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	local x, y, z = ax / n, ay / n, az / n
	local c, s, t = math.cos(ang), math.sin(ang), 1 - math.cos(ang)
	return { t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c }
end

local function run(nParts: number, vox: number): (number, number)
	local nx, ny, nz = math.ceil(HB.x / vox), math.ceil(HB.y / vox), math.ceil(HB.z / vox)
	local grid = buffer.create(nx * ny * nz)
	local parts = {}
	for i = 1, nParts do
		local R = rot(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5, (rnd() - 0.5) * 0.6)
		table.insert(parts, { cx = (rnd() - 0.5) * HB.x * 0.6, cy = rnd() * HB.y * 0.9 - HB.y / 2 * 0.9, cz = 0, hx = 0.05 + rnd() * 0.3, hy = 0.1 + rnd() * 0.6, hz = 0.03 + rnd() * 0.1, R = R })
	end
	local t0 = os.clock()
	local filled = 0
	for _, p in parts do
		local R = p.R
		-- AABB of OBB
		local ex = math.abs(R[1]) * p.hx + math.abs(R[2]) * p.hy + math.abs(R[3]) * p.hz
		local ey = math.abs(R[4]) * p.hx + math.abs(R[5]) * p.hy + math.abs(R[6]) * p.hz
		local ez = math.abs(R[7]) * p.hx + math.abs(R[8]) * p.hy + math.abs(R[9]) * p.hz
		local i0 = math.max(0, math.floor((p.cx - ex + HB.x / 2) / vox))
		local i1 = math.min(nx - 1, math.floor((p.cx + ex + HB.x / 2) / vox))
		local j0 = math.max(0, math.floor((p.cy - ey + HB.y / 2) / vox))
		local j1 = math.min(ny - 1, math.floor((p.cy + ey + HB.y / 2) / vox))
		local k0 = math.max(0, math.floor((p.cz - ez + HB.z / 2) / vox))
		local k1 = math.min(nz - 1, math.floor((p.cz + ez + HB.z / 2) / vox))
		for k = k0, k1 do
			local wz = (k + 0.5) * vox - HB.z / 2 - p.cz
			for j = j0, j1 do
				local wy = (j + 0.5) * vox - HB.y / 2 - p.cy
				for i = i0, i1 do
					local wx = (i + 0.5) * vox - HB.x / 2 - p.cx
					local lx = R[1] * wx + R[4] * wy + R[7] * wz
					local ly = R[2] * wx + R[5] * wy + R[8] * wz
					local lz = R[3] * wx + R[6] * wy + R[9] * wz
					if math.abs(lx) <= p.hx and math.abs(ly) <= p.hy and math.abs(lz) <= p.hz then
						local idx = (k * ny + j) * nx + i
						if buffer.readu8(grid, idx) == 0 then
							buffer.writeu8(grid, idx, 1)
							filled += 1
						end
					end
				end
			end
		end
	end
	-- surface faces
	local faces = 0
	for k = 0, nz - 1 do
		for j = 0, ny - 1 do
			for i = 0, nx - 1 do
				local idx = (k * ny + j) * nx + i
				if buffer.readu8(grid, idx) == 1 then
					if i == 0 or buffer.readu8(grid, idx - 1) == 0 then faces += 1 end
					if i == nx - 1 or buffer.readu8(grid, idx + 1) == 0 then faces += 1 end
					if j == 0 or buffer.readu8(grid, idx - nx) == 0 then faces += 1 end
					if j == ny - 1 or buffer.readu8(grid, idx + nx) == 0 then faces += 1 end
					if k == 0 or buffer.readu8(grid, idx - nx * ny) == 0 then faces += 1 end
					if k == nz - 1 or buffer.readu8(grid, idx + nx * ny) == 0 then faces += 1 end
				end
			end
		end
	end
	-- chamfer distance transform (2 passes, 6-neighbour) as a thickness proxy
	local dist = buffer.create(nx * ny * nz * 2)
	local n = nx * ny * nz
	for idx = 0, n - 1 do
		buffer.writeu16(dist, idx * 2, if buffer.readu8(grid, idx) == 1 then 65535 else 0)
	end
	for k = 0, nz - 1 do
		for j = 0, ny - 1 do
			for i = 0, nx - 1 do
				local idx = (k * ny + j) * nx + i
				local d = buffer.readu16(dist, idx * 2)
				if d > 0 then
					if i > 0 then d = math.min(d, buffer.readu16(dist, (idx - 1) * 2) + 1) else d = 1 end
					if j > 0 then d = math.min(d, buffer.readu16(dist, (idx - nx) * 2) + 1) else d = 1 end
					if k > 0 then d = math.min(d, buffer.readu16(dist, (idx - nx * ny) * 2) + 1) else d = 1 end
					buffer.writeu16(dist, idx * 2, d)
				end
			end
		end
	end
	for k = nz - 1, 0, -1 do
		for j = ny - 1, 0, -1 do
			for i = nx - 1, 0, -1 do
				local idx = (k * ny + j) * nx + i
				local d = buffer.readu16(dist, idx * 2)
				if d > 0 then
					if i < nx - 1 then d = math.min(d, buffer.readu16(dist, (idx + 1) * 2) + 1) else d = 1 end
					if j < ny - 1 then d = math.min(d, buffer.readu16(dist, (idx + nx) * 2) + 1) else d = 1 end
					if k < nz - 1 then d = math.min(d, buffer.readu16(dist, (idx + nx * ny) * 2) + 1) else d = 1 end
					buffer.writeu16(dist, idx * 2, d)
				end
			end
		end
	end
	local ms = (os.clock() - t0) * 1000
	return ms, filled + faces * 0
end

print("parts  voxel  grid           ms (median of 5)")
for _, cfg in { { 16, 0.05 }, { 32, 0.05 }, { 64, 0.05 }, { 32, 0.025 }, { 64, 0.025 } } do
	local times = {}
	for _ = 1, 5 do
		local ms = run(cfg[1], cfg[2])
		table.insert(times, ms)
	end
	table.sort(times)
	local vox = cfg[2]
	print(string.format("%5d  %.3f  %3dx%3dx%3d  %8.1f", cfg[1], vox, math.ceil(HB.x / vox), math.ceil(HB.y / vox), math.ceil(HB.z / vox), times[3]))
end
