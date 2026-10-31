--!strict
-- S1 prototype: is canonical data stable through a Roblox Instance round trip?
-- Roblox stores Vector3 and CFrame rotation in float32 (probe on 2026-10-31: CFrame components off by ~1e-7).
-- Emulates: canonical -> CFrame/Vector3 (float32) -> back to canonical (matrix -> quaternion -> canonicalize).

local LEN_SCALE, QUAT_SCALE, QUAT_NORM_TOL = 10000, 1000000, 1e-5

local function f32(x: number): number
	return (string.unpack("<f", string.pack("<f", x)))
end
local function q(x: number, s: number): number
	local v = math.round(x * s) / s
	return if v == 0 then 0 else v
end
local function n2(v: { number }): number
	return v[1] * v[1] + v[2] * v[2] + v[3] * v[3] + v[4] * v[4]
end
local function hemi(r: { number }): { number }
	local flip = r[4] < 0
	if r[4] == 0 then
		for i = 1, 3 do
			if r[i] ~= 0 then
				flip = r[i] < 0
				break
			end
		end
	end
	if not flip then
		return r
	end
	local o = { -r[1], -r[2], -r[3], -r[4] }
	for i = 1, 4 do
		if o[i] == 0 then
			o[i] = 0
		end
	end
	return o
end
local function canonQuat(v: { number }): { number }
	local r = { q(v[1], QUAT_SCALE), q(v[2], QUAT_SCALE), q(v[3], QUAT_SCALE), q(v[4], QUAT_SCALE) }
	if math.abs(n2(r) - 1) > QUAT_NORM_TOL then
		local s = math.sqrt(n2(v))
		r = { q(v[1] / s, QUAT_SCALE), q(v[2] / s, QUAT_SCALE), q(v[3] / s, QUAT_SCALE), q(v[4] / s, QUAT_SCALE) }
	end
	return hemi(r)
end
local function toMatrix(v: { number }): { number }
	local x, y, z, w = v[1], v[2], v[3], v[4]
	local s = 2 / (x * x + y * y + z * z + w * w)
	return {
		1 - s * (y * y + z * z), s * (x * y - z * w), s * (x * z + y * w),
		s * (x * y + z * w), 1 - s * (x * x + z * z), s * (y * z - x * w),
		s * (x * z - y * w), s * (y * z + x * w), 1 - s * (x * x + y * y),
	}
end
-- Shepperd's method (editor-side, non-authoritative)
local function fromMatrix(m: { number }): { number }
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = table.unpack(m)
	local tr = r00 + r11 + r22
	if tr > 0 then
		local s = math.sqrt(tr + 1) * 2
		return { (r21 - r12) / s, (r02 - r20) / s, (r10 - r01) / s, 0.25 * s }
	elseif r00 > r11 and r00 > r22 then
		local s = math.sqrt(1 + r00 - r11 - r22) * 2
		return { 0.25 * s, (r01 + r10) / s, (r02 + r20) / s, (r21 - r12) / s }
	elseif r11 > r22 then
		local s = math.sqrt(1 + r11 - r00 - r22) * 2
		return { (r01 + r10) / s, 0.25 * s, (r12 + r21) / s, (r02 - r20) / s }
	else
		local s = math.sqrt(1 + r22 - r00 - r11) * 2
		return { (r02 + r20) / s, (r12 + r21) / s, 0.25 * s, (r10 - r01) / s }
	end
end
local function gauss(): number
	return math.sqrt(-2 * math.log(math.max(math.random(), 1e-12))) * math.cos(2 * math.pi * math.random())
end

math.randomseed(99)
local N = 200000
local posBad, quatBad, maxQuatDev = 0, 0, 0
for _ = 1, N do
	-- canonical position component anywhere in +-64 studs
	local k = math.random(-640000, 640000)
	local x = k / LEN_SCALE
	if q(f32(x), LEN_SCALE) ~= x then
		posBad += 1
	end
	-- canonical quaternion
	local g = { gauss(), gauss(), gauss(), gauss() }
	local s = math.sqrt(n2(g))
	local cq = canonQuat({ g[1] / s, g[2] / s, g[3] / s, g[4] / s })
	local m = toMatrix(cq)
	for i = 1, 9 do
		m[i] = f32(m[i])
	end
	local back = canonQuat(fromMatrix(m))
	local same = true
	for i = 1, 4 do
		if back[i] ~= cq[i] then
			same = false
			maxQuatDev = math.max(maxQuatDev, math.abs(back[i] - cq[i]))
		end
	end
	if not same then
		quatBad += 1
	end
end
print(("float32 round trip: position mismatches %d / %d ; quaternion mismatches %d / %d (max component change %.1e)"):format(posBad, N, quatBad, N, maxQuatDev))
