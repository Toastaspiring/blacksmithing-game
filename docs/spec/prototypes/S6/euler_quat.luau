--!strict
-- S6 prototype: display Euler (Roblox Orientation convention, R = Ry(b) * Rx(a) * Rz(c), degrees)
-- <-> stored unit quaternion {w,x,y,z}. Round trip error, gimbal handling, continuity choice.
-- Run: lune run euler_quat.luau

type Quat = { w: number, x: number, y: number, z: number }
type Euler = { x: number, y: number, z: number } -- degrees: x = a (pitch), y = b (yaw), z = c (roll)

local D2R, R2D = math.pi / 180, 180 / math.pi

local function qmul(p: Quat, q: Quat): Quat
	return {
		w = p.w * q.w - p.x * q.x - p.y * q.y - p.z * q.z,
		x = p.w * q.x + p.x * q.w + p.y * q.z - p.z * q.y,
		y = p.w * q.y - p.x * q.z + p.y * q.w + p.z * q.x,
		z = p.w * q.z + p.x * q.y - p.y * q.x + p.z * q.w,
	}
end

local function qnorm(q: Quat): Quat
	local n = math.sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z)
	return { w = q.w / n, x = q.x / n, y = q.y / n, z = q.z / n }
end

local function fromEuler(e: Euler): Quat
	local a, b, c = e.x * D2R / 2, e.y * D2R / 2, e.z * D2R / 2
	local qx = { w = math.cos(a), x = math.sin(a), y = 0, z = 0 }
	local qy = { w = math.cos(b), x = 0, y = math.sin(b), z = 0 }
	local qz = { w = math.cos(c), x = 0, y = 0, z = math.sin(c) }
	return qnorm(qmul(qmul(qy, qx), qz))
end

-- rotation matrix rows from quaternion
local function toMat(q: Quat): { { number } }
	local w, x, y, z = q.w, q.x, q.y, q.z
	return {
		{ 1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y) },
		{ 2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x) },
		{ 2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y) },
	}
end

local function wrap(d: number): number -- to (-180, 180]
	d = d % 360
	if d > 180 then
		d -= 360
	end
	return d
end

local GIMBAL_EPS = 1e-6 -- on cos(a)

-- returns the canonical solution (a in [-90,90]) plus the alternative (or nil in gimbal lock)
local function toEuler(q: Quat): (Euler, Euler?)
	local m = toMat(q)
	local sa = -m[2][3]
	sa = math.clamp(sa, -1, 1)
	local a = math.asin(sa)
	local ca = math.cos(a)
	if ca > GIMBAL_EPS then
		local b = math.atan2(m[1][3], m[3][3])
		local c = math.atan2(m[2][1], m[2][2])
		local e1 = { x = a * R2D, y = b * R2D, z = c * R2D }
		local e2 = { x = wrap(180 - e1.x), y = wrap(e1.y + 180), z = wrap(e1.z + 180) }
		return e1, e2
	end
	-- gimbal lock: c := 0, b from the remaining 2x2 block
	local b = math.atan2(-m[3][1], m[1][1])
	return { x = a * R2D, y = b * R2D, z = 0 }, nil
end

local function angDist(e: Euler, f: Euler): number
	return math.abs(wrap(e.x - f.x)) + math.abs(wrap(e.y - f.y)) + math.abs(wrap(e.z - f.z))
end

-- choose the Euler triple closest to the cached one (display continuity)
local function toEulerNear(q: Quat, cache: Euler?): Euler
	local e1, e2 = toEuler(q)
	if cache == nil then
		return e1
	end
	if e2 == nil then
		-- gimbal: keep cached roll, re-derive yaw so that b -/+ c stays the same
		local m = toMat(q)
		local s = if e1.x > 0 then -1 else 1 -- a=+90: b - c fixed ; a=-90: b + c fixed
		local sum = math.atan2(-m[3][1], m[1][1]) * R2D -- equals b + s*c ... with c=0 -> b
		return { x = e1.x, y = wrap(sum - s * cache.z), z = cache.z }
	end
	return if angDist(e1, cache) <= angDist(e2, cache) then e1 else e2
end

local function qdist(p: Quat, q: Quat): number -- 1 - |dot| (0 = same rotation)
	return 1 - math.abs(p.w * q.w + p.x * q.x + p.y * q.y + p.z * q.z)
end

-- simple deterministic LCG for test inputs
local seed = 12345
local function rnd(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local maxErr, maxAngErr = 0, 0
for _ = 1, 200000 do
	local e = { x = (rnd() * 2 - 1) * 180, y = (rnd() * 2 - 1) * 180, z = (rnd() * 2 - 1) * 180 }
	local q = fromEuler(e)
	local e1 = toEuler(q)
	local q2 = fromEuler(e1)
	local d = qdist(q, q2)
	if d > maxErr then
		maxErr = d
	end
	local ang = 2 * math.acos(math.clamp(1 - d, -1, 1)) * R2D
	if ang > maxAngErr then
		maxAngErr = ang
	end
end
print(string.format("random round trip (200k): max (1-|dot|) = %.3g, max angle error = %.3g deg", maxErr, maxAngErr))

-- gimbal cases
for _, e in { { x = 90, y = 30, z = 20 }, { x = -90, y = -45, z = 10 }, { x = 89.9999, y = 10, z = 70 } } do
	local q = fromEuler(e)
	local r = toEuler(q)
	local back = fromEuler(r)
	print(string.format("gimbal in (%.4f, %.1f, %.1f) -> canonical (%.4f, %.4f, %.4f)  rot err %.2e", e.x, e.y, e.z, r.x, r.y, r.z, qdist(q, back)))
	local near = toEulerNear(q, e)
	print(string.format("   near-cache -> (%.4f, %.4f, %.4f)  rot err %.2e", near.x, near.y, near.z, qdist(q, fromEuler(near))))
end

-- continuity: user typed (170, 0, 0); canonical form flips to (10, 180, 180)
local typed = { x = 170, y = 0, z = 0 }
local q = fromEuler(typed)
local canon = toEuler(q)
local near = toEulerNear(q, typed)
print(string.format("typed (170,0,0): canonical (%.2f, %.2f, %.2f) vs continuity pick (%.2f, %.2f, %.2f)", canon.x, canon.y, canon.z, near.x, near.y, near.z))

-- incremental gizmo rotation about X in 7.5 deg steps from 0 to 360: show displayed X with/without continuity
local cache: Euler? = { x = 0, y = 0, z = 0 }
local jumpsCanon, jumpsNear = 0, 0
local prevC, prevN = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }
for i = 1, 48 do
	local qq = fromEuler({ x = i * 7.5, y = 0, z = 0 })
	local c = toEuler(qq)
	local n = toEulerNear(qq, cache)
	if angDist(c, prevC) > 30 then
		jumpsCanon += 1
	end
	if angDist(n, prevN) > 30 then
		jumpsNear += 1
	end
	prevC, prevN, cache = c, n, n
end
print(string.format("sweep X 0..360 in 7.5 deg steps: field jumps > 30 deg: canonical %d, continuity %d", jumpsCanon, jumpsNear))
