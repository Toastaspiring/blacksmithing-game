--!strict
-- Stand-in for S1's Blueprint/Quat (RULINGS 2.4): Quat = {qx, qy, qz, qw}, w last (CFrame.new order).
local Quat = {}

-- rows R00..R22, s = 2/|q|^2 (exact rotation for any non-zero q); columns = the part's local X, Y, Z axes
function Quat.toMatrix(q: { number }): (number, number, number, number, number, number, number, number, number)
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local s = 2 / (x * x + y * y + z * z + w * w)
	return 1 - s * (y * y + z * z), s * (x * y - z * w), s * (x * z + y * w),
		s * (x * y + z * w), 1 - s * (x * x + z * z), s * (y * z - x * w),
		s * (x * z - y * w), s * (y * z + x * w), 1 - s * (x * x + y * y)
end

-- Hamilton product a * b
function Quat.mul(a: { number }, b: { number }): { number }
	local ax, ay, az, aw = a[1], a[2], a[3], a[4]
	local bx, by, bz, bw = b[1], b[2], b[3], b[4]
	return {
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
		aw * bw - ax * bx - ay * by - az * bz,
	}
end

-- hemisphere rule: qw > 0, or qw == 0 and the first non-zero of (qx, qy, qz) positive; -0 -> 0
function Quat.canonical(q: { number }): { number }
	local x, y, z, w = q[1], q[2], q[3], q[4]
	if w < 0 or (w == 0 and (x < 0 or (x == 0 and (y < 0 or (y == 0 and z < 0))))) then
		x, y, z, w = -x, -y, -z, -w
	end
	return { x + 0, y + 0, z + 0, w + 0 }
end

-- fixture builders only (trig is allowed outside authoritative paths)
function Quat.axisAngle(ax: number, ay: number, az: number, deg: number): { number }
	local a = math.rad(deg) / 2
	local s = math.sin(a)
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.canonical({ ax / n * s, ay / n * s, az / n * s, math.cos(a) })
end

function Quat.rotate(q: { number }, x: number, y: number, z: number): (number, number, number)
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = Quat.toMatrix(q)
	return r00 * x + r01 * y + r02 * z, r10 * x + r11 * y + r12 * z, r20 * x + r21 * y + r22 * z
end

return Quat
