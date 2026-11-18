--!strict
-- S2 prototype v2: fixtures as canonical BlueprintCore {name, parts = {PartData}} in blueprint space
-- (origin = centre of the hitbox's bottom face; +Y toward the tip, +X across, +Z thickness; Quat {qx,qy,qz,qw}).
-- Calibration swords C01-C15 (ported from v1 swords.luau), S8's F1-F5, A25-A27, regression X01-X08, validation V*.
-- Builders may use trig (fixtures only); every fixture is canonicalized like S1's Canonical (hemisphere, ids ascending).
local Quat = require("./quat")
local Mirror = require("./mirror")

local F = {}
local fmt = string.format

local I = { 0, 0, 0, 1 }
local R = 0.70710678118654757
local Z45 = { 0, 0, 0.38268343236508978, 0.92387953251128674 }
local Z90 = { 0, 0, R, R }
local Y90 = { 0, R, 0, R }
local RZ90 = Quat.axisAngle(0, 0, 1, 90) -- cylinder axis (local X) -> +Y
local RY_M90 = Quat.axisAngle(0, 1, 0, -90) -- wedge local X -> +Z, high side (local +Z) -> -X
F.I, F.Z45, F.Z90, F.Y90, F.RZ90, F.RY_M90 = I, Z45, Z90, Y90, RZ90, RY_M90

local function P(label: string, shape: string, slot: string, mat: string, pos: { number }, rot: { number }, size: { number }): any
	return { label = label, shape = shape, slot = slot, material = mat, pos = { pos[1], pos[2], pos[3] }, rot = Quat.canonical(rot), size = { size[1], size[2], size[3] } }
end
F.P = P

-- S1-like canonicalization: ids 1..n in list order, -0 -> 0, hemisphere, Ball/Cylinder sizes
local function bp(name: string, parts: { any }): any
	local out = {}
	for i, p in ipairs(parts) do
		local s = p.size
		if p.shape == "Ball" then
			local d = math.min(s[1], s[2], s[3])
			s = { d, d, d }
		elseif p.shape == "Cylinder" then
			local d = math.min(s[2], s[3])
			s = { s[1], d, d }
		end
		out[i] = { id = i, label = p.label or ("p" .. i), shape = p.shape, slot = p.slot, material = p.material, pos = { p.pos[1] + 0, p.pos[2] + 0, p.pos[3] + 0 }, rot = Quat.canonical(p.rot), size = { s[1], s[2], s[3] } }
	end
	return { name = name, parts = out }
end
F.bp = bp

local function copy(b: any): { any }
	local t = {}
	for _, p in ipairs(b.parts) do
		table.insert(t, P(p.label, p.shape, p.slot, p.material, p.pos, p.rot, p.size))
	end
	return t
end
F.copy = copy

local function mirrorX(p: any, label: string): any
	local m = Mirror.reflect(p, "X")
	m.label = label
	return m
end
F.mirrorX = mirrorX

-- rotate a whole blueprint about pivot by q, then translate by d
function F.transform(b: any, name: string, q: { number }, pivot: { number }, d: { number }): any
	local t = {}
	for _, p in ipairs(b.parts) do
		local rx, ry, rz = Quat.rotate(q, p.pos[1] - pivot[1], p.pos[2] - pivot[2], p.pos[3] - pivot[3])
		table.insert(t, P(p.label, p.shape, p.slot, p.material, { pivot[1] + rx + d[1], pivot[2] + ry + d[2], pivot[3] + rz + d[3] }, Quat.mul(q, p.rot), p.size))
	end
	return bp(name, t)
end

function F.withMaterial(b: any, name: string, slotMat: { [string]: string }): any
	local t = copy(b)
	for _, p in ipairs(t) do
		if slotMat[p.slot] then
			p.material = slotMat[p.slot]
		end
	end
	return bp(name, t)
end

local function tipPair(mat: string, baseY: number, halfW: number, h: number, t: number): (any, any)
	local r = P("TipR", "Wedge", "Blade", mat, { halfW / 2, baseY + h / 2, 0 }, RY_M90, { t, h, halfW })
	return r, mirrorX(r, "TipL")
end

-- Shepperd quaternion from a rotation matrix (rows), returned as {qx,qy,qz,qw}
local function quatFromMatrix(m11, m12, m13, m21, m22, m23, m31, m32, m33): { number }
	local tr = m11 + m22 + m33
	local w, x, y, z
	if tr > 0 then
		local s = math.sqrt(tr + 1) * 2
		w, x, y, z = 0.25 * s, (m32 - m23) / s, (m13 - m31) / s, (m21 - m12) / s
	elseif m11 > m22 and m11 > m33 then
		local s = math.sqrt(1 + m11 - m22 - m33) * 2
		w, x, y, z = (m32 - m23) / s, 0.25 * s, (m12 + m21) / s, (m13 + m31) / s
	elseif m22 > m33 then
		local s = math.sqrt(1 + m22 - m11 - m33) * 2
		w, x, y, z = (m13 - m31) / s, (m12 + m21) / s, 0.25 * s, (m23 + m32) / s
	else
		local s = math.sqrt(1 + m33 - m11 - m22) * 2
		w, x, y, z = (m21 - m12) / s, (m13 + m31) / s, (m23 + m32) / s, 0.25 * s
	end
	return Quat.canonical({ x, y, z, w })
end

-- ================================================================ calibration swords (v1 designs)
function F.arming(mat: string?): any
	local m = mat or "Iron"
	local tr, tl = tipPair(m, 3.90, 0.10, 0.40, 0.06)
	return bp("C02 Arming (" .. m .. ")", {
		P("Pommel", "Ball", "Pommel", m, { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		P("Grip", "Cylinder", "Grip", m, { 0, 0.88, 0 }, RZ90, { 0.90, 0.16, 0.16 }),
		P("Guard", "Block", "Guard", m, { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.24 }),
		P("Blade", "Block", "Blade", m, { 0, 2.65, 0 }, I, { 0.20, 2.50, 0.06 }),
		tr, tl,
	})
end

function F.minimal(): any
	return bp("C01 Minimal", {
		P("Pommel", "Block", "Pommel", "Iron", { 0, 0.35, 0 }, I, { 0.30, 0.30, 0.30 }),
		P("Grip", "Block", "Grip", "Iron", { 0, 1.00, 0 }, I, { 0.20, 1.00, 0.20 }),
		P("Guard", "Block", "Guard", "Iron", { 0, 1.60, 0 }, I, { 1.00, 0.20, 0.30 }),
		P("Blade", "Block", "Blade", "Iron", { 0, 2.90, 0 }, I, { 0.25, 2.40, 0.10 }),
	})
end

function F.rapier(): any
	local tr, tl = tipPair("Steel", 4.60, 0.045, 0.30, 0.05)
	return bp("C04 Rapier (Steel blade)", {
		P("Pommel", "Ball", "Pommel", "Iron", { 0, 0.25, 0 }, I, { 0.26, 0.26, 0.26 }),
		P("Grip", "Cylinder", "Grip", "Iron", { 0, 0.77, 0 }, RZ90, { 0.80, 0.14, 0.14 }),
		P("Cross", "Block", "Guard", "Steel", { 0, 1.21, 0 }, I, { 0.70, 0.10, 0.12 }),
		P("Cup", "Cylinder", "Guard", "Steel", { 0, 1.285, 0 }, RZ90, { 0.05, 0.44, 0.44 }),
		P("Blade", "Block", "Blade", "Steel", { 0, 2.95, 0 }, I, { 0.09, 3.30, 0.05 }),
		tr, tl,
	})
end

function F.cleaver(): any
	return bp("C05 Cleaver", {
		P("Pommel", "Block", "Pommel", "Iron", { 0, 0.32, 0 }, I, { 0.30, 0.24, 0.30 }),
		P("Grip", "Cylinder", "Grip", "Iron", { 0, 0.89, 0 }, RZ90, { 0.92, 0.20, 0.20 }),
		P("Guard", "Block", "Guard", "Iron", { 0, 1.41, 0 }, I, { 0.60, 0.14, 0.30 }),
		P("Blade", "Block", "Blade", "Iron", { 0.25, 2.58, 0 }, I, { 1.00, 2.20, 0.14 }),
		P("Spine", "Block", "Blade", "Iron", { -0.31, 2.58, 0 }, I, { 0.12, 2.20, 0.22 }),
		P("Top", "Wedge", "Blade", "Iron", { 0.19, 3.88, 0 }, Quat.axisAngle(0, 1, 0, 90), { 0.14, 0.40, 1.12 }),
	})
end

function F.sabre(): any
	local parts = {
		P("Pommel", "Ball", "Pommel", "Iron", { 0, 0.30, 0 }, I, { 0.28, 0.28, 0.28 }),
		P("Grip", "Cylinder", "Grip", "Iron", { 0, 0.87, 0 }, RZ90, { 0.88, 0.16, 0.16 }),
		P("Guard", "Block", "Guard", "Steel", { 0, 1.38, 0 }, I, { 0.80, 0.14, 0.22 }),
	}
	local bx, by = 0, 1.40
	local L, step = 0.62, 0.58
	local lastQ, endX, endY = I, 0, 0
	for k, a in ipairs({ 2, 5, 8, 11, 14 }) do
		local q = Quat.axisAngle(0, 0, 1, a)
		local dx, dy = Quat.rotate(q, 0, 1, 0)
		table.insert(parts, P("Seg" .. k, "Block", "Blade", "Steel", { bx + dx * L / 2, by + dy * L / 2, 0 }, q, { 0.18, L, 0.06 }))
		endX, endY = bx + dx * L, by + dy * L
		bx, by = bx + dx * step, by + dy * step
		lastQ = q
	end
	local h, hw = 0.36, 0.09
	for s = -1, 1, 2 do
		local loc = if s > 0 then RY_M90 else Quat.axisAngle(0, 1, 0, 90)
		local ox, oy = Quat.rotate(lastQ, s * hw / 2, h / 2, 0)
		table.insert(parts, P(if s > 0 then "TipR" else "TipL", "Wedge", "Blade", "Steel", { endX + ox, endY + oy, 0 }, Quat.mul(lastQ, loc), { 0.06, h, hw }))
	end
	return bp("C06 Sabre (Steel)", parts)
end

function F.gamey(symmetric: boolean): any
	local t = copy(F.minimal())
	local k = 0
	for i = 0, 4 do
		local y = 1.95 + i * 0.45
		local zf = if i % 2 == 0 then 0.05 else -0.05
		for s = -1, 1, 2 do
			k += 1
			local x = if symmetric then s * 0.06 else 0.06
			local yy = if symmetric then y else y + (s + 1) * 0.11
			table.insert(t, P("Stud" .. k, "Block", "Blade", "Iron", { x, yy, zf }, I, { 0.09, 0.09, 0.09 }))
		end
	end
	for i = 1, 3 do
		for s = -1, 1, 2 do
			k += 1
			local x = if symmetric then s * 0.15 * i else 0.075 * (2 * i + (s + 1) / 2) - 0.03
			table.insert(t, P("Stud" .. k, "Block", "Guard", "Iron", { x, 1.70, 0 }, I, { 0.09, 0.09, 0.09 }))
		end
	end
	table.insert(t, P("Hidden1", "Block", "Pommel", "Iron", { 0.06, 0.35, 0 }, I, { 0.10, 0.10, 0.10 }))
	table.insert(t, P("Hidden2", "Block", "Pommel", "Iron", { -0.06, 0.35, 0 }, I, { 0.10, 0.10, 0.10 }))
	table.insert(t, P("Dust1", "Block", "Grip", "Iron", { 0.125, 1.0, 0 }, I, { 0.05, 0.05, 0.05 }))
	table.insert(t, P("Dust2", "Block", "Grip", "Iron", { -0.125, 1.0, 0 }, I, { 0.05, 0.05, 0.05 }))
	return bp(if symmetric then "C10 Gamey filler, symmetric" else "C11 Gamey filler, lopsided", t)
end

function F.ornate(): any
	local m = "Iron"
	local qUR = quatFromMatrix(0, 0, -1, -1, 0, 0, 0, 1, 0)
	local qLR = quatFromMatrix(0, 0, -1, 1, 0, 0, 0, -1, 0)
	local bevUR = P("BevelUR", "Wedge", "Blade", m, { 0.085, 2.60, 0.015 }, qUR, { 2.40, 0.03, 0.05 })
	local bevLR = P("BevelLR", "Wedge", "Blade", m, { 0.085, 2.60, -0.015 }, qLR, { 2.40, 0.03, 0.05 })
	local armR = P("ArmR", "Block", "Guard", m, { 0.33, 1.43, 0 }, Quat.axisAngle(0, 0, 1, 10), { 0.40, 0.10, 0.14 })
	local finR = P("FinialR", "Ball", "Guard", m, { 0.56, 1.47, 0 }, I, { 0.14, 0.14, 0.14 })
	local tr, tl = tipPair(m, 3.80, 0.11, 0.40, 0.06)
	return bp("C09 Ornate (18 parts)", {
		P("Pommel", "Ball", "Pommel", m, { 0, 0.30, 0 }, I, { 0.26, 0.26, 0.26 }),
		P("PommelCap", "Ball", "Pommel", m, { 0, 0.14, 0 }, I, { 0.10, 0.10, 0.10 }),
		P("Grip", "Cylinder", "Grip", m, { 0, 0.88, 0 }, RZ90, { 0.90, 0.15, 0.15 }),
		P("Ring1", "Cylinder", "Grip", m, { 0, 0.60, 0 }, RZ90, { 0.04, 0.19, 0.19 }),
		P("Ring2", "Cylinder", "Grip", m, { 0, 0.88, 0 }, RZ90, { 0.04, 0.19, 0.19 }),
		P("Ring3", "Cylinder", "Grip", m, { 0, 1.16, 0 }, RZ90, { 0.04, 0.19, 0.19 }),
		P("GuardCore", "Block", "Guard", m, { 0, 1.41, 0 }, I, { 0.30, 0.18, 0.26 }),
		armR, mirrorX(armR, "ArmL"), finR, mirrorX(finR, "FinialL"),
		P("Core", "Block", "Blade", m, { 0, 2.60, 0 }, I, { 0.12, 2.40, 0.06 }),
		bevUR, bevLR, mirrorX(bevUR, "BevelUL"), mirrorX(bevLR, "BevelLL"),
		tr, tl,
	})
end

function F.dagger(): any
	local tr, tl = tipPair("Iron", 2.20, 0.09, 0.30, 0.06)
	return bp("C07 Dagger", {
		P("Pommel", "Ball", "Pommel", "Iron", { 0, 0.21, 0 }, I, { 0.22, 0.22, 0.22 }),
		P("Grip", "Cylinder", "Grip", "Iron", { 0, 0.61, 0 }, RZ90, { 0.60, 0.14, 0.14 }),
		P("Guard", "Block", "Guard", "Iron", { 0, 0.96, 0 }, I, { 0.60, 0.12, 0.20 }),
		P("Blade", "Block", "Blade", "Iron", { 0, 1.60, 0 }, I, { 0.18, 1.20, 0.06 }),
		tr, tl,
	})
end

function F.greatsword(): any
	local tr, tl = tipPair("Iron", 4.58, 0.15, 0.40, 0.08)
	return bp("C08 Greatsword", {
		P("Pommel", "Ball", "Pommel", "Iron", { 0, 0.27, 0 }, I, { 0.34, 0.34, 0.34 }),
		P("Grip", "Cylinder", "Grip", "Iron", { 0, 1.03, 0 }, RZ90, { 1.20, 0.18, 0.18 }),
		P("Guard", "Block", "Guard", "Iron", { 0, 1.71, 0 }, I, { 1.50, 0.18, 0.26 }),
		P("Blade", "Block", "Blade", "Iron", { 0, 3.18, 0 }, I, { 0.30, 2.80, 0.08 }),
		tr, tl,
	})
end

function F.armingSegmented(): any
	local a = F.arming()
	local t = {}
	for _, p in ipairs(copy(a)) do
		if p.label ~= "Blade" then
			table.insert(t, p)
		end
	end
	for k = 0, 4 do
		local y0 = 1.40 + k * 0.49
		table.insert(t, P("Blade" .. (k + 1), "Block", "Blade", "Iron", { 0, y0 + 0.27, 0 }, I, { 0.20, 0.54, 0.06 }))
	end
	return bp("C12 Arming, blade in 5 overlapping segments", t)
end

function F.armingMirrored(): any
	local t = {}
	for _, p in ipairs(copy(F.arming())) do
		if p.label ~= "Guard" then
			table.insert(t, p)
		end
	end
	local gr = P("GuardR", "Block", "Guard", "Iron", { 0.275, 1.40, 0 }, I, { 0.55, 0.16, 0.24 })
	local cr = P("FinialR", "CornerWedge", "Guard", "Iron", { 0.47, 1.54, 0 }, Quat.axisAngle(0, 1, 0, 30), { 0.12, 0.12, 0.16 })
	table.insert(t, gr)
	table.insert(t, mirrorX(gr, "GuardL"))
	table.insert(t, cr)
	table.insert(t, mirrorX(cr, "FinialL"))
	return bp("C13 Arming, guard = half + mirror (+CornerWedges)", t)
end

function F.calibration(): { any }
	local a = F.arming("Iron")
	return {
		F.minimal(),
		a,
		F.arming("Steel"),
		F.rapier(),
		F.cleaver(),
		F.sabre(),
		F.dagger(),
		F.greatsword(),
		F.ornate(),
		F.gamey(true),
		F.gamey(false),
		F.armingSegmented(),
		F.armingMirrored(),
		F.transform(a, "C14 Arming translated (0, +0.27, +0.05)", I, { 0, 0, 0 }, { 0, 0.27, 0.05 }),
		F.transform(a, "C15 Arming rotated 4 deg about Z at the grip", Quat.axisAngle(0, 0, 1, 4), { 0, 0.88, 0 }, { 0, 0, 0 }),
	}
end

-- ================================================================ S8 golden fixtures F1-F5 (S8 §14.7, blueprint space)
function F.golden(): { any }
	local F1 = bp("F1 ArmingSword", {
		P("Pommel", "Ball", "Pommel", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }),
		P("Grip", "Block", "Grip", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.90, 0.16 }),
		P("Guard", "Block", "Guard", "Iron", { 0, 1.29, 0 }, I, { 1.00, 0.18, 0.24 }),
		P("Blade", "Block", "Blade", "Steel", { 0, 2.68, 0 }, I, { 0.16, 2.60, 0.06 }),
		P("Tip", "Block", "Blade", "Steel", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }),
	})
	local F2 = bp("F2 MinimalSword", {
		P("Pommel", "Block", "Pommel", "Iron", { 0, 0.20, 0 }, I, { 0.30, 0.30, 0.30 }),
		P("Grip", "Block", "Grip", "Iron", { 0, 0.85, 0 }, I, { 0.20, 1.00, 0.20 }),
		P("Guard", "Block", "Guard", "Iron", { 0, 1.45, 0 }, I, { 0.80, 0.20, 0.20 }),
		P("Blade", "Block", "Blade", "Iron", { 0, 2.75, 0 }, I, { 0.20, 2.40, 0.08 }),
	})
	local F3 = bp("F3 Rapier", {
		P("Pommel", "Ball", "Pommel", "Steel", { 0, 0.16, 0 }, I, { 0.28, 0.28, 0.28 }),
		P("Grip", "Cylinder", "Grip", "Steel", { 0, 0.75, 0 }, Z90, { 0.90, 0.13, 0.13 }),
		P("Guard", "Block", "Guard", "Steel", { 0, 1.24, 0 }, I, { 0.90, 0.08, 0.08 }),
		P("QuillonL", "Ball", "Guard", "Steel", { -0.45, 1.24, 0 }, I, { 0.12, 0.12, 0.12 }),
		P("QuillonR", "Ball", "Guard", "Steel", { 0.45, 1.24, 0 }, I, { 0.12, 0.12, 0.12 }),
		P("Blade", "Block", "Blade", "Steel", { 0, 2.98, 0 }, I, { 0.07, 3.40, 0.035 }),
		P("Tip", "Wedge", "Blade", "Steel", { 0, 4.83, 0 }, Y90, { 0.035, 0.30, 0.07 }),
	})
	local F4 = bp("F4 Cleaver", {
		P("Pommel", "Block", "Pommel", "Iron", { 0, 0.20, 0 }, I, { 0.30, 0.20, 0.30 }),
		P("Grip", "Block", "Grip", "Iron", { 0, 0.75, 0 }, I, { 0.22, 0.90, 0.22 }),
		P("Guard", "Block", "Guard", "Iron", { 0, 1.275, 0 }, I, { 0.50, 0.15, 0.30 }),
		P("Blade", "Block", "Blade", "Iron", { 0.175, 2.45, 0 }, I, { 0.85, 2.20, 0.16 }),
		P("Tip", "Wedge", "Blade", "Iron", { 0.175, 3.75, 0 }, Y90, { 0.16, 0.40, 0.85 }),
	})
	local F5 = F.withMaterial(F1, "F5 StarterSword", { Blade = "Iron" })
	return { F1, F2, F3, F4, F5 }
