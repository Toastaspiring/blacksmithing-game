--!strict
-- Throwaway S7 prototype v2: RenderPlan against S2's conventions (Roblox-native shapes, quaternion {w,x,y,z},
-- blueprint origin = bottom-centre of the hitbox x[-0.8,0.8] y[0,5] z[-0.3,0.3]) using S2's arming sword.
-- Run: lune run render_plan_native.luau
local V = require("./vecmath")

local function qAxis(ax: number, ay: number, az: number, deg: number): { number }
	local a = math.rad(deg) / 2
	local s = math.sin(a)
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return { math.cos(a), ax / n * s, ay / n * s, az / n * s }
end
local ID = { 1, 0, 0, 0 }
local RZ90 = qAxis(0, 0, 1, 90)
local RY_M90 = qAxis(0, 1, 0, -90)
local RY_P90 = qAxis(0, 1, 0, 90)

type BpPart = { shape: string, slot: string, material: string, pos: { number }, rot: { number }, size: { number } }
local ARMING: { BpPart } = { -- = S2 proto Swords.arming("Iron") with a Steel blade
	{ shape = "Ball", slot = "Pommel", material = "Iron", pos = { 0, 0.30, 0 }, rot = ID, size = { 0.30, 0.30, 0.30 } },
	{ shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0, 0.88, 0 }, rot = RZ90, size = { 0.90, 0.16, 0.16 } },
	{ shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 1.40, 0 }, rot = ID, size = { 1.10, 0.16, 0.24 } },
	{ shape = "Block", slot = "Blade", material = "Steel", pos = { 0, 2.65, 0 }, rot = ID, size = { 0.20, 2.50, 0.06 } },
	{ shape = "Wedge", slot = "Blade", material = "Steel", pos = { 0.05, 4.10, 0 }, rot = RY_M90, size = { 0.06, 0.40, 0.10 } },
	{ shape = "Wedge", slot = "Blade", material = "Steel", pos = { -0.05, 4.10, 0 }, rot = RY_P90, size = { 0.06, 0.40, 0.10 } },
}

-- exact AABB per shape, S2 geometry: Wedge = Block AND z/hz >= y/hy ; CornerWedge apex (+hx,+hy,-hz);
-- Cylinder axis local X radius min(hy,hz); Ball radius min(hx,hy,hz)
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
		local r = math.min(hx, hy, hz)
		for i = 1, 3 do
			mn[i], mx[i] = p.pos[i] - r, p.pos[i] + r
		end
	elseif p.shape == "Cylinder" then
		local a = V.col(R, 1)
		local r = math.min(hy, hz)
		for i = 1, 3 do
			local e = math.abs(a[i]) * hx + r * math.sqrt(math.max(0, 1 - a[i] * a[i]))
			mn[i], mx[i] = p.pos[i] - e, p.pos[i] + e
		end
	elseif p.shape == "Wedge" then
		for _, v in { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { -hx, hy, hz }, { hx, hy, hz } } do
			acc(v)
		end
	elseif p.shape == "CornerWedge" then
		for _, v in { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, -hz } } do
			acc(v)
		end
	else
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

local mn, mx = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
local bladeMn, bladeMx = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
for _, p in ARMING do
	local a, b = partAabb(p)
	for i = 1, 3 do
		mn[i], mx[i] = math.min(mn[i], a[i]), math.max(mx[i], b[i])
		if p.slot == "Blade" then
			bladeMn[i], bladeMx[i] = math.min(bladeMn[i], a[i]), math.max(bladeMx[i], b[i])
		end
	end
end
local size = V.sub(mx, mn)
print(string.format("arming sword (S2 fixture): AABB min %s max %s size %s", V.fmt(mn), V.fmt(mx), V.fmt(size)))
print(string.format("Blade-slot AABB min %s max %s", V.fmt(bladeMn), V.fmt(bladeMx)))
-- check the wedge tip apex: highest wedge vertex must be the point on the centre line
do
	local p = ARMING[5]
	local R = V.fromQuat(p.rot[1], p.rot[2], p.rot[3], p.rot[4])
	local hx, hy, hz = p.size[1] / 2, p.size[2] / 2, p.size[3] / 2
	local top = V.add(p.pos, V.mapply(R, { 0, hy, hz }))
	print(string.format("right tip wedge: top edge midpoint (local (0,+hy,+hz)) -> %s (expect x = 0, y = 4.30)", V.fmt(top)))
end
local anchor = { (mn[1] + mx[1]) / 2, mn[2], (mn[3] + mx[3]) / 2 }
print("BaseCenter anchor " .. V.fmt(anchor) .. string.format("  -> item top above cradle = %.2f studs", mx[2] - mn[2]))

-- display on stand: cradle at plot y 2.05 -> item top at 2.05 + height
print(string.format("on a stand: item spans plot y %.2f .. %.2f", 2.05, 2.05 + size[2]))
-- InspectHitbox = AABB + 2*0.3 pad, min thickness 0.8
local hb = { size[1] + 0.6, size[2] + 0.6, math.max(size[3] + 0.6, 0.8) }
print("InspectHitbox size " .. V.fmt(hb))
-- worst case hitbox-filling item
print(string.format("max item (= S2 hitbox 1.6 x 5 x 0.6): top at plot y %.2f, InspectHitbox %s", 2.05 + 5, V.fmt({ 2.2, 5.6, 1.2 })))

-- viewport fits for this item, horizontal presentation (blueprint Y -> screen X)
local function fit(ex: number, ey: number, ez: number, fov: number, aspect: number, m: number): number
	local tv = math.tan(math.rad(fov) / 2)
	return ez + m * math.max(ex / (tv * aspect), ey / tv)
end
for _, c in { { "results card 16:9", 16 / 9 }, { "inspect panel 4:3", 4 / 3 }, { "inventory tile 1:1", 1 } } do
	print(string.format("  %-20s FOV 30, margin 1.08: camera distance %.2f studs", c[1], fit(size[2] / 2, size[1] / 2, size[3] / 2, 30, c[2], 1.08)))
end
-- workpiece lying flat on the anvil: rotation FLAT_X (blueprint Y -> station +X, Z -> up, X -> +Z)
local FLAT = { 0, 1, 0, 0, 0, 1, 1, 0, 0 }
print(string.format("FLAT_X det = %.1f ; blueprint Y -> %s, Z -> %s, X -> %s", V.det(FLAT), V.fmt(V.mapply(FLAT, { 0, 1, 0 })), V.fmt(V.mapply(FLAT, { 0, 0, 1 })), V.fmt(V.mapply(FLAT, { 1, 0, 0 }))))
print(string.format("lying on the anvil face (top y 3.0 station-local): Center pivot at y = 3.0 + %.3f; overhang beyond the 2.4-stud face: %.2f studs", size[3] / 2, size[2] - 2.4))
local VH = { 0, 1, 0, -1, 0, 0, 0, 0, 1 }
print(string.format("VIEW_H (Rz -90) det = %.1f ; blueprint Y -> %s (screen right), Z -> %s (to camera)", V.det(VH), V.fmt(V.mapply(VH, { 0, 1, 0 })), V.fmt(V.mapply(VH, { 0, 0, 1 }))))
print(string.format("budget: %d plots x %d slots x PARTS_MAX %d = %d item parts (+48 hitboxes); workpieces 8 x 24 = 192", 8, 6, 24, 8 * 6 * 24))
