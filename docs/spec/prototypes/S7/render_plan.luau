--!strict
-- Throwaway S7 prototype of the pure RenderPlan (blueprint -> render primitives) + checks.
-- Run: lune run render_plan.luau
local V = require("./vecmath")

-- ------------------------------------------------------------------ inputs (assumed S1/S2 shape)
type BpPart = {
	shape: string,
	slot: string,
	material: string,
	pos: { number }, -- blueprint space, studs
	rot: { number }, -- unit quaternion {w,x,y,z}
	size: { number }, -- canonical size; Cylinder canonical axis = local +Y (assumption), Ball may be non-uniform
}

local MATERIALS = { -- proposed render values (S1 owns them)
	Iron = { color = { 112, 114, 120 }, material = "Metal", reflectance = 0.05 },
	Steel = { color = { 196, 202, 210 }, material = "Metal", reflectance = 0.18 },
}

local s45 = math.sqrt(0.5)
local function qz(deg: number): { number }
	local a = math.rad(deg) / 2
	return { math.cos(a), 0, 0, math.sin(a) }
end
local REF_SWORD: { BpPart } = {
	{ shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0, -0.65, 0 }, rot = { 1, 0, 0, 0 }, size = { 0.24, 1.1, 0.24 } },
	{ shape = "Ball", slot = "Pommel", material = "Iron", pos = { 0, -1.33, 0 }, rot = { 1, 0, 0, 0 }, size = { 0.36, 0.36, 0.36 } },
	{ shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 0, 0 }, rot = { 1, 0, 0, 0 }, size = { 1.3, 0.18, 0.3 } },
	{ shape = "CornerWedge", slot = "Guard", material = "Iron", pos = { 0.74, 0.0, 0 }, rot = qz(30), size = { 0.2, 0.2, 0.2 } },
	{ shape = "Block", slot = "Blade", material = "Steel", pos = { 0, 1.59, 0 }, rot = { 1, 0, 0, 0 }, size = { 0.26, 3.0, 0.07 } },
	{ shape = "Wedge", slot = "Blade", material = "Steel", pos = { -0.065, 3.315, 0 }, rot = { s45, 0, s45, 0 }, size = { 0.07, 0.45, 0.13 } },
	{ shape = "Wedge", slot = "Blade", material = "Steel", pos = { 0.065, 3.315, 0 }, rot = { s45, 0, -s45, 0 }, size = { 0.07, 0.45, 0.13 } },
	-- an ellipsoid to exercise the SpecialMesh path, tilted
	{ shape = "Ball", slot = "Guard", material = "Steel", pos = { -0.74, 0, 0 }, rot = qz(-20), size = { 0.3, 0.16, 0.16 } },
}

-- ------------------------------------------------------------------ shape table (render mapping)
local RZ90 = { 0, -1, 0, 1, 0, 0, 0, 0, 1 } -- exact Rz(+90deg): local X -> +Y
local SHAPE = {
	Block = { partType = "Block", pre = V.I, perm = function(s: { number }) return { s[1], s[2], s[3] } end },
	Wedge = { partType = "Wedge", pre = V.I, perm = function(s: { number }) return { s[1], s[2], s[3] } end },
	CornerWedge = { partType = "CornerWedge", pre = V.I, perm = function(s: { number }) return { s[1], s[2], s[3] } end },
	Cylinder = { partType = "Cylinder", pre = RZ90, perm = function(s: { number }) return { s[2], s[1], s[3] } end },
	Ball = { partType = "Ball", pre = V.I, perm = function(s: { number }) return { s[1], s[2], s[3] } end },
}

