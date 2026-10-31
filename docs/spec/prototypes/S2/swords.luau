--!strict
-- S2 prototype: example sword blueprints (blueprint space: origin = bottom-centre of the hitbox,
-- +Y along the blade, +X across the guard, +Z through the thickness; hitbox x in [-0.8,0.8], y in [0,5], z in [-0.3,0.3]).
-- Builders use cos/sin (prototype only: the editor produces quaternions, the analysis never calls trig).
local Swords = {}

local function qAxis(ax: number, ay: number, az: number, deg: number): { number }
	local a = math.rad(deg) / 2
	local s = math.sin(a)
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return { math.cos(a), ax / n * s, ay / n * s, az / n * s }
end
Swords.qAxis = qAxis

local function qmul(a: { number }, b: { number }): { number }
	local w1, x1, y1, z1 = a[1], a[2], a[3], a[4]
	local w2, x2, y2, z2 = b[1], b[2], b[3], b[4]
	return {
		w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
		w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
		w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
		w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
	}
end
Swords.qmul = qmul

local function qrot(q: { number }, x: number, y: number, z: number): (number, number, number)
	local w, qx, qy, qz = q[1], q[2], q[3], q[4]
	local ux = 1 - 2 * (qy * qy + qz * qz)
	local uy = 2 * (qx * qy + w * qz)
	local uz = 2 * (qx * qz - w * qy)
	local vx = 2 * (qx * qy - w * qz)
	local vy = 1 - 2 * (qx * qx + qz * qz)
	local vz = 2 * (qy * qz + w * qx)
	local wx = 2 * (qx * qz + w * qy)
	local wy = 2 * (qy * qz - w * qx)
	local wz = 1 - 2 * (qx * qx + qy * qy)
	return x * ux + y * vx + z * wx, x * uy + y * vy + z * wy, x * uz + y * vz + z * wz
end
Swords.qrot = qrot

local ID = { 1, 0, 0, 0 }
local RZ90 = qAxis(0, 0, 1, 90) -- cylinder axis (local X) -> world +Y
local RY_M90 = qAxis(0, 1, 0, -90) -- wedge: local X -> world +Z (thickness), high side (+Z local) -> world -X
local RY_P90 = qAxis(0, 1, 0, 90) -- wedge: local X -> world -Z, high side -> world +X
Swords.RZ90, Swords.RY_M90, Swords.RY_P90 = RZ90, RY_M90, RY_P90

local function part(id, shape, slot, mat, pos, rot, size)
	return { id = id, shape = shape, slot = slot, material = mat, pos = pos, rot = rot, size = size }
end
Swords.part = part

-- ---------------------------------------------------------------- mirror tool (pure, no negative scale)
-- Mirror across the plane x = x0. Block/Wedge/Cylinder/Ball: q' = (w, x, -y, -z), size unchanged.
-- CornerWedge: q' = (w, x, -y, -z) * qY(+90deg), size (sx,sy,sz) -> (sz,sy,sx).
local SQRT_HALF = math.sqrt(0.5)
function Swords.mirrorX(p: any, x0: number, newId: string): any
	local q = p.rot
	local qm = { q[1], q[2], -q[3], -q[4] }
	local size = { p.size[1], p.size[2], p.size[3] }
	if p.shape == "CornerWedge" then
		qm = qmul(qm, { SQRT_HALF, 0, SQRT_HALF, 0 })
		size = { p.size[3], p.size[2], p.size[1] }
	end
	return part(newId, p.shape, p.slot, p.material, { 2 * x0 - p.pos[1], p.pos[2], p.pos[3] }, qm, size)
end

