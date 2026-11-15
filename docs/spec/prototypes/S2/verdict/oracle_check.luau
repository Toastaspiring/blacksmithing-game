--!nocheck
-- m2r5: the oracle against closed forms: a ball cap, a cylinder arc (side and caps), a block with a known visible strip, a wedge cut by a plane,
-- coincident faces and the index rule, a gap within the probe; each unrotated and turned as a whole, so no grid or axis is special.
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Quat = require("./tree/src/shared/Blueprint/Quat")
local Balance = require("./tree/src/shared/Definitions/Balance")
local O = require("./oracle")
local fmt = string.format
local DELTA = Balance.Geometry.HIDE_OFFSET
local PI = math.pi
local I = { 0, 0, 0, 1 }

local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) })
end

local TURNS = { I, axisAngle(1, 2, 3, 37), axisAngle(-2, 1, 0.5, 71), axisAngle(0, 0, 1, 22.5), axisAngle(1, 1, 0, 45) }

local function turned(parts, q)
	local out = {}
	for i, p in ipairs(parts) do
		local r = Quat.rotate(q, { p.pos[1], p.pos[2], p.pos[3] })
		out[i] = { id = i, slot = "Blade", shape = p.shape, material = "Iron", pos = r, rot = Quat.normalize(Quat.mul(q, p.rot)), size = p.size }
	end
	return out
end

local function prep(parts)
	local P = {}
	for i, p in ipairs(parts) do
		P[i] = Shapes.prepare(p, i)
	end
	return P
end

local worst, count = 0, 0
local function check(what, parts, idx, want)
	local errs = {}
	for t, q in ipairs(TURNS) do
		local P = prep(turned(parts, q))
		local _, _, hider = O.flags(P)
		local got, n = O.share(P, idx, hider, { noCoarse = true })
		local e = math.abs(got - want)
		errs[t] = fmt("%.4f", e * 100)
		worst = math.max(worst, e)
		count += 1
	end
	print(fmt("%-52s want %8.4f %%   err (pct points, 5 turns): %s", what, want * 100, table.concat(errs, " ")))
end

-- a host whose top plane is y = c, far wider than the part
local function hostBelow(c, shape)
	return { shape = "Block", pos = { 0, c - 2, 0 }, rot = I, size = { 8, 4, 8 } }
end

print("-- ball cap, r = 0.15 and 0.05, plane y = c")
for _, r in ipairs({ 0.15, 0.05 }) do
	for _, f in ipairs({ 0.99, 0.95, 0.9, 0.8, 0.5, 0.2, 0, -0.5, -0.9 }) do
		local c = f * r
		local ce = if c >= 0 then c else c / (1 + DELTA / r)
		local want = math.max(0, (r - ce) / (2 * r))
		check(fmt("ball r %.2f, c/r %.2f", r, f), { { shape = "Ball", pos = { 0, 0, 0 }, rot = I, size = { 2 * r, 2 * r, 2 * r } }, hostBelow(c) }, 1, want)
	end
end

print("-- cylinder along X, plane y = c: an arc of the side and a segment of each cap")
for _, def in ipairs({ { 0.1, 1.0 }, { 0.03, 2.0 }, { 0.2, 0.05 } }) do
	local r, L = def[1], def[2]
	for _, f in ipairs({ 0.99, 0.95, 0.9, 0.7, 0.3, 0, -0.5, -0.9 }) do
		local c = f * r
		local ce = if c >= 0 then c else c / (1 + DELTA / r)
		local side = L * 2 * r * math.acos(math.clamp(ce / r, -1, 1))
		local cap = 2 * (r * r * math.acos(f) - c * math.sqrt(r * r - c * c))
		local total = 2 * PI * r * L + 2 * PI * r * r
		check(fmt("cylinder r %.2f L %.2f, c/r %.2f", r, L, f), { { shape = "Cylinder", pos = { 0, 0, 0 }, rot = I, size = { L, 2 * r, 2 * r } }, hostBelow(c) }, 1, (side + cap) / total)
	end
end