-- exact (Ball/Cylinder/Wedge) or conservative-box (Block/CornerWedge) AABB of one canonical part
local function partAabb(p: BpPart): ({ number }, { number })
	local R = V.fromQuat(p.rot[1], p.rot[2], p.rot[3], p.rot[4])
	local hx, hy, hz = p.size[1] / 2, p.size[2] / 2, p.size[3] / 2
	local mn, mx = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	local function acc(v: { number })
		local w = V.add(p.pos, V.mapply(R, v))
		for i = 1, 3 do
			mn[i] = math.min(mn[i], w[i])
			mx[i] = math.max(mx[i], w[i])
		end
	end
	if p.shape == "Ball" then
		for i = 1, 3 do
			-- ellipsoid extent along world axis i = sqrt(sum_j (R_ij a_j)^2)
			local e = math.sqrt((R[(i - 1) * 3 + 1] * hx) ^ 2 + (R[(i - 1) * 3 + 2] * hy) ^ 2 + (R[(i - 1) * 3 + 3] * hz) ^ 2)
			mn[i] = p.pos[i] - e
			mx[i] = p.pos[i] + e
		end
	elseif p.shape == "Cylinder" then
		local a = V.col(R, 2) -- canonical axis +Y
		local r = hx -- circular: size.x = size.z = diameter
		for i = 1, 3 do
			local e = math.abs(a[i]) * hy + r * math.sqrt(math.max(0, 1 - a[i] * a[i]))
			mn[i] = p.pos[i] - e
			mx[i] = p.pos[i] + e
		end
	elseif p.shape == "Wedge" then
		for _, v in { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { -hx, hy, hz }, { hx, hy, hz } } do
			acc(v)
		end
	else -- Block, CornerWedge (conservative)
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					acc({ sx * hx, sy * hy, sz * hz })
				end
			end
		end
	end
	return mn, mx
end

type Prim = { slot: string, shape: string, partType: string, sphereMesh: boolean, size: { number }, cf: { number }, color: { number }, material: string, reflectance: number }
type Plan = { prims: { Prim }, aabbMin: { number }, aabbMax: { number }, anchor: { number }, scale: number }

local MAX_RENDER_PARTS = 64

