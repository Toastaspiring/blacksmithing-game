--!strict
-- S6 prototype: mirror a free-transform primitive across a blueprint plane (x=0 or z=0)
-- and represent the result as a *proper* rotation + size of the same shape.
-- Checks: vertex set of the mirrored part == reflected vertex set of the original; mirror twice == identity.
-- Run: lune run mirror.luau

type V3 = { number }
type M3 = { { number } }

local function mmul(a: M3, b: M3): M3
	local r = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
	for i = 1, 3 do
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end
local function mv(a: M3, v: V3): V3
	return { a[1][1] * v[1] + a[1][2] * v[2] + a[1][3] * v[3], a[2][1] * v[1] + a[2][2] * v[2] + a[2][3] * v[3], a[3][1] * v[1] + a[3][2] * v[2] + a[3][3] * v[3] }
end
local function det(a: M3): number
	return a[1][1] * (a[2][2] * a[3][3] - a[2][3] * a[3][2]) - a[1][2] * (a[2][1] * a[3][3] - a[2][3] * a[3][1]) + a[1][3] * (a[2][1] * a[3][2] - a[2][2] * a[3][1])
end
local function diag(x: number, y: number, z: number): M3
	return { { x, 0, 0 }, { 0, y, 0 }, { 0, 0, z } }
end

-- canonical unit vertex sets (local coords, +-0.5). Wedge: Roblox profile in YZ, extruded along X.
-- CornerWedge: base y=-0.5 full rectangle, apex at (sx*0.5, 0.5, sz*0.5); ASSUMED (S2 to confirm vs Roblox).
local function verts(shape: string, apexSx: number, apexSz: number): { V3 }
	local h = 0.5
	if shape == "Block" then
		local t = {}
		for _, x in { -h, h } do
			for _, y in { -h, h } do
				for _, z in { -h, h } do
					table.insert(t, { x, y, z })
				end
			end
		end
		return t
	elseif shape == "Wedge" then
		return { { -h, -h, -h }, { h, -h, -h }, { -h, -h, h }, { h, -h, h }, { -h, h, h }, { h, h, h } }
	elseif shape == "CornerWedge" then
		return { { -h, -h, -h }, { h, -h, -h }, { -h, -h, h }, { h, -h, h }, { apexSx * h, h, apexSz * h } }
	end
	error("shape")
end

-- local reflection T (det -1) and size permutation for each shape; n = mirror normal axis index (1=x, 3=z)
local function localReflection(shape: string, n: number, sigma: number): (M3, { number })
	if shape == "Block" or shape == "Ball" or shape == "Cylinder" then
		local d = { 1, 1, 1 }
		d[n] = -1
		return diag(d[1], d[2], d[3]), { 1, 2, 3 } -- R' = S R S (conjugation)
	elseif shape == "Wedge" then
		return diag(-1, 1, 1), { 1, 2, 3 } -- only local X flip is a symmetry
	elseif shape == "CornerWedge" then
		return { { 0, 0, sigma }, { 0, 1, 0 }, { sigma, 0, 0 } }, { 3, 2, 1 } -- swap X/Z sizes
	end
	error("shape")
end

local function rotFromAxisAngle(ax: V3, ang: number): M3
	local n = math.sqrt(ax[1] ^ 2 + ax[2] ^ 2 + ax[3] ^ 2)
	local x, y, z = ax[1] / n, ax[2] / n, ax[3] / n
	local c, s, t = math.cos(ang), math.sin(ang), 1 - math.cos(ang)
	return {
		{ t * x * x + c, t * x * y - s * z, t * x * z + s * y },
		{ t * x * y + s * z, t * y * y + c, t * y * z - s * x },
		{ t * x * z - s * y, t * y * z + s * x, t * z * z + c },
	}
end

type Part = { shape: string, R: M3, p: V3, s: V3 }

local function worldVerts(part: Part, sx: number, sz: number): { V3 }
	local out = {}
	for _, v in verts(part.shape, sx, sz) do
		local scaled = { v[1] * part.s[1], v[2] * part.s[2], v[3] * part.s[3] }
		local w = mv(part.R, scaled)
		table.insert(out, { w[1] + part.p[1], w[2] + part.p[2], w[3] + part.p[3] })
	end
	return out