-- transform a whole blueprint: rotate by q about pivot, then translate
function Swords.transform(bp: any, name: string, q: { number }, pivot: { number }, d: { number }): any
	local out = { name = name, parts = {} }
	for _, p in ipairs(bp.parts) do
		local rx, ry, rz = qrot(q, p.pos[1] - pivot[1], p.pos[2] - pivot[2], p.pos[3] - pivot[3])
		table.insert(out.parts, part(p.id, p.shape, p.slot, p.material, { pivot[1] + rx + d[1], pivot[2] + ry + d[2], pivot[3] + rz + d[3] }, qmul(q, p.rot), p.size))
	end
	return out
end

local function tipPair(prefix, mat, baseY, halfW, h, t)
	local r = part(prefix .. "TipR", "Wedge", "Blade", mat, { halfW / 2, baseY + h / 2, 0 }, RY_M90, { t, h, halfW })
	local l = Swords.mirrorX(r, 0, prefix .. "TipL")
	return r, l
end

function Swords.arming(mat: string?): any
	local m = mat or "Iron"
	local tr, tl = tipPair("", m, 3.90, 0.10, 0.40, 0.06)
	return {
		name = "Arming sword (" .. m .. ")",
		parts = {
			part("Pommel", "Ball", "Pommel", m, { 0, 0.30, 0 }, ID, { 0.30, 0.30, 0.30 }),
			part("Grip", "Cylinder", "Grip", m, { 0, 0.88, 0 }, RZ90, { 0.90, 0.16, 0.16 }),
			part("Guard", "Block", "Guard", m, { 0, 1.40, 0 }, ID, { 1.10, 0.16, 0.24 }),
			part("Blade", "Block", "Blade", m, { 0, 2.65, 0 }, ID, { 0.20, 2.50, 0.06 }),
			tr,
			tl,
		},
	}
end

function Swords.minimal(): any
	return {
		name = "Minimal 4-part (Iron)",
		parts = {
			part("Pommel", "Block", "Pommel", "Iron", { 0, 0.35, 0 }, ID, { 0.30, 0.30, 0.30 }),
			part("Grip", "Block", "Grip", "Iron", { 0, 1.00, 0 }, ID, { 0.20, 1.00, 0.20 }),
			part("Guard", "Block", "Guard", "Iron", { 0, 1.60, 0 }, ID, { 1.00, 0.20, 0.30 }),
			part("Blade", "Block", "Blade", "Iron", { 0, 2.90, 0 }, ID, { 0.25, 2.40, 0.10 }),
		},
	}
end

function Swords.rapier(): any
	local tr, tl = tipPair("", "Steel", 4.60, 0.045, 0.30, 0.05)
	return {
		name = "Rapier (Steel blade)",
		parts = {
			part("Pommel", "Ball", "Pommel", "Iron", { 0, 0.25, 0 }, ID, { 0.26, 0.26, 0.26 }),
			part("Grip", "Cylinder", "Grip", "Iron", { 0, 0.77, 0 }, RZ90, { 0.80, 0.14, 0.14 }),
			part("Cross", "Block", "Guard", "Steel", { 0, 1.21, 0 }, ID, { 0.70, 0.10, 0.12 }),
			part("Cup", "Cylinder", "Guard", "Steel", { 0, 1.285, 0 }, RZ90, { 0.05, 0.44, 0.44 }),
			part("Blade", "Block", "Blade", "Steel", { 0, 2.95, 0 }, ID, { 0.09, 3.30, 0.05 }),
			tr,
			tl,
		},
	}
end

function Swords.cleaver(): any
	return {
		name = "Cleaver (Iron)",
		parts = {
			part("Pommel", "Block", "Pommel", "Iron", { 0, 0.32, 0 }, ID, { 0.30, 0.24, 0.30 }),
			part("Grip", "Cylinder", "Grip", "Iron", { 0, 0.89, 0 }, RZ90, { 0.92, 0.20, 0.20 }),
			part("Guard", "Block", "Guard", "Iron", { 0, 1.41, 0 }, ID, { 0.60, 0.14, 0.30 }),
			part("Blade", "Block", "Blade", "Iron", { 0.25, 2.58, 0 }, ID, { 1.00, 2.20, 0.14 }),
			part("Spine", "Block", "Blade", "Iron", { -0.31, 2.58, 0 }, ID, { 0.12, 2.20, 0.22 }),
			part("Top", "Wedge", "Blade", "Iron", { 0.19, 3.88, 0 }, RY_P90, { 0.14, 0.40, 1.12 }),
		},
	}
