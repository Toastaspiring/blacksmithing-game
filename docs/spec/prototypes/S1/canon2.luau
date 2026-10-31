--!strict
-- S1 prototype v2 (revision): canonical form WITHOUT a storage grid (RULINGS 2.5).
-- Rules: finite; bounds rejected (never clamped); q renormalized only if | |q|^2 - 1 | > QUAT_NORM_TOL;
-- hemisphere rule; -0 -> 0; Ball/Cylinder size hook; parts sorted by id.
-- Checks: idempotency (bit-exact), norm error after one renormalization, orthonormality of R(q),
-- float32 (Instance) round trip, JSON round trip (shortest digits). Run: lune run canon2.luau
-- v1 (grid) outputs are kept in canon.v1.out.txt / canon_f32.v1.out.txt.

local QUAT_NORM_TOL = 1e-9
local QUAT_INPUT_TOL = 1e-2
local POS_ABS_MAX, MIN_DIM, MAX_DIM = 16, 0.02, 6.0

local function finite(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end
local function z(x: number): number
	return if x == 0 then 0 else x -- -0 -> +0
end
local function n2(q: { number }): number
	return q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
end

local function canonQuat(q: { number }): { number }?
	for i = 1, 4 do
		if not finite(q[i]) then
			return nil
		end
	end
	local m = n2(q)
	if not finite(m) or math.abs(m - 1) > QUAT_INPUT_TOL then
		return nil
	end
	local r = { q[1], q[2], q[3], q[4] }
	if math.abs(m - 1) > QUAT_NORM_TOL then
		local s = math.sqrt(m)
		r = { q[1] / s, q[2] / s, q[3] / s, q[4] / s }
	end
	local flip = r[4] < 0
	if r[4] == 0 then
		for i = 1, 3 do
			if r[i] ~= 0 then
				flip = r[i] < 0
				break
			end
		end
	end
	if flip then
		r = { -r[1], -r[2], -r[3], -r[4] }
	end
	return { z(r[1]), z(r[2]), z(r[3]), z(r[4]) }
end

local function canonPart(p: any): any?
	local pos, size = table.clone(p.pos), table.clone(p.size)
	for i = 1, 3 do
		if not (finite(pos[i]) and math.abs(pos[i]) <= POS_ABS_MAX) then
			return nil
		end
		if not (finite(size[i]) and size[i] >= MIN_DIM and size[i] <= MAX_DIM) then
			return nil
		end
		pos[i] = z(pos[i])
	end
	if p.shape == "Ball" then
		local s = math.min(size[1], size[2], size[3])
		size = { s, s, s }
	elseif p.shape == "Cylinder" then
		local s = math.min(size[2], size[3])
		size = { size[1], s, s }
	end
	local rot = canonQuat(p.rot)
	if rot == nil then
		return nil
	end
	return { id = p.id, shape = p.shape, pos = pos, rot = rot, size = size }
end

local function same(a: any, b: any): boolean
	for i = 1, 3 do
		if a.pos[i] ~= b.pos[i] or a.size[i] ~= b.size[i] then
			return false
		end
		if 1 / a.pos[i] ~= 1 / b.pos[i] then -- distinguishes -0
			return false
		end
	end
	for i = 1, 4 do
		if a.rot[i] ~= b.rot[i] or (a.rot[i] == 0 and 1 / a.rot[i] ~= 1 / b.rot[i]) then
			return false
		end
	end
	return true
end

local function gauss(): number
	local u1 = math.max(math.random(), 1e-300)
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * math.random())
end
local function toMatrix(q: { number }): { number }
	local x, y, zq, w = q[1], q[2], q[3], q[4]
	local s = 2 / (x * x + y * y + zq * zq + w * w)
	return {
		1 - s * (y * y + zq * zq), s * (x * y - zq * w), s * (x * zq + y * w),
		s * (x * y + zq * w), 1 - s * (x * x + zq * zq), s * (y * zq - x * w),
		s * (x * zq - y * w), s * (y * zq + x * w), 1 - s * (x * x + y * y),
	}
end
local function f32(x: number): number
	return (string.unpack("<f", string.pack("<f", x)))
end

