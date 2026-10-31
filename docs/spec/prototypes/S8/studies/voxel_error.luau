--!strict
-- S8 study: discretization error of centre-sampled voxelization, to set test tolerances.
-- Run from proto/S8:  lune run studies/voxel_error
local P = require("../repo/src/shared/Physics/ProtoShapes")
local F = require("../repo/tests/fixtures/Blueprints")
local TestRng = require("../repo/tests/lib/TestRng")

local rng = TestRng.new(20261031)

local function randomQuat(): { number }
	-- Shoemake uniform random rotation (study only: uses sin/cos)
	local u1, u2, u3 = rng:float(), rng:float(), rng:float()
	local a, b = math.sqrt(1 - u1), math.sqrt(u1)
	return { a * math.sin(2 * math.pi * u2), a * math.cos(2 * math.pi * u2), b * math.sin(2 * math.pi * u3), b * math.cos(2 * math.pi * u3) }
end

-- Count voxel centres inside one part on a grid with spacing h anchored at (ox, oy, oz).
local function countPart(part: P.Part, h: number, ox: number, oy: number, oz: number): number
	local m = P.matrix(part.rot)
	local hx, hy, hz = part.size[1] / 2, part.size[2] / 2, part.size[3] / 2
	local e1 = math.abs(m[1]) * hx + math.abs(m[2]) * hy + math.abs(m[3]) * hz
	local e2 = math.abs(m[4]) * hx + math.abs(m[5]) * hy + math.abs(m[6]) * hz
	local e3 = math.abs(m[7]) * hx + math.abs(m[8]) * hy + math.abs(m[9]) * hz
	local px, py, pz = part.pos[1], part.pos[2], part.pos[3]
	local n = 0
	for k = math.floor((pz - e3 - oz) / h), math.floor((pz + e3 - oz) / h) do
		local dz = oz + (k + 0.5) * h - pz
		for j = math.floor((py - e2 - oy) / h), math.floor((py + e2 - oy) / h) do
			local dy = oy + (j + 0.5) * h - py
			for i = math.floor((px - e1 - ox) / h), math.floor((px + e1 - ox) / h) do
				local dx = ox + (i + 0.5) * h - px
				local lx = m[1] * dx + m[4] * dy + m[7] * dz
				local ly = m[2] * dx + m[5] * dy + m[8] * dz
				local lz = m[3] * dx + m[6] * dy + m[9] * dz
				if P.insideLocal(part.shape, hx, hy, hz, lx, ly, lz) then n += 1 end
			end
		end
	end
	return n * h * h * h
end

local SHAPES: { { name: string, part: P.Part, area: number? } } = {
	{ name = "Block blade 0.16x2.6x0.06", part = { slot = "", shape = "Block", material = "", pos = { 0, 0, 0 }, rot = { 0, 0, 0, 1 }, size = { 0.16, 2.6, 0.06 } }, area = 2 * (0.16 * 2.6 + 2.6 * 0.06 + 0.06 * 0.16) },
	{ name = "Block guard 1.0x0.18x0.24", part = { slot = "", shape = "Block", material = "", pos = { 0, 0, 0 }, rot = { 0, 0, 0, 1 }, size = { 1.0, 0.18, 0.24 } }, area = 2 * (1.0 * 0.18 + 0.18 * 0.24 + 0.24 * 1.0) },
	{ name = "Ball d0.26", part = { slot = "", shape = "Ball", material = "", pos = { 0, 0, 0 }, rot = { 0, 0, 0, 1 }, size = { 0.26, 0.26, 0.26 } }, area = 4 * math.pi * 0.13 * 0.13 },
	{ name = "Cylinder L0.9 d0.13", part = { slot = "", shape = "Cylinder", material = "", pos = { 0, 0, 0 }, rot = { 0, 0, 0, 1 }, size = { 0.9, 0.13, 0.13 } }, area = 2 * math.pi * 0.065 * 0.065 + 2 * math.pi * 0.065 * 0.9 },
	{ name = "Wedge 0.85x0.4x0.16", part = { slot = "", shape = "Wedge", material = "", pos = { 0, 0, 0 }, rot = { 0, 0, 0, 1 }, size = { 0.85, 0.4, 0.16 } }, area = nil },
	{ name = "CornerWedge 0.3^3", part = { slot = "", shape = "CornerWedge", material = "", pos = { 0, 0, 0 }, rot = { 0, 0, 0, 1 }, size = { 0.3, 0.3, 0.3 } }, area = nil },
}

print("== 1. single part: |V_voxel - V_exact| / V_exact over random rotation + sub-voxel offset")
print("   (k = |err| / (A*h): fit for a tolerance tol_V = k*A*h/V)")
for _, h in { 0.05, 0.025, 0.0125 } do
	for _, s in SHAPES do
		local exact = P.analyticVolume(s.part)
		local samples = if h < 0.02 then 24 else 60
		local sum, worst, kWorst = 0, 0, 0
		for _ = 1, samples do
			local part = table.clone(s.part)
			part.rot = randomQuat()
			local v = countPart(part, h, rng:range(0, h), rng:range(0, h), rng:range(0, h))
			local e = math.abs(v - exact) / exact
			sum += e
			if e > worst then worst = e end
			if s.area then
				local k = math.abs(v - exact) / ((s.area :: number) * h)
				if k > kWorst then kWorst = k end
			end
		end
		print(string.format("  h=%-6g %-26s mean %6.2f%%  max %6.2f%%%s", h, s.name, 100 * sum / samples, 100 * worst,
			if s.area then string.format("  k_max=%.3f", kWorst) else ""))
	end