end

-- ================================================================ adversarial A25-A27 (R3-01) with their bases
function F.adversarial(): { any }
	local g = F.golden()
	local F1 = g[1]
	local a25 = copy(F1)
	table.insert(a25, P("Core", "Block", "Grip", "Iron", { 0, 0.75, 0 }, Quat.axisAngle(0, 0, 1, 20), { 0.04, 0.30, 0.06 }))
	-- ring grip base: F1 with its grip replaced by 4 rings (0.20 x 0.225 x 0.20: not elongated, no axis)
	local ring = {}
	for _, p in ipairs(copy(F1)) do
		if p.slot ~= "Grip" then
			table.insert(ring, p)
		end
	end
	for k = 0, 3 do
		table.insert(ring, P("Ring" .. k, "Block", "Grip", "Iron", { 0, 0.30 + 0.1125 + k * 0.225, 0 }, I, { 0.20, 0.225, 0.20 }))
	end
	local ringBase = bp("A26 base: F1 ring grip", ring)
	local strap = copy(ringBase)
	table.insert(strap, P("Strap", "Block", "Grip", "Iron", { 0, 0.75, 0 }, Quat.axisAngle(0, 0, 1, 40), { 0.05, 0.40, 0.05 }))
	local a27 = copy(F1)
	for _, p in ipairs(a27) do
		if p.slot ~= "Blade" then
			p.pos[1] += 0.04
		end
	end
	return {
		{ base = F1, fixture = bp("A25 F1 + enclosed 20 deg grip core", a25), bound = 0.01, steps = "all" },
		{ base = ringBase, fixture = bp("A26 F1 ring grip + 40 deg strap", strap), bound = 0.02, steps = "all" },
		{ base = F1, fixture = bp("A27 F1 hilt shifted 0.04 in X", a27), bound = 0.02, steps = "Sharpening" },
	}