end

-- curved sabre: 5 blade segments rotated about Z, plus a 2-wedge tip rotated with the last segment
function Swords.sabre(): any
	local parts = {
		part("Pommel", "Ball", "Pommel", "Iron", { 0, 0.30, 0 }, ID, { 0.28, 0.28, 0.28 }),
		part("Grip", "Cylinder", "Grip", "Iron", { 0, 0.87, 0 }, RZ90, { 0.88, 0.16, 0.16 }),
		part("Guard", "Block", "Guard", "Steel", { 0, 1.38, 0 }, ID, { 0.80, 0.14, 0.22 }),
	}
	local bx, by = 0, 1.40
	local angles = { 2, 5, 8, 11, 14 }
	local L, step = 0.62, 0.58
	local lastQ, endX, endY = ID, 0, 0
	for k, a in ipairs(angles) do
		local q = qAxis(0, 0, 1, a)
		local dx, dy = qrot(q, 0, 1, 0)
		table.insert(parts, part("Seg" .. k, "Block", "Blade", "Steel", { bx + dx * L / 2, by + dy * L / 2, 0 }, q, { 0.18, L, 0.06 }))
		endX, endY = bx + dx * L, by + dy * L
		bx, by = bx + dx * step, by + dy * step
		lastQ = q
	end
	-- tip pair in the last segment's frame, base at the segment's end
	local h, hw = 0.36, 0.09
	for s = -1, 1, 2 do
		local local_ = if s > 0 then RY_M90 else RY_P90
		local ox, oy = qrot(lastQ, s * hw / 2, h / 2, 0)
		table.insert(parts, part(if s > 0 then "TipR" else "TipL", "Wedge", "Blade", "Steel", { endX + ox, endY + oy, 0 }, qmul(lastQ, local_), { 0.06, h, hw }))
	end
	return { name = "Curved sabre (Steel)", parts = parts }
end

-- minimal sword stuffed to the 24-part cap with filler: 10 blade studs, 6 guard studs (0.09 cubes, half embedded),
-- 2 blocks hidden inside the pommel, 2 dust specks on the grip. symmetric=false puts every stud on the +X side.
function Swords.gamey(symmetric: boolean): any
	local bp = Swords.minimal()
	bp.name = if symmetric then "Gamey filler, symmetric (24 parts)" else "Gamey filler, lopsided (24 parts)"
	local k = 0
	for i = 0, 4 do
		local y = 1.95 + i * 0.45
		local zf = if i % 2 == 0 then 0.05 else -0.05
		for s = -1, 1, 2 do
			k += 1
			local x = if symmetric then s * 0.06 else 0.06
			local yy = if symmetric then y else y + (s + 1) * 0.11
			table.insert(bp.parts, part("Stud" .. k, "Block", "Blade", "Iron", { x, yy, zf }, ID, { 0.09, 0.09, 0.09 }))
		end
	end
	for i = 1, 3 do
		for s = -1, 1, 2 do
			k += 1
			local x = if symmetric then s * 0.15 * i else 0.075 * (2 * i + (s + 1) / 2) - 0.03
			table.insert(bp.parts, part("Stud" .. k, "Block", "Guard", "Iron", { x, 1.70, 0 }, ID, { 0.09, 0.09, 0.09 }))
		end
	end
	table.insert(bp.parts, part("Hidden1", "Block", "Pommel", "Iron", { 0.06, 0.35, 0 }, ID, { 0.10, 0.10, 0.10 }))
	table.insert(bp.parts, part("Hidden2", "Block", "Pommel", "Iron", { -0.06, 0.35, 0 }, ID, { 0.10, 0.10, 0.10 }))
	table.insert(bp.parts, part("Dust1", "Block", "Grip", "Iron", { 0.125, 1.0, 0 }, ID, { 0.05, 0.05, 0.05 }))
	table.insert(bp.parts, part("Dust2", "Block", "Grip", "Iron", { -0.125, 1.0, 0 }, ID, { 0.05, 0.05, 0.05 }))
	return bp
