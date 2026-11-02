--!strict
-- Blueprint/Quat (SPEC §3.4, §3.11; owner S1): the only quaternion module. S2's math, S6's Euler display
-- (EditorCore/Rotation), S7's rendering and Blueprint/Mirror all call it. q = {qx, qy, qz, qw}, w last (CFrame.new
-- order). Pure, determinism rules of §4.1: + − × ÷ and sqrt only, no trigonometry (axis-angle and Euler conversions
-- live in EditorCore/Rotation). Every function returns new tables and never mutates its arguments.
--
--   toMatrix    rows R00..R22 with s = 2 / ‖q‖²: an exact rotation for any non-zero q, no square root (orthonormal
--               to 1.3e-15, E-S1.1); columns = the part's local X, Y, Z axes; R(q) = R(−q) bit for bit
--   fromMatrix  Shepperd: the largest of 4qw², 4qx², 4qy², 4qz² (their sum is 4, so it is ≥ 1) sets the divisor;
--               then normalize and the hemisphere rule (C4–C5), so the result is canonical
--   normalize   q / ‖q‖ (the arithmetic of Canonical's C3); errors on a zero or non-finite norm
--   hemisphere  C4 + C5: −q if qw < 0, or qw = 0 and the first non-zero of (qx, qy, qz) is negative; then −0 → +0
--   mul         Hamilton product a ⊗ b: rotate by b, then by a
--   rotate      R(q) · v
-- Record → CFrame (Roblox-bound code only): CFrame.new(x, y, z, Quat.toMatrix(rot)), which equals
-- CFrame.new(x, y, z, qx, qy, qz, qw).

local Schema = require("./Schema")

type Quat = Schema.Quat
type Vec3 = Schema.Vec3

local Quat = {}

-- Frozen: copy it (table.clone) before putting it in a record, which must not share tables (§9.2).
Quat.IDENTITY = table.freeze({ 0, 0, 0, 1 }) :: Quat

function Quat.toMatrix(q: Quat): (number, number, number, number, number, number, number, number, number)
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local s = 2 / (x * x + y * y + z * z + w * w)
	return 1 - s * (y * y + z * z), s * (x * y - z * w), s * (x * z + y * w),
		s * (x * y + z * w), 1 - s * (x * x + z * z), s * (y * z - x * w),
		s * (x * z - y * w), s * (y * z + x * w), 1 - s * (x * x + y * y)
end

function Quat.normalize(q: Quat): Quat
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local n = math.sqrt(x * x + y * y + z * z + w * w)
	if not (n > 0 and n < math.huge) then
		error("Quat.normalize: the quaternion has no direction (norm " .. tostring(n) .. ")", 2)
	end
	return { x / n, y / n, z / n, w / n }
end

local function zero(v: number): number
	return if v == 0 then 0 else v -- −0 → +0 (C5)
end

function Quat.hemisphere(q: Quat): Quat
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local flip: boolean
	if w ~= 0 then
		flip = w < 0
	elseif x ~= 0 then
		flip = x < 0
	elseif y ~= 0 then
		flip = y < 0
	else
		flip = z < 0
	end
	if flip then
		x, y, z, w = -x, -y, -z, -w
	end
	return { zero(x), zero(y), zero(z), zero(w) }
end

function Quat.fromMatrix(r00: number, r01: number, r02: number, r10: number, r11: number, r12: number,
	r20: number, r21: number, r22: number): Quat
	local tw = 1 + r00 + r11 + r22 -- 4·qw²
	local tx = 1 + r00 - r11 - r22 -- 4·qx²
	local ty = 1 - r00 + r11 - r22 -- 4·qy²
	local tz = 1 - r00 - r11 + r22 -- 4·qz²
	local x, y, z, w
	if tw >= tx and tw >= ty and tw >= tz then
		local s = 2 * math.sqrt(tw) -- 4·qw
		w = 0.25 * s
		x = (r21 - r12) / s
		y = (r02 - r20) / s
		z = (r10 - r01) / s
	elseif tx >= ty and tx >= tz then
		local s = 2 * math.sqrt(tx) -- 4·qx
		w = (r21 - r12) / s
		x = 0.25 * s
		y = (r01 + r10) / s
		z = (r02 + r20) / s
	elseif ty >= tz then
		local s = 2 * math.sqrt(ty) -- 4·qy
		w = (r02 - r20) / s
		x = (r01 + r10) / s
		y = 0.25 * s
		z = (r12 + r21) / s
	else
		local s = 2 * math.sqrt(tz) -- 4·qz
		w = (r10 - r01) / s
		x = (r02 + r20) / s
		y = (r12 + r21) / s
		z = 0.25 * s
	end
	return Quat.hemisphere(Quat.normalize({ x, y, z, w }))
end

function Quat.mul(a: Quat, b: Quat): Quat
	local ax, ay, az, aw = a[1], a[2], a[3], a[4]
	local bx, by, bz, bw = b[1], b[2], b[3], b[4]
	return {
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
		aw * bw - ax * bx - ay * by - az * bz,
	}
end

function Quat.rotate(q: Quat, v: Vec3): Vec3
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = Quat.toMatrix(q)
	local x, y, z = v[1], v[2], v[3]
	return { r00 * x + r01 * y + r02 * z, r10 * x + r11 * y + r12 * z, r20 * x + r21 * y + r22 * z }
end

return table.freeze(Quat)