end

local HITBOX = { x0 = -0.6, y0 = -1.3, z0 = -0.2, x1 = 0.6, y1 = 3.9, z1 = 0.2 }
local function gridFor(h: number): P.Grid
	return { ox = HITBOX.x0, oy = HITBOX.y0, oz = HITBOX.z0, h = h,
		nx = math.ceil((HITBOX.x1 - HITBOX.x0) / h - 1e-9), ny = math.ceil((HITBOX.y1 - HITBOX.y0) / h - 1e-9), nz = math.ceil((HITBOX.z1 - HITBOX.z0) / h - 1e-9) }
end
local function translate(parts: { P.Part }, d: { number }): { P.Part }
	return P.transformDesign(parts, { 0, 0, 0, 1 }, d)
end
local function sumVolumes(parts: { P.Part }): number
	local v = 0
	for _, part in parts do v += P.analyticVolume(part) end
	return v
end

print("\n== 2. fixture union volume / COM / reach jitter under 40 random sub-voxel translations")
local EQUAL = { Iron = 1, Steel = 1 }
for _, h in { 0.05, 0.025, 0.0125 } do
	local grid = gridFor(h)
	for _, name in F.order do
		local parts = (F :: any)[name] :: { P.Part }
		local vols, comY, reach = {}, {}, {}
		local tSum = 0
		for _ = 1, 40 do
			local d = { rng:range(0, h), rng:range(0, h), rng:range(0, h) }
			local moved = translate(parts, d)
			local c0 = os.clock()
			local occ = P.voxelize(moved, grid)
			tSum += os.clock() - c0
			local mp = P.massProps(moved, occ, EQUAL)
			table.insert(vols, mp.volume)
			table.insert(comY, mp.com[2] - d[2])
			table.insert(reach, mp.maxY - d[2])
		end
		local function stats(xs: { number }): (number, number, number)
			local mean, lo, hi = 0, math.huge, -math.huge
			for _, x in xs do mean += x; lo = math.min(lo, x); hi = math.max(hi, x) end
			mean /= #xs
			return mean, lo, hi
		end
		local vm, vlo, vhi = stats(vols)
		local cm, clo, chi = stats(comY)
		local _, rlo, rhi = stats(reach)
		print(string.format("  h=%-6g %-13s V=%.5f (exact-sum %.5f) range %5.2f%%  COMy %.4f ±%.4f  reach-range %.4f  voxelize %.1f ms",
			h, name, vm, sumVolumes(parts), 100 * (vhi - vlo) / vm, cm, (chi - clo) / 2, rhi - rlo, 1000 * tSum / 40))
	end
end

print("\n== 3. asymmetry: noise floor on symmetric fixtures, signal on asymmetric ones (h=0.025)")
do
	local grid = gridFor(0.025)
	for _, name in F.order do
		local parts = (F :: any)[name] :: { P.Part }
		local worstGrid, worstExact = 0, 0
		for _ = 1, 20 do
			local dx = rng:range(-0.05, 0.05)
			local moved = translate(parts, { dx, 0, 0 })
			local occ = P.voxelize(moved, grid)
			worstGrid = math.max(worstGrid, P.asymmetryGrid(occ))
			worstExact = math.max(worstExact, P.asymmetryExact(moved, occ, dx))
		end
		print(string.format("  %-13s max over 20 x-offsets: grid-centre mirror %.4f   exact mirror about own plane %.4f", name, worstGrid, worstExact))
	end
end

print("\n== 4. fixture reference geometry (fixture frame, h=0.0125, rho_Iron=1, rho_Steel=r)")
do
	local grid = gridFor(0.0125)
	for _, name in F.order do
		local parts = (F :: any)[name] :: { P.Part }
		local occ = P.voxelize(parts, grid)
		local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
		local bladeTop = -math.huge
		for _, part in parts do
			local m = P.matrix(part.rot)
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				local c = P.rotate(m, { sx * part.size[1] / 2, sy * part.size[2] / 2, sz * part.size[3] / 2 })
				for a = 1, 3 do
					lo[a] = math.min(lo[a], part.pos[a] + c[a]); hi[a] = math.max(hi[a], part.pos[a] + c[a])
				end
				if part.slot == "Blade" then bladeTop = math.max(bladeTop, part.pos[2] + c[2]) end
			end end end
		end
		local coms = {}
		local masses = {}
		for _, r in { 0.9, 1.0, 1.1 } do
			local mp = P.massProps(parts, occ, { Iron = 1, Steel = r })
			table.insert(coms, string.format("%.4f", mp.com[2]))
			table.insert(masses, string.format("%.5f", mp.mass))
		end
		local mp = P.massProps(parts, occ, EQUAL)
		local vIron, vSteel = 0, 0
		for _, part in parts do
			if part.material == "Iron" then vIron += P.analyticVolume(part) else vSteel += P.analyticVolume(part) end
		end
		print(string.format("  %-13s parts=%d  sumV=%.5f (Iron %.5f, Steel %.5f) unionV=%.5f  AABB x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]",
			name, #parts, sumVolumes(parts), vIron, vSteel, mp.volume, lo[1], hi[1], lo[2], hi[2], lo[3], hi[3]))
		print(string.format("  %-13s bladeTopY=%.4f  COMy(r=0.9,1.0,1.1)=%s  COMx=%.4f  mass(r=0.9,1.0,1.1)=%s",
			"", bladeTop, table.concat(coms, ","), mp.com[1], table.concat(masses, ",")))
	end
end