end

-- quaternion from rotation matrix rows (m_ij = row i, col j; columns = local axes in world). Shepperd's method.
function Swords.quatFromMatrix(m11, m12, m13, m21, m22, m23, m31, m32, m33): { number }
	local tr = m11 + m22 + m33
	if tr > 0 then
		local s = math.sqrt(tr + 1) * 2
		return { 0.25 * s, (m32 - m23) / s, (m13 - m31) / s, (m21 - m12) / s }
	elseif m11 > m22 and m11 > m33 then
		local s = math.sqrt(1 + m11 - m22 - m33) * 2
		return { (m32 - m23) / s, 0.25 * s, (m12 + m21) / s, (m13 + m31) / s }
	elseif m22 > m33 then
		local s = math.sqrt(1 + m22 - m11 - m33) * 2
		return { (m13 - m31) / s, (m12 + m21) / s, 0.25 * s, (m23 + m32) / s }
	else
		local s = math.sqrt(1 + m33 - m11 - m22) * 2
		return { (m21 - m12) / s, (m13 + m31) / s, (m23 + m32) / s, 0.25 * s }
	end
end

-- a legitimately detailed sword: bevelled blade (core + 4 bevel wedges), composite guard with finials,
-- ringed grip, capped pommel. 18 parts.
function Swords.ornate(): any
	local m = "Iron"
	local qUR = Swords.quatFromMatrix(0, 0, -1, -1, 0, 0, 0, 1, 0) -- bevel upper-right: local X->-Y, Y->+Z, Z->-X
	local qLR = Swords.quatFromMatrix(0, 0, -1, 1, 0, 0, 0, -1, 0) -- bevel lower-right: local X->+Y, Y->-Z, Z->-X
	local bevUR = part("BevelUR", "Wedge", "Blade", m, { 0.085, 2.60, 0.015 }, qUR, { 2.40, 0.03, 0.05 })
	local bevLR = part("BevelLR", "Wedge", "Blade", m, { 0.085, 2.60, -0.015 }, qLR, { 2.40, 0.03, 0.05 })
	local armR = part("ArmR", "Block", "Guard", m, { 0.33, 1.43, 0 }, qAxis(0, 0, 1, 10), { 0.40, 0.10, 0.14 })
	local finR = part("FinialR", "Ball", "Guard", m, { 0.56, 1.47, 0 }, ID, { 0.14, 0.14, 0.14 })
	local tr, tl = tipPair("", m, 3.80, 0.11, 0.40, 0.06)
	return {
		name = "Ornate (Iron, 18 parts)",
		parts = {
			part("Pommel", "Ball", "Pommel", m, { 0, 0.30, 0 }, ID, { 0.26, 0.26, 0.26 }),
			part("PommelCap", "Ball", "Pommel", m, { 0, 0.14, 0 }, ID, { 0.10, 0.10, 0.10 }),
			part("Grip", "Cylinder", "Grip", m, { 0, 0.88, 0 }, RZ90, { 0.90, 0.15, 0.15 }),
			part("Ring1", "Cylinder", "Grip", m, { 0, 0.60, 0 }, RZ90, { 0.04, 0.19, 0.19 }),
			part("Ring2", "Cylinder", "Grip", m, { 0, 0.88, 0 }, RZ90, { 0.04, 0.19, 0.19 }),
			part("Ring3", "Cylinder", "Grip", m, { 0, 1.16, 0 }, RZ90, { 0.04, 0.19, 0.19 }),
			part("GuardCore", "Block", "Guard", m, { 0, 1.41, 0 }, ID, { 0.30, 0.18, 0.26 }),
			armR,
			Swords.mirrorX(armR, 0, "ArmL"),
			finR,
			Swords.mirrorX(finR, 0, "FinialL"),
			part("Core", "Block", "Blade", m, { 0, 2.60, 0 }, ID, { 0.12, 2.40, 0.06 }),
			bevUR,
			bevLR,
			Swords.mirrorX(bevUR, 0, "BevelUL"),
			Swords.mirrorX(bevLR, 0, "BevelLL"),
			tr,
			tl,
		},
	}