local function buildPlan(parts: { BpPart }, anchorMode: string, scale: number): Plan?
	if #parts == 0 or #parts > MAX_RENDER_PARTS then
		return nil
	end
	local mn, mx = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, p in parts do
		local a, b = partAabb(p)
		for i = 1, 3 do
			mn[i] = math.min(mn[i], a[i])
			mx[i] = math.max(mx[i], b[i])
		end
	end
	local anchor
	if anchorMode == "BaseCenter" then
		anchor = { (mn[1] + mx[1]) / 2, mn[2], (mn[3] + mx[3]) / 2 }
	elseif anchorMode == "Center" then
		anchor = { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
	else
		anchor = { 0, 0, 0 }
	end
	local prims = {}
	for _, p in parts do
		local sh = SHAPE[p.shape]
		local R = V.mmul(V.fromQuat(p.rot[1], p.rot[2], p.rot[3], p.rot[4]), sh.pre)
		local pos = V.scale(V.sub(p.pos, anchor), scale)
		local size = V.scale(sh.perm(p.size), scale)
		local uniform = p.shape ~= "Ball" or (p.size[1] == p.size[2] and p.size[2] == p.size[3])
		local m = MATERIALS[p.material]
		table.insert(prims, {
			slot = p.slot,
			shape = p.shape,
			partType = uniform and sh.partType or "Block",
			sphereMesh = not uniform,
			size = size,
			cf = { pos[1], pos[2], pos[3], R[1], R[2], R[3], R[4], R[5], R[6], R[7], R[8], R[9] },
			color = m.color,
			material = m.material,
			reflectance = m.reflectance,
		})
	end
	return { prims = prims, aabbMin = mn, aabbMax = mx, anchor = anchor, scale = scale }
end

-- ------------------------------------------------------------------ checks
print("==================== A. reference sword plan ====================")
local plan = buildPlan(REF_SWORD, "BaseCenter", 1) :: Plan
print(string.format("parts %d  AABB min %s max %s  size %s", #plan.prims, V.fmt(plan.aabbMin), V.fmt(plan.aabbMax), V.fmt(V.sub(plan.aabbMax, plan.aabbMin))))
print("anchor (BaseCenter) " .. V.fmt(plan.anchor))
for i, p in plan.prims do
	print(string.format("  %d %-7s %-11s -> Part.Shape=%-11s mesh=%-5s Size=%s pos=%s", i, p.slot, p.shape, p.partType, tostring(p.sphereMesh), V.fmt(p.size), V.fmt({ p.cf[1], p.cf[2], p.cf[3] })))
end

print("==================== B. cylinder mapping (canonical +Y axis -> Roblox X axis) ====================")
do
	-- tilted grip: 35 deg about Z then 20 about X
	local q1 = qz(35)
	local Rq = V.mmul(V.rotX(20), V.fromQuat(q1[1], q1[2], q1[3], q1[4]))
	local canonAxis = V.col(Rq, 2)
	local robloxR = V.mmul(Rq, RZ90)
	local robloxAxis = V.col(robloxR, 1) -- Roblox cylinder axis = Part local X
	print(string.format("  canonical axis %s, rendered Roblox X axis %s, |diff| = %.2e, det(Rz90)=%.1f", V.fmt(canonAxis), V.fmt(robloxAxis), V.len(V.sub(canonAxis, robloxAxis)), V.det(RZ90)))
	-- AABB closed form vs brute force sampling of the cylinder surface
	local cyl: BpPart = { shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0.3, -0.2, 0.1 }, rot = { 1, 0, 0, 0 }, size = { 0.24, 1.1, 0.24 } }
	-- encode Rq as quaternion via brute force: just test the formula with Rq directly
	local mnF, mxF = { 0, 0, 0 }, { 0, 0, 0 }
	local a = canonAxis
	for i = 1, 3 do
		local e = math.abs(a[i]) * 0.55 + 0.12 * math.sqrt(1 - a[i] * a[i])
		mnF[i] = cyl.pos[i] - e
		mxF[i] = cyl.pos[i] + e
	end
	local mnB, mxB = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	local u = V.col(Rq, 1)
	local w = V.col(Rq, 3)
	for k = 0, 3600 do
		local t = 2 * math.pi * k / 3600
		for _, hs in { -0.55, 0.55 } do
			local pnt = V.add(cyl.pos, V.add(V.scale(a, hs), V.add(V.scale(u, 0.12 * math.cos(t)), V.scale(w, 0.12 * math.sin(t)))))
			for i = 1, 3 do
				mnB[i] = math.min(mnB[i], pnt[i])
				mxB[i] = math.max(mxB[i], pnt[i])
			end
		end
	end
	local err = 0
	for i = 1, 3 do
		err = math.max(err, math.abs(mnF[i] - mnB[i]), math.abs(mxF[i] - mxB[i]))
	end
	print(string.format("  rotated-cylinder AABB closed form vs 7202-point sampling: max |diff| = %.2e studs", err))
end

print("==================== C. display placement on a stand ====================")
do
	-- stand on plot 3 (yaw 90) slot 4; cradle at stand-local (0,1.55,0); display rotation Ry(180)
	local R = 86
	local phi = 2 * 45
	local plotXf = V.xf(V.v(R * math.sin(math.rad(phi)), 0, R * math.cos(math.rad(phi))), V.rotY(phi))
	local standXf = V.compose(plotXf, V.xf(V.v(3.5, 0.5, -9), V.I))
	local cradle = V.compose(standXf, V.xf(V.v(0, 1.55, 0), V.I))
	local RY180 = { -1, 0, 0, 0, 1, 0, 0, 0, -1 }
	local pivot = V.compose(cradle, V.xf(V.v(0, 0, 0), RY180))
	local minY = math.huge
	for _, pr in plan.prims do
		local c = pr.cf
		local partXf = V.compose(pivot, V.xf({ c[1], c[2], c[3] }, { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }))
		local h = V.scale(pr.size, 0.5)
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local wpt = V.point(partXf, V.v(sx * h[1], sy * h[2], sz * h[3]))
					minY = math.min(minY, wpt[2])
				end
			end
		end
	end
	local bpZ = V.mapply(pivot.r, { 0, 0, 1 })
	local bpY = V.mapply(pivot.r, { 0, 1, 0 })
	local standLook = V.look(standXf)
	print(string.format("  cradle world y %.3f, lowest box corner of any rendered part %.3f (box-corner bound; true min = cradle)", cradle.p[2], minY))
	print(string.format("  blueprint +Z -> %s, stand LookVector (towards plaza) %s, dot=%.3f ; blueprint +Y -> %s", V.fmt(bpZ), V.fmt(standLook), V.dot(bpZ, standLook), V.fmt(bpY)))
end

print("==================== D. viewport fit ====================")
local function fitDistance(ex: number, ey: number, ez: number, fovDeg: number, aspect: number, margin: number): number
	local tv = math.tan(math.rad(fovDeg) / 2)
	local th = tv * aspect
	return ez + margin * math.max(ex / th, ey / tv)
end
local sz = V.sub(plan.aabbMax, plan.aabbMin)
-- horizontal presentation: blueprint Y -> screen X ; blueprint X -> screen Y ; blueprint Z -> towards camera
for _, case in { { "results card 16:9", 16 / 9, 30 }, { "inspect panel 4:3", 4 / 3, 30 }, { "inventory tile 1:1", 1, 30 }, { "inspect panel 4:3 fov 40", 4 / 3, 40 } } do
	local ex, ey, ez = sz[2] / 2, sz[1] / 2, sz[3] / 2
	local d = fitDistance(ex, ey, ez, case[3], case[2], 1.08)
	-- verify by projecting the AABB corners
	local tv = math.tan(math.rad(case[3]) / 2)
	local th = tv * case[2]
	local maxNx, maxNy = 0, 0
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz2 = -1, 1, 2 do
				local depth = d - sz2 * ez
				maxNx = math.max(maxNx, math.abs(sx * ex) / depth / th)
				maxNy = math.max(maxNy, math.abs(sy * ey) / depth / tv)
			end
		end
	end
	print(string.format("  %-26s fov %d: camera distance %.2f studs; max |NDC| x %.3f y %.3f (target 1/1.08 = %.3f)", case[1], case[3], d, maxNx, maxNy, 1 / 1.08))
end

print("==================== E. budgets ====================")
local SLOTS, PLOTS = 6, 8
local perItemFx = { Common = 0, Uncommon = 0, Rare = 1, Epic = 2, Legendary = 3, Mythic = 3, Divine = 3 }
print(string.format("  worst-case displayed item parts: %d plots x %d slots x %d parts = %d (+%d inspect hitboxes)", PLOTS, SLOTS, MAX_RENDER_PARTS, PLOTS * SLOTS * MAX_RENDER_PARTS, PLOTS * SLOTS))
print(string.format("  worst-case rarity FX instances (MVP cap Epic): %d lights + %d emitters", PLOTS * SLOTS, PLOTS * SLOTS))
print(string.format("  per-item FX instance counts by rarity: Common %d Uncommon %d Rare %d Epic %d Legendary+ %d", perItemFx.Common, perItemFx.Uncommon, perItemFx.Rare, perItemFx.Epic, perItemFx.Legendary))
-- particles alive per emitter: rate * mean lifetime
for _, r in { { "Epic", 3, 1.1 }, { "Legendary", 5, 1.2 }, { "Mythic", 7, 1.3 }, { "Divine", 9, 1.4 } } do
	print(string.format("  %-9s sparkles: rate %d/s x mean life %.1fs = %.1f live particles per item", r[1], r[2], r[3], r[2] * r[3]))
end
