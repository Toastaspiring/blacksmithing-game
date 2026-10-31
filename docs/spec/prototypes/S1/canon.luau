--!strict
-- S1 prototype: canonical storage form of free transforms.
-- Checks: (1) idempotency of canonicalize, (2) max corner displacement it causes,
-- (3) quaternion norm drift after rounding, (4) R(q) with s = 2/|q|^2 is orthonormal.
-- Throwaway: run with lune 0.8.9.

local LEN_SCALE = 10000 -- 1e-4 stud
local QUAT_SCALE = 1000000 -- 1e-6
local QUAT_NORM_TOL = 1e-5 -- accepted | |q|^2 - 1 | for an already-rounded quaternion
local QUAT_INPUT_TOL = 1e-2 -- reject inputs further than this from unit (malformed)

local function q(x: number, scale: number): number
	local v = math.round(x * scale) / scale
	if v == 0 then
		v = 0 -- kill -0
	end
	return v
end

type Vec3 = { number }
type Quat = { number }

local function canonVec(v: Vec3): Vec3
	return { q(v[1], LEN_SCALE), q(v[2], LEN_SCALE), q(v[3], LEN_SCALE) }
end

local function n2(v: Quat): number
	return v[1] * v[1] + v[2] * v[2] + v[3] * v[3] + v[4] * v[4]
end

local function roundQuat(v: Quat): Quat
	return { q(v[1], QUAT_SCALE), q(v[2], QUAT_SCALE), q(v[3], QUAT_SCALE), q(v[4], QUAT_SCALE) }
end

local function hemisphere(r: Quat): Quat
	-- w > 0, or w == 0 and first non-zero of (x, y, z) > 0
	local flip = false
	if r[4] < 0 then
		flip = true
	elseif r[4] == 0 then
		for i = 1, 3 do
			if r[i] ~= 0 then
				flip = r[i] < 0
				break
			end
		end
	end
	if flip then
		local o = { -r[1], -r[2], -r[3], -r[4] }
		for i = 1, 4 do
			if o[i] == 0 then
				o[i] = 0
			end
		end
		return o
	end
	return r
end

local function canonQuat(v: Quat): Quat?
	local m = n2(v)
	if m ~= m or m == math.huge or math.abs(m - 1) > QUAT_INPUT_TOL then
		return nil
	end
	local r = roundQuat(v)
	if math.abs(n2(r) - 1) > QUAT_NORM_TOL then
		local s = math.sqrt(m)
		r = roundQuat({ v[1] / s, v[2] / s, v[3] / s, v[4] / s })
	end
	return hemisphere(r)
end

-- rotation matrix rows, valid for any non-zero q (s = 2/|q|^2): only + - * /
local function toMatrix(v: Quat): { { number } }
	local x, y, z, w = v[1], v[2], v[3], v[4]
	local s = 2 / (x * x + y * y + z * z + w * w)
	return {
		{ 1 - s * (y * y + z * z), s * (x * y - z * w), s * (x * z + y * w) },
		{ s * (x * y + z * w), 1 - s * (x * x + z * z), s * (y * z - x * w) },
		{ s * (x * z - y * w), s * (y * z + x * w), 1 - s * (x * x + y * y) },
	}
end

local function corners(pos: Vec3, rot: Quat, size: Vec3): { Vec3 }
	local R = toMatrix(rot)
	local out = {}
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local lx, ly, lz = sx * size[1] / 2, sy * size[2] / 2, sz * size[3] / 2
				table.insert(out, {
					pos[1] + R[1][1] * lx + R[1][2] * ly + R[1][3] * lz,
					pos[2] + R[2][1] * lx + R[2][2] * ly + R[2][3] * lz,
					pos[3] + R[3][1] * lx + R[3][2] * ly + R[3][3] * lz,
				})
			end
		end
	end
	return out
end

local function gauss(): number
	local u1 = math.max(math.random(), 1e-12)
	local u2 = math.random()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function randomUnitQuat(): Quat
	local v = { gauss(), gauss(), gauss(), gauss() }
	local s = math.sqrt(n2(v))
	return { v[1] / s, v[2] / s, v[3] / s, v[4] / s }
end

local function eqv(a: { number }, b: { number }): boolean
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

math.randomseed(12345)

-- Placeholder hitbox for magnitudes only (S2 owns real numbers): X,Z centred, Y from -1.5 to 5.5
local HB_MIN = { -1.0, -1.5, -0.4 }
local HB_MAX = { 1.0, 5.5, 0.4 }

local N = 200000
local idemFail, maxDisp, maxNormDrift, maxOrthoErr = 0, 0, 0, 0
local maxNormDriftNormalizedBranch = 0
local roundBranch, renormBranch = 0, 0
local nearTolCases = 0

