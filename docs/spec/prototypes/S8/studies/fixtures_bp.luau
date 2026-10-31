--!strict
-- S8 study (revision pass): the golden fixtures F1-F5 written in blueprint space as PartData
-- ({id, slot, shape, material, pos, rot = {qx, qy, qz, qw}, size}), checked against the Sword hitbox
-- x [-0.8, 0.8], y [0, 5], z [-0.3, 0.3] (origin = centre of the hitbox's bottom face), with S1's densities
-- (Iron 7.87, Steel 7.85 kg/stud^3). Prints exact analytic oracle values (independent of S2's code):
-- per-material volume, pairwise overlaps (0.002-stud sampling), mass and COM under the sum and union
-- conventions, grip point (volume-weighted centroid of Grip parts), Euclidean reach from the grip point
-- (farthest exact Blade vertex), axial blade top, min part dimension and hitbox margins.
-- Run from proto/S8:  lune run studies/fixtures_bp
local P = require("../repo/src/shared/Physics/ProtoShapes")

local R = 0.70710678118654757 -- sqrt(1/2), 17 significant digits
local I = { 0, 0, 0, 1 }
local Z45 = { 0, 0, 0.38268343236508978, 0.92387953251128674 }
local Z90 = { 0, 0, R, R }
local Y90 = { 0, R, 0, R }
local RHO = { Iron = 7.87, Steel = 7.85 }
local HMIN, HMAX = { -0.8, 0, -0.3 }, { 0.8, 5, 0.3 }

type PD = { id: number, slot: string, shape: string, material: string, pos: { number }, rot: { number }, size: { number } }

local function F1(bladeMat: string): { PD }
	return {
		{ id = 1, slot = "Pommel", shape = "Ball", material = "Iron", pos = { 0, 0.17, 0 }, rot = I, size = { 0.26, 0.26, 0.26 } },
		{ id = 2, slot = "Grip", shape = "Block", material = "Iron", pos = { 0, 0.75, 0 }, rot = I, size = { 0.16, 0.90, 0.16 } },
		{ id = 3, slot = "Guard", shape = "Block", material = "Iron", pos = { 0, 1.29, 0 }, rot = I, size = { 1.00, 0.18, 0.24 } },
		{ id = 4, slot = "Blade", shape = "Block", material = bladeMat, pos = { 0, 2.68, 0 }, rot = I, size = { 0.16, 2.60, 0.06 } },
		{ id = 5, slot = "Blade", shape = "Block", material = bladeMat, pos = { 0, 3.98, 0 }, rot = Z45, size = { 0.113, 0.113, 0.055 } },
	}
end

local fixtures: { { name: string, parts: { PD } } } = {
	{ name = "F1 ArmingSword", parts = F1("Steel") },
	{ name = "F2 MinimalSword", parts = {
		{ id = 1, slot = "Pommel", shape = "Block", material = "Iron", pos = { 0, 0.20, 0 }, rot = I, size = { 0.30, 0.30, 0.30 } },
		{ id = 2, slot = "Grip", shape = "Block", material = "Iron", pos = { 0, 0.85, 0 }, rot = I, size = { 0.20, 1.00, 0.20 } },
		{ id = 3, slot = "Guard", shape = "Block", material = "Iron", pos = { 0, 1.45, 0 }, rot = I, size = { 0.80, 0.20, 0.20 } },
		{ id = 4, slot = "Blade", shape = "Block", material = "Iron", pos = { 0, 2.75, 0 }, rot = I, size = { 0.20, 2.40, 0.08 } },
	} },
	{ name = "F3 Rapier", parts = {
		{ id = 1, slot = "Pommel", shape = "Ball", material = "Steel", pos = { 0, 0.16, 0 }, rot = I, size = { 0.28, 0.28, 0.28 } },
		{ id = 2, slot = "Grip", shape = "Cylinder", material = "Steel", pos = { 0, 0.75, 0 }, rot = Z90, size = { 0.90, 0.13, 0.13 } },
		{ id = 3, slot = "Guard", shape = "Block", material = "Steel", pos = { 0, 1.24, 0 }, rot = I, size = { 0.90, 0.08, 0.08 } },
		{ id = 4, slot = "Guard", shape = "Ball", material = "Steel", pos = { -0.45, 1.24, 0 }, rot = I, size = { 0.12, 0.12, 0.12 } },
		{ id = 5, slot = "Guard", shape = "Ball", material = "Steel", pos = { 0.45, 1.24, 0 }, rot = I, size = { 0.12, 0.12, 0.12 } },
		{ id = 6, slot = "Blade", shape = "Block", material = "Steel", pos = { 0, 2.98, 0 }, rot = I, size = { 0.07, 3.40, 0.035 } },
		{ id = 7, slot = "Blade", shape = "Wedge", material = "Steel", pos = { 0, 4.83, 0 }, rot = Y90, size = { 0.035, 0.30, 0.07 } },
	} },
	{ name = "F4 Cleaver", parts = {
		{ id = 1, slot = "Pommel", shape = "Block", material = "Iron", pos = { 0, 0.20, 0 }, rot = I, size = { 0.30, 0.20, 0.30 } },
		{ id = 2, slot = "Grip", shape = "Block", material = "Iron", pos = { 0, 0.75, 0 }, rot = I, size = { 0.22, 0.90, 0.22 } },
		{ id = 3, slot = "Guard", shape = "Block", material = "Iron", pos = { 0, 1.275, 0 }, rot = I, size = { 0.50, 0.15, 0.30 } },
		{ id = 4, slot = "Blade", shape = "Block", material = "Iron", pos = { 0.175, 2.45, 0 }, rot = I, size = { 0.85, 2.20, 0.16 } },
		{ id = 5, slot = "Blade", shape = "Wedge", material = "Iron", pos = { 0.175, 3.75, 0 }, rot = Y90, size = { 0.16, 0.40, 0.85 } },
	} },
	{ name = "F5 StarterSword", parts = F1("Iron") },
}

-- exact local vertices (polyhedra) of a part; nil for curved shapes
local function localVerts(p: PD): { { number } }?
	local hx, hy, hz = p.size[1] / 2, p.size[2] / 2, p.size[3] / 2
	if p.shape == "Wedge" then
		return { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { -hx, hy, hz }, { hx, hy, hz } }
	elseif p.shape == "CornerWedge" then
		return { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, -hz } }
	elseif p.shape == "Block" then
		local v = {}
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			table.insert(v, { sx * hx, sy * hy, sz * hz })
		end end end
		return v
	end
	return nil
end

-- exact world AABB (polyhedra: vertices; cylinder: axis + radius; ball: centre +- r)
local function aabb(p: PD): ({ number }, { number })
	local m = P.matrix(p.rot)
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	local vs = localVerts(p)
	if vs then
		for _, v in vs do
			local w = P.rotate(m, v)
			for a = 1, 3 do
				lo[a] = math.min(lo[a], p.pos[a] + w[a]); hi[a] = math.max(hi[a], p.pos[a] + w[a])
			end
		end
	elseif p.shape == "Ball" then
		local r = math.min(p.size[1], p.size[2], p.size[3]) / 2
		for a = 1, 3 do lo[a] = p.pos[a] - r; hi[a] = p.pos[a] + r end
	else -- Cylinder, axis = local X (column 1 of m)
		local hx, r = p.size[1] / 2, math.min(p.size[2], p.size[3]) / 2
		for a = 1, 3 do
			local u = m[(a - 1) * 3 + 1]
			local e = hx * math.abs(u) + r * math.sqrt(math.max(0, 1 - u * u))
			lo[a] = p.pos[a] - e; hi[a] = p.pos[a] + e
		end
	end
	return lo, hi
end

local function asProto(p: PD): any
	return { slot = p.slot, shape = p.shape, material = p.material, pos = p.pos, rot = p.rot, size = p.size }
end

-- A ∩ B volume and centroid by centre sampling at spacing h inside the AABB intersection
local function overlap(a: PD, b: PD, h: number): (number, { number })
	local alo, ahi = aabb(a)
	local blo, bhi = aabb(b)
	local lo, hi = {}, {}
	for i = 1, 3 do
		lo[i] = math.max(alo[i], blo[i]); hi[i] = math.min(ahi[i], bhi[i])
		if lo[i] >= hi[i] then return 0, { 0, 0, 0 } end
	end
	local pa, pb = { asProto(a) }, { asProto(b) }
	local n, sx, sy, sz = 0, 0, 0, 0
	local x = lo[1] + h / 2
	while x < hi[1] do
		local y = lo[2] + h / 2
		while y < hi[2] do
			local z = lo[3] + h / 2
			while z < hi[3] do
				if P.insideDesign(pa, x, y, z) and P.insideDesign(pb, x, y, z) then
					n += 1; sx += x; sy += y; sz += z
				end
				z += h
			end
			y += h
		end
		x += h
	end
	if n == 0 then return 0, { 0, 0, 0 } end
	return n * h * h * h, { sx / n, sy / n, sz / n }
end

local slotRank = { Blade = 1, Guard = 2, Grip = 3, Pommel = 4 }

for _, fx in fixtures do
	local parts = fx.parts
	local vMat: { [string]: number } = {}
	local m, mx, my, mz = 0, 0, 0, 0
	local gV, gx, gy, gz = 0, 0, 0, 0
	local minDim, minMargin = math.huge, math.huge
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, p in parts do
		local v = P.analyticVolume(asProto(p))
		local c = P.rotate(P.matrix(p.rot), P.localCentroid(asProto(p)))
		local w = { p.pos[1] + c[1], p.pos[2] + c[2], p.pos[3] + c[3] }
		vMat[p.material] = (vMat[p.material] or 0) + v
		local dm = RHO[p.material] * v
		m += dm; mx += dm * w[1]; my += dm * w[2]; mz += dm * w[3]
		if p.slot == "Grip" then gV += v; gx += v * w[1]; gy += v * w[2]; gz += v * w[3] end
		minDim = math.min(minDim, p.size[1], p.size[2], p.size[3])
		local plo, phi = aabb(p)
		for a = 1, 3 do
			lo[a] = math.min(lo[a], plo[a]); hi[a] = math.max(hi[a], phi[a])
			minMargin = math.min(minMargin, plo[a] - HMIN[a], HMAX[a] - phi[a])
		end
	end
	local g = { gx / gV, gy / gV, gz / gV }
	-- overlaps: owner = earlier in (slot rank, id); union removes the overlap from the lower-priority part
	local ovTotal, uM, uMx, uMy, uMz = 0, m, mx, my, mz
	local ovText = {}
	for i = 1, #parts do
		for j = i + 1, #parts do
			local v, c = overlap(parts[i], parts[j], 0.002)
			if v > 0 then
				local a, b = parts[i], parts[j]
				local loser = if slotRank[a.slot] < slotRank[b.slot] or (slotRank[a.slot] == slotRank[b.slot] and a.id < b.id) then b else a
				local dm = RHO[loser.material] * v
				uM -= dm; uMx -= dm * c[1]; uMy -= dm * c[2]; uMz -= dm * c[3]
				ovTotal += v
				table.insert(ovText, string.format("#%d∩#%d=%.6f", a.id, b.id, v))
			end
		end
	end
	-- Euclidean reach: farthest exact Blade vertex from g (Blade parts here are polyhedra)
	local reach, top = 0, -math.huge
	for _, p in parts do
		if p.slot == "Blade" then
			local vs = localVerts(p)
			assert(vs, "fixture blades are polyhedra")
			local mm = P.matrix(p.rot)
			for _, v in vs do
				local w = P.rotate(mm, v)
				local dx, dy, dz = p.pos[1] + w[1] - g[1], p.pos[2] + w[2] - g[2], p.pos[3] + w[3] - g[3]
				reach = math.max(reach, math.sqrt(dx * dx + dy * dy + dz * dz))
				top = math.max(top, p.pos[2] + w[2])
			end
		end
	end
	local vSum = 0
	for _, v in vMat do vSum += v end
	print(string.format("%s  parts=%d  minDim=%.3f  hitbox margin=%.3f  AABB x[%.3f, %.3f] y[%.3f, %.3f] z[%.3f, %.3f]",
		fx.name, #parts, minDim, minMargin, lo[1], hi[1], lo[2], hi[2], lo[3], hi[3]))
	print(string.format("  V_sum=%.5f (Iron %.6f, Steel %.6f)  overlap=%.6f %s -> V_union=%.5f",
		vSum, vMat.Iron or 0, vMat.Steel or 0, ovTotal, table.concat(ovText, " "), vSum - ovTotal))
	print(string.format("  mass sum=%.4f union=%.4f kg | COM sum (%.4f, %.4f, %.4f) union (%.4f, %.4f, %.4f)",
		m, uM, mx / m, my / m, mz / m, uMx / uM, uMy / uM, uMz / uM))
	print(string.format("  grip point (%.4f, %.4f, %.4f)  blade top y=%.4f (axial %.4f)  reach (Euclidean, from g)=%.4f",
		g[1], g[2], g[3], top, top - g[2], reach))
	print(string.format("  balanceFromHand sum=%.4f union=%.4f (COM_y - g_y)", my / m - g[2], uMy / uM - g[2]))
end