end

-- ================================================================ regression X01-X07 (base F5 unless noted)
local function F5(): any
	return F.golden()[5]
end

-- replace F5's blade block (label "Blade", 0.16 x 2.60 x 0.06 at y 2.68, y in [1.38, 3.98]) by a list of parts
local function withBlade(name: string, blades: { any }, base: any?): any
	local t = {}
	for _, p in ipairs(copy(base or F5())) do
		if p.label ~= "Blade" then
			table.insert(t, p)
		end
	end
	for _, b in ipairs(blades) do
		table.insert(t, b)
	end
	return bp(name, t)
end

function F.regression(): { any }
	local base = F5()
	local list = {}
	local function add(id: string, name: string, b: any, kind: string, bound: number, ref: any?)
		table.insert(list, { id = id, fixture = bp(id .. " " .. name, copy(b)), kind = kind, bound = bound, base = ref or base })
	end
	-- X01: 2 invisible blade copies at z +-0.003
	do
		local t = copy(base)
		table.insert(t, P("CopyA", "Block", "Blade", "Iron", { 0, 2.68, 0.003 }, I, { 0.16, 2.60, 0.06 }))
		table.insert(t, P("CopyB", "Block", "Blade", "Iron", { 0, 2.68, -0.003 }, I, { 0.16, 2.60, 0.06 }))
		-- the union is a 0.066-thick blade: compare with that single blade (same union -> same D)
		local u = withBlade("x", { P("Blade", "Block", "Blade", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.60, 0.066 }) })
		add("X01", "2 blade copies at z +-0.003 (vs union blade 0.066)", bp("x", t), "D", 0.01, u)
		add("X01raw", "2 blade copies at z +-0.003 (vs F5)", bp("x", t), "D", 0.05)
	end
	-- X02: 6 copies at k * 0.002 (k = 1..6)
	do
		local t = copy(base)
		for k = 1, 6 do
			table.insert(t, P("Copy" .. k, "Block", "Blade", "Iron", { 0, 2.68, k * 0.002 }, I, { 0.16, 2.60, 0.06 }))
		end
		local u = withBlade("x", { P("Blade", "Block", "Blade", "Iron", { 0, 2.68, 0.006 }, I, { 0.16, 2.60, 0.072 }) })
		add("X02", "6 blade copies at z = k*0.002 (vs union blade 0.072)", bp("x", t), "D", 0.01, u)
	end
	-- X03: F4 + a 0.0003 stud^3 fin on the blade's +X face (R3-03); bound on Thinness
	do
		local f4 = F.golden()[4]
		local t = copy(f4)
		table.insert(t, P("Fin", "Block", "Blade", "Iron", { 0.175 + 0.425 + 0.05 - 0.001, 2.45, 0 }, I, { 0.10, 0.06, 0.05 }))
		add("X03", "F4 + 0.0003 st3 fin", bp("x", t), "Thinness", 0.02, f4)
	end
	-- X04: blade from 4 strips of 0.04 (seams at x = -0.04, 0, 0.04); 5 and 10 segments with gaps; grip nudges
	do
		local s = {}
		for k = 0, 3 do
			table.insert(s, P("Strip" .. k, "Block", "Blade", "Iron", { -0.06 + k * 0.04, 2.68, 0 }, I, { 0.04, 2.60, 0.06 }))
		end
		add("X04a", "blade from 4 strips", withBlade("x", s), "Edge", 0.02)
		local s2 = {}
		for k = 0, 3 do
			table.insert(s2, P("Strip" .. k, "Block", "Blade", "Iron", { -0.06 + k * 0.04, 2.68, 0 }, I, { 0.04, 2.60, 0.06 }))
		end
		-- seams on cell centres: strips of 0.05 at odd multiples of 0.01 (F5 blade is 0.16 wide: 0.03 + 2x0.05 + 0.03)
		local s3 = {
			P("StripA", "Block", "Blade", "Iron", { -0.065, 2.68, 0 }, I, { 0.03, 2.60, 0.06 }),
			P("StripB", "Block", "Blade", "Iron", { -0.025, 2.68, 0 }, I, { 0.05, 2.60, 0.06 }),
			P("StripC", "Block", "Blade", "Iron", { 0.025, 2.68, 0 }, I, { 0.05, 2.60, 0.06 }),
			P("StripD", "Block", "Blade", "Iron", { 0.065, 2.68, 0 }, I, { 0.03, 2.60, 0.06 }),
		}
		add("X04b", "blade from strips, seams at +-0.05 and 0", withBlade("x", s3), "Edge", 0.02)
		for _, n in ipairs({ 5, 10 }) do
			for _, gap in ipairs({ 0.004, 0.006, 0.009 }) do
				local segs = {}
				local L = (2.60 - (n - 1) * gap) / n
				for k = 0, n - 1 do
					local y0 = 1.38 + k * (L + gap)
					table.insert(segs, P("Seg" .. k, "Block", "Blade", "Iron", { 0, y0 + L / 2, 0 }, I, { 0.16, L, 0.06 }))
				end
				add(fmt("X04-%d-%.3f", n, gap), fmt("%d segments, gaps %.3f", n, gap), withBlade("x", segs), "Edge", 0.02)
			end
		end
		for _, dx in ipairs({ 0.005, 0.010, 0.015, 0.020 }) do
			local t = copy(base)
			for _, p in ipairs(t) do
				if p.slot == "Grip" then
					p.pos[1] += dx
				end
			end
			add(fmt("X04g%.3f", dx), fmt("grip nudge %.3f in X", dx), bp("x", t), "Edge", 0.02)
		end
	end
	-- X05: segment gaps 0.002-0.009 and overlaps 0.005-0.05 (bound on G)
	do
		for _, gap in ipairs({ 0.002, 0.004, 0.006, 0.009, -0.005, -0.02, -0.05 }) do
			local n = 5
			local L = (2.60 - (n - 1) * gap) / n
			local segs = {}
			for k = 0, n - 1 do
				local y0 = 1.38 + k * (L + gap)
				table.insert(segs, P("Seg" .. k, "Block", "Blade", "Iron", { 0, y0 + L / 2, 0 }, I, { 0.16, L, 0.06 }))
			end
			add(fmt("X05%+.3f", gap), fmt("5 segments, %s %.3f", if gap > 0 then "gap" else "overlap", math.abs(gap)), withBlade("x", segs), "G", 0.01)
		end
	end
	-- X06: blade offset sweep 0..0.05 in X (Asymmetry vs a continuous oracle, computed in the runner)
	for _, dx in ipairs({ 0.0, 0.01, 0.02, 0.03, 0.04, 0.05 }) do
		local t = copy(base)
		for _, p in ipairs(t) do
			if p.slot == "Blade" then
				p.pos[1] += dx
			end
		end
		add(fmt("X06-%.2f", dx), fmt("blade offset %.2f in X", dx), bp("x", t), "Asym", 0.02)
	end
	-- X07: laminated plates (two 0.03 plates, then two 0.035 plates overlapping by 0.01) and overlapping segments
	do
		add("X07a", "laminate 2 x 0.03 plates", withBlade("x", {
			P("PlateA", "Block", "Blade", "Iron", { 0, 2.68, 0.015 }, I, { 0.16, 2.60, 0.03 }),
			P("PlateB", "Block", "Blade", "Iron", { 0, 2.68, -0.015 }, I, { 0.16, 2.60, 0.03 }),
		}), "G+mass", 0.01)
		add("X07b", "laminate 2 x 0.035 plates overlapping 0.01", withBlade("x", {
			P("PlateA", "Block", "Blade", "Iron", { 0, 2.68, 0.0125 }, I, { 0.16, 2.60, 0.035 }),
			P("PlateB", "Block", "Blade", "Iron", { 0, 2.68, -0.0125 }, I, { 0.16, 2.60, 0.035 }),
		}), "G+mass", 0.01)
		local segs = {}
		for k = 0, 3 do
			table.insert(segs, P("Seg" .. k, "Block", "Blade", "Iron", { 0, 1.38 + 0.35 + k * 0.63, 0 }, I, { 0.16, 0.70, 0.06 }))
		end
		add("X07c", "4 segments overlapping 0.07", withBlade("x", segs), "G+mass", 0.01)
	end
	return list