end

local function mirror(part: Part, n: number, sigma: number): Part
	local S = diag(1, 1, 1)
	S[n][n] = -1
	local T, perm = localReflection(part.shape, n, sigma)
	local R2 = mmul(mmul(S, part.R), T)
	local s2 = { part.s[perm[1]], part.s[perm[2]], part.s[perm[3]] }
	local p2 = mv(S, part.p)
	return { shape = part.shape, R = R2, p = p2, s = s2 }
end

local function sameSet(a: { V3 }, b: { V3 }): number -- max matching error (greedy nearest)
	local used = {}
	local maxE = 0
	for _, v in a do
		local best, bi = math.huge, 0
		for j, w in b do
			if not used[j] then
				local e = math.abs(v[1] - w[1]) + math.abs(v[2] - w[2]) + math.abs(v[3] - w[3])
				if e < best then
					best, bi = e, j
				end
			end
		end
		used[bi] = true
		maxE = math.max(maxE, best)
	end
	return maxE
end

local seed = 777
local function rnd(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

for _, apex in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
	local sx, sz = apex[1], apex[2]
	local sigma = sx * sz
	local worst = { Block = 0, Wedge = 0, CornerWedge = 0 }
	local worstTwice = 0
	local dets = 0
	for _ = 1, 5000 do
		for _, shape in { "Block", "Wedge", "CornerWedge" } do
			local R = rotFromAxisAngle({ rnd() - 0.5, rnd() - 0.5, rnd() - 0.5 }, rnd() * 2 * math.pi)
			local part: Part = { shape = shape, R = R, p = { rnd() - 0.5, rnd() * 4, rnd() - 0.5 }, s = { 0.1 + rnd(), 0.1 + rnd() * 2, 0.05 + rnd() * 0.3 } }
			for _, n in { 1, 3 } do
				local m = mirror(part, n, sigma)
				if math.abs(det(m.R) - 1) > 1e-9 then
					dets += 1
				end
				-- reflected original vertices
				local refl = {}
				for _, v in worldVerts(part, sx, sz) do
					local r = { v[1], v[2], v[3] }
					r[n] = -r[n]
					table.insert(refl, r)
				end
				local e = sameSet(refl, worldVerts(m, sx, sz))
				worst[shape] = math.max(worst[shape], e)
				local mm = mirror(m, n, sigma)
				local e2 = sameSet(worldVerts(part, sx, sz), worldVerts(mm, sx, sz))
				worstTwice = math.max(worstTwice, e2)
			end
		end
	end
	print(string.format("apex corner (%+d,%+d) sigma=%+d: max vertex error Block %.1e Wedge %.1e CornerWedge %.1e | mirror twice %.1e | improper results %d",
		sx, sz, sigma, worst.Block, worst.Wedge, worst.CornerWedge, worstTwice, dets))
end

-- show the "tidy" property: a part rotated +30 deg about Z mirrored across X becomes -30 deg about Z
local R30 = rotFromAxisAngle({ 0, 0, 1 }, math.rad(30))
local m = mirror({ shape = "Block", R = R30, p = { 0.4, 1, 0 }, s = { 0.2, 1, 0.1 } }, 1, 1)
local angle = math.deg(math.atan2(m.R[2][1], m.R[1][1]))
print(string.format("Block rotZ(+30) at x=+0.4 mirrored across x=0 -> rotZ(%.1f) at x=%.1f", angle, m.p[1]))
-- wrong sigma check (shows the dependency on S2's canonical apex)
local part: Part = { shape = "CornerWedge", R = diag(1, 1, 1), p = { 0.3, 1, 0 }, s = { 0.4, 0.5, 0.2 } }
local mBad = mirror(part, 1, -1)
local refl = {}
for _, v in worldVerts(part, 1, -1) do
	table.insert(refl, { -v[1], v[2], v[3] })
end
print(string.format("CornerWedge with apex (+1,-1) but sigma=-(+1)? using sigma=-1 correct: err %.2e ; using sigma=+1 (wrong): err %.2e",
	sameSet(refl, worldVerts(mBad, 1, -1)), sameSet(refl, worldVerts(mirror(part, 1, 1), 1, -1))))