print("-- cylinder with a narrow visible arc between two half-spaces (a slot): arc = 2 phi, caps hidden behind end blocks")
for _, phi in ipairs({ 5, 10, 20, 30, 45 }) do
	local r, L = 0.1, 1.0
	-- the two walls: blocks turned +-phi about X, each covers y < 0 side beyond its plane through the axis offset 0: visible = angle within +-phi of +Z
	local a = math.rad(phi)
	local function wall(sign)
		-- half-space through the axis with outward normal (0, sign*cos(a), sin(a)) rotated: keep it simple with a big block whose face passes the axis
		local q = axisAngle(1, 0, 0, sign * phi)
		local big = 4
		local n = Quat.rotate(q, { 0, sign, 0 }) -- the wall's inner normal direction away from the slot
		return { shape = "Block", pos = { 0, n[2] * big / 2, n[3] * big / 2 }, rot = q, size = { 8, big, 8 } }
	end
	local ends = { { shape = "Block", pos = { L / 2 + 2, 0, 0 }, rot = I, size = { 4, 4, 4 } }, { shape = "Block", pos = { -L / 2 - 2, 0, 0 }, rot = I, size = { 4, 4, 4 } } }
	-- the probe grows nothing here: a side point at angle t from +Z has its probe further out along its own radius, which stays on the same side of a plane through the axis
	local want = (L * 2 * r * a) / (2 * PI * r * L + 2 * PI * r * r)
	check(fmt("cylinder slot, half-angle %d deg", phi), { { shape = "Cylinder", pos = { 0, 0, 0 }, rot = I, size = { L, 2 * r, 2 * r } }, wall(1), wall(-1), ends[1], ends[2] }, 1, want)
end

print("-- block sunk in a host: visible strip")
for _, t in ipairs({ 0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1 }) do
	local a, b, c = 0.3, 0.5, 0.04
	local want = (a * c + 2 * (a + c) * t) / (2 * (a * b + a * c + b * c))
	check(fmt("plate 0.3 x 0.5 x 0.04, poke %.3f", t), { { shape = "Block", pos = { 0, t - b / 2, 0 }, rot = I, size = { a, b, c } }, hostBelow(0) }, 1, want)
end

print("-- wedge cut by a plane")
for _, f in ipairs({ 0.95, 0.8, 0.5, 0, -0.5, -0.9 }) do
	local hx, hy, hz = 0.2, 0.15, 0.1
	local c = f * hy
	local s = math.sqrt(hy * hy + hz * hz)
	local total = 4 * hx * hz + 4 * hx * hy + 4 * hx * s + 4 * hy * hz
	local vis = 2 * hx * (hy - c) + (hy - c) / (2 * hy) * 4 * hx * s + 2 * hz * (hy - c) ^ 2 / (2 * hy)
	check(fmt("wedge, c/hy %.2f", f), { { shape = "Wedge", pos = { 0, 0, 0 }, rot = I, size = { 2 * hx, 2 * hy, 2 * hz } }, hostBelow(c) }, 1, vis / total)
end

print("-- coincident faces: A (index 1) and B (index 2) overlap by o along X, same Y and Z ranges")
do
	local a, b, c = 0.6, 0.3, 0.1
	local o = 0.2
	local partsAB = { { shape = "Block", pos = { -(a - o) / 2, 0, 0 }, rot = I, size = { a, b, c } }, { shape = "Block", pos = { (a - o) / 2, 0, 0 }, rot = I, size = { a, b, c } } }
	local total = 2 * (a * b + a * c + b * c)
	local endFace = b * c
	check("lower index: keeps its coincident faces, loses its end", partsAB, 1, (total - endFace) / total)
	check("higher index: loses the coincident faces and its end", partsAB, 2, (total - endFace - o * (2 * b + 2 * c)) / total)
end

print("-- a gap of 0.008 (inside the probe) below a plate: its bottom is hidden")
do
	local a, b, c = 0.3, 0.1, 0.4
	local total = 2 * (a * b + a * c + b * c)
	check("plate 0.008 above a host", { { shape = "Block", pos = { 0, b / 2 + 0.008, 0 }, rot = I, size = { a, b, c } }, hostBelow(0) }, 1, (total - a * c) / total)
	check("plate 0.014 above a host (out of the probe)", { { shape = "Block", pos = { 0, b / 2 + 0.014, 0 }, rot = I, size = { a, b, c } }, hostBelow(0) }, 1, 1)
end

print(fmt("\n%d checks, worst error %.4f percentage points", count, worst * 100))