end

-- ================================================================ validation cases (from v1 + R1-15 / A22 / A23 / A24)
function F.validation(): { any }
	local a = F.arming()
	local out = {}
	local function mod(name: string, fn: (t: { any }) -> { any }?)
		local t = copy(a)
		local r = fn(t)
		table.insert(out, bp(name, r or t))
	end
	mod("V-gap: pommel 0.03 below the grip", function(t)
		t[1].pos[2] -= 0.05 -- ball top 0.40, grip bottom 0.43: gap 0.03
		return nil
	end)
	mod("V-out: tip wedges raised 1.0 (top at 5.30)", function(t)
		t[5].pos[2] += 1.0
		t[6].pos[2] += 1.0
		return nil
	end)
	mod("V-nogrip", function(t)
		table.remove(t, 2)
		return nil
	end)
	mod("V-upside-down", function(t)
		local r = {}
		for _, p in ipairs(t) do
			local q = Quat.mul(Quat.axisAngle(0, 0, 1, 180), p.rot)
			table.insert(r, P(p.label, p.shape, p.slot, p.material, { -p.pos[1], 5.0 - p.pos[2], p.pos[3] }, q, p.size))
		end
		return r
	end)
	mod("A22a: only Blade part dust (0.05 cube on the guard)", function(t)
		local r = {}
		for _, p in ipairs(t) do
			if p.slot ~= "Blade" then
				table.insert(r, p)
			end
		end
		table.insert(r, P("Speck", "Block", "Blade", "Iron", { 0, 1.505, 0 }, I, { 0.05, 0.05, 0.05 }))
		return r
	end)
	mod("A22b: only Blade part enclosed in the guard", function(t)
		local r = {}
		for _, p in ipairs(t) do
			if p.slot ~= "Blade" then
				table.insert(r, p)
			end
		end
		table.insert(r, P("Hidden", "Block", "Blade", "Iron", { 0, 1.40, 0 }, I, { 0.30, 0.10, 0.10 }))
		return r
	end)
	mod("A22c: only Grip part enclosed (grip inside a fat pommel)", function(t)
		local r = {}
		for _, p in ipairs(t) do
			if p.slot ~= "Grip" and p.slot ~= "Pommel" then
				table.insert(r, p)
			end
		end
		table.insert(r, P("FatPommel", "Block", "Pommel", "Iron", { 0, 0.80, 0 }, I, { 0.40, 1.04, 0.28 }))
		table.insert(r, P("GripIn", "Cylinder", "Grip", "Iron", { 0, 0.80, 0 }, RZ90, { 0.80, 0.16, 0.16 }))
		return r
	end)
	-- A23: a side exactly MIN_DIM (0.02) somewhere legitimate: a 0.02-thick fuller plate on the blade
	mod("A23: 0.02-thick decorative plate on the blade", function(t)
		table.insert(t, P("Plate", "Block", "Blade", "Iron", { 0, 2.40, 0.04 }, I, { 0.10, 1.20, 0.02 }))
		return nil
	end)
	-- A24: blade 0.02 x 3.0 x 0.02 (needle)
	mod("A24: needle blade 0.02 x 3.0 x 0.02", function(t)
		local r = {}
		for _, p in ipairs(t) do
			if p.slot ~= "Blade" then
				table.insert(r, p)
			end
		end
		table.insert(r, P("Needle", "Block", "Blade", "Iron", { 0, 1.48 + 1.5, 0 }, I, { 0.02, 3.0, 0.02 }))
		return r
	end)
	return out