for i = 1, N do
	local pos = {
		HB_MIN[1] + math.random() * (HB_MAX[1] - HB_MIN[1]),
		HB_MIN[2] + math.random() * (HB_MAX[2] - HB_MIN[2]),
		HB_MIN[3] + math.random() * (HB_MAX[3] - HB_MIN[3]),
	}
	local size = { 0.05 + math.random() * 1.95, 0.05 + math.random() * 6.95, 0.05 + math.random() * 0.75 }
	local rot = randomUnitQuat()
	-- every 10th case: perturb the norm (as a sloppy client could) within input tolerance
	if i % 10 == 0 then
		local f = 1 + (math.random() * 2 - 1) * 4e-3
		rot = { rot[1] * f, rot[2] * f, rot[3] * f, rot[4] * f }
	end
	-- every 7th case: axis-aligned 90-degree multiples (typical snapped rotations)
	if i % 7 == 0 then
		local h = math.sqrt(0.5)
		local choices = { { 0, 0, 0, 1 }, { h, 0, 0, h }, { 0, h, 0, h }, { 0, 0, h, h }, { 1, 0, 0, 0 }, { 0.5, 0.5, 0.5, 0.5 } }
		rot = choices[math.random(1, #choices)]
	end

	local cp, cs = canonVec(pos), canonVec(size)
	local r0 = roundQuat(rot)
	if math.abs(n2(r0) - 1) > QUAT_NORM_TOL then
		renormBranch += 1
	else
		roundBranch += 1
	end
	local cr = canonQuat(rot) :: Quat
	-- idempotency
	local cp2, cs2, cr2 = canonVec(cp), canonVec(cs), canonQuat(cr) :: Quat
	if not (eqv(cp, cp2) and eqv(cs, cs2) and eqv(cr, cr2)) then
		idemFail += 1
	end
	-- norm drift of the stored quaternion
	local drift = math.abs(n2(cr) - 1)
	if drift > maxNormDrift then
		maxNormDrift = drift
	end
	if math.abs(n2(rot) - 1) > QUAT_NORM_TOL then
		if drift > maxNormDriftNormalizedBranch then
			maxNormDriftNormalizedBranch = drift
		end
	end
	if math.abs(drift - QUAT_NORM_TOL) < 2e-6 then
		nearTolCases += 1
	end
	-- displacement of the 8 corners: raw (normalized input) vs canonical
	local s = math.sqrt(n2(rot))
	local rawRot = { rot[1] / s, rot[2] / s, rot[3] / s, rot[4] / s }
	local a = corners(pos, rawRot, size)
	local b = corners(cp, cr, cs)
	for k = 1, 8 do
		for ax = 1, 3 do
			local d = math.abs(a[k][ax] - b[k][ax])
			if d > maxDisp then
				maxDisp = d
			end
		end
	end
	-- orthonormality of R(cr) (s = 2/|q|^2 formula)
	local R = toMatrix(cr)
	for r1 = 1, 3 do
		for r2 = 1, 3 do
			local dot = R[r1][1] * R[r2][1] + R[r1][2] * R[r2][2] + R[r1][3] * R[r2][3]
			local e = math.abs(dot - (if r1 == r2 then 1 else 0))
			if e > maxOrthoErr then
				maxOrthoErr = e
			end
		end
	end
end

print(("cases=%d  idempotency failures=%d"):format(N, idemFail))
print(("branch: round-only=%d  renormalize=%d"):format(roundBranch, renormBranch))
print(("max | |q|^2-1 | of stored quaternions = %.3e  (renormalized branch max %.3e)"):format(maxNormDrift, maxNormDriftNormalizedBranch))
print(("max corner displacement per axis (pos+size+rot quantization) = %.3e stud"):format(maxDisp))
print(("max orthonormality error of R(q) = %.3e"):format(maxOrthoErr))

-- Second-order idempotency stress: values sitting exactly on .5 ticks and huge/small magnitudes
local stress = { 0.00005, -0.00005, 0.00015, 1.23455, -1.23455, 999.99995, 2047.99995, 0.0001, 1e-9, -1e-9 }
local bad = 0
for _, x in stress do
	local a1 = q(x, LEN_SCALE)
	local a2 = q(a1, LEN_SCALE)
	if a1 ~= a2 then
		bad += 1
		print("non-idempotent", x, a1, a2)
	end
end
print("tie/edge stress non-idempotent count:", bad)

-- exhaustive check of k/1e4 round trip for |k| <= 20,480,000 (covers +-2048 studs) sampled every 7
local rtBad = 0
for k = -20480000, 20480000, 7 do
	local x = k / LEN_SCALE
	if math.round(x * LEN_SCALE) ~= k then
		rtBad += 1
	end
end
print("k/1e4 -> round(x*1e4) mismatches (sampled 5.85M values):", rtBad)
local rtBadQ = 0
for k = -1000000, 1000000 do
	local x = k / QUAT_SCALE
	if math.round(x * QUAT_SCALE) ~= k then
		rtBadQ += 1
	end
end
print("k/1e6 -> round(x*1e6) mismatches (all 2M+1 values):", rtBadQ)

-- angle error bound: 2*asin(|delta|) with |delta| <= sqrt(4)*0.5e-6 = 1e-6
print(("rotation error bound ~ %.2e rad; over half-diagonal 3.66 stud -> %.2e stud"):format(2e-6, 2e-6 * 3.66))
