--!strict
-- Throwaway S7 prototype: minimal pure vector / 3x3 / rigid-transform math (Roblox CFrame semantics).
-- Mat3 is row-major {r00,r01,r02, r10,r11,r12, r20,r21,r22}; its COLUMNS are the local axes in parent space
-- (same layout as CFrame.new(x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22)).

local V = {}

export type Vec3 = { number }
export type Mat3 = { number }
export type Xform = { p: Vec3, r: Mat3 }
export type Obb = { c: Vec3, r: Mat3, h: Vec3 }

function V.v(x: number, y: number, z: number): Vec3
	return { x, y, z }
end
function V.add(a: Vec3, b: Vec3): Vec3
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end
function V.sub(a: Vec3, b: Vec3): Vec3
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
function V.scale(a: Vec3, s: number): Vec3
	return { a[1] * s, a[2] * s, a[3] * s }
end
function V.dot(a: Vec3, b: Vec3): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
function V.cross(a: Vec3, b: Vec3): Vec3
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
function V.len(a: Vec3): number
	return math.sqrt(V.dot(a, a))
end
function V.norm(a: Vec3): Vec3
	local l = V.len(a)
	return { a[1] / l, a[2] / l, a[3] / l }
end

V.I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

function V.mmul(a: Mat3, b: Mat3): Mat3
	local r = table.create(9, 0)
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end

function V.mapply(m: Mat3, v: Vec3): Vec3
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

function V.transpose(m: Mat3): Mat3
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end

function V.det(m: Mat3): number
	return m[1] * (m[5] * m[9] - m[6] * m[8]) - m[2] * (m[4] * m[9] - m[6] * m[7]) + m[3] * (m[4] * m[8] - m[5] * m[7])
end

function V.col(m: Mat3, k: number): Vec3
	return { m[k], m[3 + k], m[6 + k] }
end

-- Rotations identical to CFrame.Angles(rx,0,0) / (0,ry,0) / (0,0,rz)
function V.rotX(deg: number): Mat3
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
function V.rotY(deg: number): Mat3
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
function V.rotZ(deg: number): Mat3
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

-- unit quaternion (w,x,y,z) -> Mat3 (exact arithmetic, no trig)
function V.fromQuat(w: number, x: number, y: number, z: number): Mat3
	return {
		1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
		2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
		2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y),
	}
end

function V.xf(p: Vec3, r: Mat3?): Xform
	return { p = p, r = r or V.I }
end
function V.compose(a: Xform, b: Xform): Xform
	return { p = V.add(a.p, V.mapply(a.r, b.p)), r = V.mmul(a.r, b.r) }
end
function V.point(a: Xform, v: Vec3): Vec3
	return V.add(a.p, V.mapply(a.r, v))
end
function V.inverse(a: Xform): Xform
	local rt = V.transpose(a.r)
	return { p = V.scale(V.mapply(rt, a.p), -1), r = rt }
end
-- Roblox LookVector = -Z column
function V.look(a: Xform): Vec3
	return V.scale(V.col(a.r, 3), -1)
end

-- Segment p0->p1 vs OBB (slab test). Returns entry fraction t in [0,1] or nil.
function V.segObb(p0: Vec3, p1: Vec3, o: Obb): number?
	local rt = V.transpose(o.r)
	local a = V.mapply(rt, V.sub(p0, o.c))
	local b = V.mapply(rt, V.sub(p1, o.c))
	local tmin, tmax = 0, 1
	for i = 1, 3 do
		local d = b[i] - a[i]
		if math.abs(d) < 1e-12 then
			if a[i] < -o.h[i] or a[i] > o.h[i] then
				return nil
			end
		else
			local t1 = (-o.h[i] - a[i]) / d
			local t2 = (o.h[i] - a[i]) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tmin then
				tmin = t1
			end
			if t2 < tmax then
				tmax = t2
			end
			if tmin > tmax then
				return nil
			end
		end
	end
	return tmin
end

function V.pointObbDist(p: Vec3, o: Obb): number
	local l = V.mapply(V.transpose(o.r), V.sub(p, o.c))
	local d = { 0, 0, 0 }
	for i = 1, 3 do
		local q = math.clamp(l[i], -o.h[i], o.h[i])
		d[i] = l[i] - q
	end
	return V.len(d)
end

-- OBB vs OBB separating-axis test (true = overlapping, with tolerance eps of penetration ignored)
function V.obbOverlap(A: Obb, B: Obb, eps: number?): boolean
	local e = eps or 0
	local axes: { Vec3 } = {}
	for i = 1, 3 do
		table.insert(axes, V.col(A.r, i))
		table.insert(axes, V.col(B.r, i))
	end
	for i = 1, 3 do
		for j = 1, 3 do
			local c = V.cross(V.col(A.r, i), V.col(B.r, j))
			if V.len(c) > 1e-9 then
				table.insert(axes, V.norm(c))
			end
		end
	end
	local t = V.sub(B.c, A.c)
	for _, ax in axes do
		local ra = 0
		local rb = 0
		for i = 1, 3 do
			ra += A.h[i] * math.abs(V.dot(V.col(A.r, i), ax))
			rb += B.h[i] * math.abs(V.dot(V.col(B.r, i), ax))
		end
		if math.abs(V.dot(t, ax)) > ra + rb - e then
			return false
		end
	end
	return true
end

function V.fmt(v: Vec3): string
	return string.format("(%.2f, %.2f, %.2f)", v[1], v[2], v[3])
end

return V