math.randomseed(20261031)
local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local N = 1000000
local idemFail, renorm, keep, flipped, rejected = 0, 0, 0, 0, 0
local maxAfterRenorm, maxKept, maxOrtho = 0, 0, 0
local f32PosChanged, f32RotChanged, f32MaxPos, f32MaxRot = 0, 0, 0, 0
local h = math.sqrt(0.5)
local AXIS = { { 0, 0, 0, 1 }, { h, 0, 0, h }, { 0, h, 0, h }, { 0, 0, h, h }, { 1, 0, 0, 0 }, { 0.5, 0.5, 0.5, 0.5 }, { 0, 0, -1, 0 }, { -0.0, 0, 0, -1 } }
for i = 1, N do
	local g = { gauss(), gauss(), gauss(), gauss() }
	local s = math.sqrt(n2(g))
	local q = { g[1] / s, g[2] / s, g[3] / s, g[4] / s } -- editor-like unit quaternion (|n2-1| ~ 1e-16)
	local mode = i % 10
	if mode == 0 then -- sloppy client: norm off by up to 4e-3 (renormalized branch)
		local f = 1 + (math.random() * 2 - 1) * 4e-3
		q = { q[1] * f, q[2] * f, q[3] * f, q[4] * f }
	elseif mode == 1 then -- right at the threshold
		local f = math.sqrt(1 + (if math.random() < 0.5 then 1 else -1) * QUAT_NORM_TOL * (1 + (math.random() - 0.5) * 1e-3))
		q = { q[1] * f, q[2] * f, q[3] * f, q[4] * f }
	elseif mode == 2 then -- near the input tolerance
		local f = math.sqrt(1 + (math.random() * 2 - 1) * 0.0099)
		q = { q[1] * f, q[2] * f, q[3] * f, q[4] * f }
	elseif mode == 3 then
		q = table.clone(AXIS[math.random(1, #AXIS)])
	elseif mode == 4 then -- w exactly 0
		local a = { gauss(), gauss(), gauss() }
		local t = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
		q = { a[1] / t, a[2] / t, a[3] / t, 0 }
	end
	local p = {
		id = i,
		shape = SHAPES[(i % 5) + 1],
		pos = { (math.random() * 2 - 1) * 16, (math.random() * 2 - 1) * 16, if i % 13 == 0 then -0.0 else (math.random() * 2 - 1) * 1e-6 },
		size = { MIN_DIM + math.random() * (MAX_DIM - MIN_DIM), MIN_DIM + math.random() * (MAX_DIM - MIN_DIM), MIN_DIM + math.random() * 0.5 },
		rot = q,
	}
	local m = n2(q)
	local c = canonPart(p)
	if c == nil then
		rejected += 1
	else
		if math.abs(m - 1) > QUAT_NORM_TOL then
			renorm += 1
			maxAfterRenorm = math.max(maxAfterRenorm, math.abs(n2(c.rot) - 1))
		else
			keep += 1
			maxKept = math.max(maxKept, math.abs(n2(c.rot) - 1))
		end
		local neg = q[4] < 0
		if q[4] == 0 then
			for k = 1, 3 do
				if q[k] ~= 0 then
					neg = q[k] < 0
					break
				end
			end
		end
		if neg then
			flipped += 1
		end
		local c2 = canonPart(c)
		if c2 == nil or not same(c, c2) then
			idemFail += 1
		end
		if i % 10 == 5 then
			local R = toMatrix(c.rot)
			for a = 0, 2 do
				for b = 0, 2 do
					local dot = R[a * 3 + 1] * R[b * 3 + 1] + R[a * 3 + 2] * R[b * 3 + 2] + R[a * 3 + 3] * R[b * 3 + 3]
					maxOrtho = math.max(maxOrtho, math.abs(dot - (if a == b then 1 else 0)))
				end
			end
			-- Instance round trip: Vector3 and CFrame components are float32 in Roblox
			for k = 1, 3 do
				local d = math.abs(f32(c.pos[k]) - c.pos[k])
				if d > 0 then
					f32PosChanged += 1
				end
				f32MaxPos = math.max(f32MaxPos, d)
			end
			for k = 1, 4 do
				local d = math.abs(f32(c.rot[k]) - c.rot[k])
				if d > 0 then
					f32RotChanged += 1
				end
				f32MaxRot = math.max(f32MaxRot, d)
			end
		end
	end
end
print(("cases=%d  rejected=%d  idempotency failures=%d"):format(N, rejected, idemFail))
print(("quaternion branch: kept as given=%d  renormalized=%d  hemisphere flips=%d"):format(keep, renorm, flipped))
print(("max | |q|^2-1 | after one renormalization = %.3e  (threshold %.0e; kept-branch max %.3e)"):format(maxAfterRenorm, QUAT_NORM_TOL, maxKept))
print(("max orthonormality error of R(q) (s = 2/|q|^2) = %.3e"):format(maxOrtho))
print(("float32 round trip (sampled 1/10): pos components changed %d / %d (max %.2e stud), rot components changed %d / %d (max %.2e)"):format(
	f32PosChanged, (N // 10) * 3, f32MaxPos, f32RotChanged, (N // 10) * 4, f32MaxRot))

-- Bounds are rejected, never clamped
local edge = {
	{ "pos 16 (inclusive)", { id = 1, shape = "Block", pos = { 16, -16, 0 }, size = { 1, 1, 1 }, rot = { 0, 0, 0, 1 } }, true },
	{ "pos 16.000000000000004", { id = 1, shape = "Block", pos = { 16.000000000000004, 0, 0 }, size = { 1, 1, 1 }, rot = { 0, 0, 0, 1 } }, false },
	{ "size MIN_DIM", { id = 1, shape = "Block", pos = { 0, 0, 0 }, size = { 0.02, 6, 1 }, rot = { 0, 0, 0, 1 } }, true },
	{ "size 0.019999999999999997", { id = 1, shape = "Block", pos = { 0, 0, 0 }, size = { 0.019999999999999997, 1, 1 }, rot = { 0, 0, 0, 1 } }, false },
	{ "size 6.000000000000001", { id = 1, shape = "Block", pos = { 0, 0, 0 }, size = { 6.000000000000001, 1, 1 }, rot = { 0, 0, 0, 1 } }, false },
	{ "NaN pos", { id = 1, shape = "Block", pos = { 0 / 0, 0, 0 }, size = { 1, 1, 1 }, rot = { 0, 0, 0, 1 } }, false },
	{ "inf size", { id = 1, shape = "Block", pos = { 0, 0, 0 }, size = { math.huge, 1, 1 }, rot = { 0, 0, 0, 1 } }, false },
	{ "q norm^2 1.011", { id = 1, shape = "Block", pos = { 0, 0, 0 }, size = { 1, 1, 1 }, rot = { 0, 0, 0, math.sqrt(1.011) } }, false },
	{ "q zero", { id = 1, shape = "Block", pos = { 0, 0, 0 }, size = { 1, 1, 1 }, rot = { 0, 0, 0, 0 } }, false },
}
local edgeBad = 0
for _, e in edge do
	local ok = canonPart(e[2]) ~= nil
	if ok ~= e[3] then
		edgeBad += 1
		print("EDGE CASE WRONG:", e[1])
	end
end
print(("bound edge cases: %d / %d wrong"):format(edgeBad, #edge))
local ball = canonPart({ id = 1, shape = "Ball", pos = { 0, 0, 0 }, size = { 0.3, 0.5, 0.4 }, rot = { 0, 0, 0, 1 } })
local cyl = canonPart({ id = 1, shape = "Cylinder", pos = { 0, 0, 0 }, size = { 1, 0.3, 0.2 }, rot = { 0, 0, 0, 1 } })
print(("hook: Ball {0.3,0.5,0.4} -> {%g,%g,%g}; Cylinder {1,0.3,0.2} -> {%g,%g,%g}"):format(
	ball.size[1], ball.size[2], ball.size[3], cyl.size[1], cyl.size[2], cyl.size[3]))
local negz = canonPart({ id = 1, shape = "Block", pos = { -0.0, 0, 0 }, size = { 1, 1, 1 }, rot = { -0.0, 0, 0, -1 } })
print(("-0 handling: pos[1] = %s (1/x = %s), rot = {%s, %s, %s, %s}"):format(tostring(negz.pos[1]), tostring(1 / negz.pos[1]),
	tostring(negz.rot[1]), tostring(negz.rot[2]), tostring(negz.rot[3]), tostring(negz.rot[4])))
-- JSON round trip of raw doubles: shortest-digit strings parse back bit-exactly
local jsonBad = 0
for _ = 1, 200000 do
	local x = (math.random() * 2 - 1) * 16
	for p = 1, 17 do
		local s = string.format("%." .. p .. "g", x)
		if tonumber(s) == x then
			break
		end
		if p == 17 then
			jsonBad += 1
		end
	end
end
print(("17-significant-digit round trip failures over 200000 doubles: %d"):format(jsonBad))