end

function Swords.dagger(): any
	local tr, tl = tipPair("", "Iron", 2.20, 0.09, 0.30, 0.06)
	return {
		name = "Dagger (Iron)",
		parts = {
			part("Pommel", "Ball", "Pommel", "Iron", { 0, 0.21, 0 }, ID, { 0.22, 0.22, 0.22 }),
			part("Grip", "Cylinder", "Grip", "Iron", { 0, 0.61, 0 }, RZ90, { 0.60, 0.14, 0.14 }),
			part("Guard", "Block", "Guard", "Iron", { 0, 0.96, 0 }, ID, { 0.60, 0.12, 0.20 }),
			part("Blade", "Block", "Blade", "Iron", { 0, 1.60, 0 }, ID, { 0.18, 1.20, 0.06 }),
			tr,
			tl,
		},
	}
end

function Swords.greatsword(): any
	local tr, tl = tipPair("", "Iron", 4.58, 0.15, 0.40, 0.08)
	return {
		name = "Greatsword (Iron)",
		parts = {
			part("Pommel", "Ball", "Pommel", "Iron", { 0, 0.27, 0 }, ID, { 0.34, 0.34, 0.34 }),
			part("Grip", "Cylinder", "Grip", "Iron", { 0, 1.03, 0 }, RZ90, { 1.20, 0.18, 0.18 }),
			part("Guard", "Block", "Guard", "Iron", { 0, 1.71, 0 }, ID, { 1.50, 0.18, 0.26 }),
			part("Blade", "Block", "Blade", "Iron", { 0, 3.18, 0 }, ID, { 0.30, 2.80, 0.08 }),
			tr,
			tl,
		},
	}
end

-- arming sword with a segmented blade (5 overlapping blocks) - should measure like the single blade
function Swords.armingSegmented(): any
	local bp = Swords.arming()
	bp.name = "Arming, blade in 5 segments"
	table.remove(bp.parts, 4)
	for k = 0, 4 do
		local y0 = 1.40 + k * 0.49
		table.insert(bp.parts, 4 + k, part("Blade" .. (k + 1), "Block", "Blade", "Iron", { 0, y0 + 0.27, 0 }, ID, { 0.20, 0.54, 0.06 }))
	end
	return bp
end

-- arming sword whose guard is built as halves + mirror tool, with CornerWedge decorations
function Swords.armingMirrored(): any
	local bp = Swords.arming()
	bp.name = "Arming, guard = half + mirror (+CornerWedges)"
	local gr = part("GuardR", "Block", "Guard", "Iron", { 0.275, 1.40, 0 }, ID, { 0.55, 0.16, 0.24 })
	local cr = part("FinialR", "CornerWedge", "Guard", "Iron", { 0.47, 1.54, 0 }, qAxis(0, 1, 0, 30), { 0.12, 0.12, 0.16 })
	bp.parts[3] = gr
	table.insert(bp.parts, Swords.mirrorX(gr, 0, "GuardL"))
	table.insert(bp.parts, cr)
	table.insert(bp.parts, Swords.mirrorX(cr, 0, "FinialL"))
	return bp
end

return Swords