end

-- ================================================================ performance (adversarial, valid, all inside the hitbox)
-- slots by height: Pommel 1-2, Grip 3-4, Guard 5-12, Blade 13-24 (slot maxima respected, blade above the grip)
local PERF_SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard",
	"Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
function F.perf(): { any }
	local out = {}
	do -- P1: 24 large blocks (1.0 x 3.5 x 0.4) stacked with small tilts: every pair overlaps
		local t = {}
		for i = 1, 24 do
			local q = Quat.mul(Quat.axisAngle(0, 0, 1, -8 + 16 * ((i * 7) % 24) / 23), Quat.axisAngle(0, 1, 0, -4 + 8 * ((i * 5) % 24) / 23))
			table.insert(t, P("Giant" .. i, "Block", PERF_SLOTS[i], "Iron", { 0, 1.9 + 0.05 * i, 0 }, q, { 1.0, 3.5 - 0.01 * i, 0.40 }))
		end
		table.insert(out, bp("P1 24 large overlapping tilted blocks", t))
	end
	do -- P2: 24 rotated cylinders chained along Y
		local t = {}
		for i = 1, 24 do
			local q = Quat.mul(Quat.axisAngle(0, 0, 1, -60 + 5 * i), Quat.axisAngle(1, 0, 0, 13 * i))
			table.insert(t, P("Cyl" .. i, "Cylinder", PERF_SLOTS[i], "Iron", { 0.15 * math.sin(i), 0.45 + 0.16 * i, 0 }, q, { 1.0, 0.3, 0.3 }))
		end
		table.insert(out, bp("P2 24 rotated cylinders", t))
	end
	do -- P3: 24 rotated wedges / corner wedges chained along Y (exact clipping path)
		local t = {}
		for i = 1, 24 do
			local q = Quat.axisAngle(0, 0, 1, 11 * i)
			local shape = if i % 2 == 0 then "Wedge" else "CornerWedge"
			table.insert(t, P("W" .. i, shape, PERF_SLOTS[i], "Iron", { 0.12 * math.sin(i), 0.5 + 0.12 * i, 0 }, q, { 0.30, 0.40, 0.30 }))
		end
		table.insert(out, bp("P3 24 rotated wedges", t))
	end
	do -- P4: 24 overlapping balls
		local t = {}
		for i = 1, 24 do
			table.insert(t, P("B" .. i, "Ball", PERF_SLOTS[i], "Iron", { 0.2 * math.sin(i), 0.4 + i * 0.17, 0 }, I, { 0.58, 0.58, 0.58 }))
		end
		table.insert(out, bp("P4 24 overlapping balls", t))
	end
	do -- P5: comb blade: a 0.6-wide blade with 10 teeth per side on a plain hilt (many raster runs and chains)
		local t = copy(F.golden()[5])
		for k = 0, 4 do
			local y = 1.6 + k * 0.45
			for s = -1, 1, 2 do
				table.insert(t, P("Tooth" .. k .. s, "Wedge", "Blade", "Iron", { s * 0.14, y, 0 }, Quat.axisAngle(0, 0, 1, s * 90), { 0.08, 0.12, 0.06 }))
			end
		end
		while #t > 24 do table.remove(t) end
		table.insert(out, bp("P5 comb blade (sawtooth, 24 parts)", t))
	end
	return out
end

return F
