--!strict
-- S7 revision prototype: RenderPlan bounds from S1 PartData (camelCase, rot = {qx, qy, qz, qw}, w last) through
-- S1's Quat.toMatrix (s = 2/|q|^2, rows R00..R22), replacing S2's {w,x,y,z} path and the dropped Geometry.partMatrix.
-- Checks: (1) same arming-sword bounds as render_plan_native.luau; (2) toMatrix(k*q) == toMatrix(q) for k != 1;
-- (3) the 12 CFrame components are finite and the rotation is orthonormal with det +1; (4) BadSize / TooManyParts.
-- Run: lune run render_plan_partdata.luau

-- S1 Quat.toMatrix (verbatim formula from S1 §3.3): returns R00, R01, R02, R10, R11, R12, R20, R21, R22
local function toMatrix(q: { number }): (number, number, number, number, number, number, number, number, number)
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local s = 2 / (x * x + y * y + z * z + w * w)
	return 1 - s * (y * y + z * z), s * (x * y - z * w), s * (x * z + y * w),
		s * (x * y + z * w), 1 - s * (x * x + z * z), s * (y * z - x * w),
		s * (x * z - y * w), s * (y * z + x * w), 1 - s * (x * x + y * y)
end

local function qAxis(ax: number, ay: number, az: number, deg: number): { number }
	local a = math.rad(deg) / 2
	local s = math.sin(a)
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return { ax / n * s, ay / n * s, az / n * s, math.cos(a) } -- {qx, qy, qz, qw}
end

type PartData = { id: number, slot: string, shape: string, material: string, pos: { number }, rot: { number }, size: { number } }
local ID = { 0, 0, 0, 1 }
local ARMING: { PartData } = { -- S2 prototype arming sword, Steel blade (same data as render_plan_native.luau)
	{ id = 1, shape = "Ball", slot = "Pommel", material = "Iron", pos = { 0, 0.30, 0 }, rot = ID, size = { 0.30, 0.30, 0.30 } },
	{ id = 2, shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0, 0.88, 0 }, rot = qAxis(0, 0, 1, 90), size = { 0.90, 0.16, 0.16 } },
	{ id = 3, shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 1.40, 0 }, rot = ID, size = { 1.10, 0.16, 0.24 } },
	{ id = 4, shape = "Block", slot = "Blade", material = "Steel", pos = { 0, 2.65, 0 }, rot = ID, size = { 0.20, 2.50, 0.06 } },
	{ id = 5, shape = "Wedge", slot = "Blade", material = "Steel", pos = { 0.05, 4.10, 0 }, rot = qAxis(0, 1, 0, -90), size = { 0.06, 0.40, 0.10 } },
	{ id = 6, shape = "Wedge", slot = "Blade", material = "Steel", pos = { -0.05, 4.10, 0 }, rot = qAxis(0, 1, 0, 90), size = { 0.06, 0.40, 0.10 } },
}

local MIN_DIM, MAX_DIM, MAX_PARTS = 0.02, 6.0, 24

local VERTS: { [string]: { { number } } } = {
	Wedge = { { -1, -1, -1 }, { 1, -1, -1 }, { -1, -1, 1 }, { 1, -1, 1 }, { -1, 1, 1 }, { 1, 1, 1 } },
	CornerWedge = { { -1, -1, -1 }, { 1, -1, -1 }, { -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, -1 } },
}
do
	local b = {}
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				table.insert(b, { sx, sy, sz })
			end
		end
	end
	VERTS.Block = b
end

local function partBounds(p: PartData): ({ number }, { number })
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = toMatrix(p.rot)
	local R = { { r00, r01, r02 }, { r10, r11, r12 }, { r20, r21, r22 } }
	local h = { p.size[1] / 2, p.size[2] / 2, p.size[3] / 2 }
	local mn, mx = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	if p.shape == "Ball" then
		local r = math.min(h[1], h[2], h[3])
		for i = 1, 3 do
			mn[i], mx[i] = p.pos[i] - r, p.pos[i] + r
		end
	elseif p.shape == "Cylinder" then
		local r = math.min(h[2], h[3])
		for i = 1, 3 do
			local a = R[i][1] -- first column = local X (axis)
			local e = math.abs(a) * h[1] + r * math.sqrt(math.max(0, 1 - a * a))
			mn[i], mx[i] = p.pos[i] - e, p.pos[i] + e
		end
	else
		for _, v in VERTS[p.shape] do
			local l = { v[1] * h[1], v[2] * h[2], v[3] * h[3] }
			for i = 1, 3 do
				local w = p.pos[i] + R[i][1] * l[1] + R[i][2] * l[2] + R[i][3] * l[3]
				mn[i], mx[i] = math.min(mn[i], w), math.max(mx[i], w)
			end
		end
	end
	return mn, mx
end

local function plan(parts: { PartData }): (any, string?)
	if #parts == 0 then
		return nil, "Empty"
	end
	if #parts > MAX_PARTS then
		return nil, "TooManyParts"
	end
	local mn, mx = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, p in parts do
		for i = 1, 3 do
			if p.size[i] < MIN_DIM or p.size[i] > MAX_DIM then
				return nil, "BadSize"
			end
		end
		local a, b = partBounds(p)
		for i = 1, 3 do
			mn[i], mx[i] = math.min(mn[i], a[i]), math.max(mx[i], b[i])
		end
	end
	return { min = mn, max = mx }
end

local function f(v: { number }): string
	return string.format("(%.2f, %.2f, %.2f)", v[1], v[2], v[3])
end

local fails = 0
local function check(name: string, ok: boolean, detail: string?)
	print((ok and "PASS " or "FAIL ") .. name .. (detail and ("  " .. detail) or ""))
	if not ok then
		fails += 1
	end
end

-- (1) bounds equal the w-first prototype's result (-0.55, 0.15, -0.15) .. (0.55, 4.30, 0.15)
local b = plan(ARMING)
local want = { min = { -0.55, 0.15, -0.15 }, max = { 0.55, 4.30, 0.15 } }
local err = 0
for i = 1, 3 do
	err = math.max(err, math.abs(b.min[i] - want.min[i]), math.abs(b.max[i] - want.max[i]))
end
check("arming sword bounds via PartData + Quat.toMatrix", err < 1e-9, f(b.min) .. " .. " .. f(b.max) .. string.format(" max err %.1e", err))

-- (2) non-unit quaternion gives the same matrix (s = 2/|q|^2)
local q = qAxis(1, 2, 3, 37)
local k = 1.0037
local m1 = { toMatrix(q) }
local m2 = { toMatrix({ q[1] * k, q[2] * k, q[3] * k, q[4] * k }) }
local d = 0
for i = 1, 9 do
	d = math.max(d, math.abs(m1[i] - m2[i]))
end
check("toMatrix(k*q) == toMatrix(q)", d < 1e-12, string.format("max diff %.1e", d))

-- (3) orthonormal, det +1 over random quaternions
math.randomseed(7)
local function u(): number
	return math.random() * 2 - 1
end
local worst, worstDet = 0, 0
for _ = 1, 20000 do
	local qq = { u(), u(), u(), u() }
	local r = { toMatrix(qq) }
	local R = { { r[1], r[2], r[3] }, { r[4], r[5], r[6] }, { r[7], r[8], r[9] } }
	for i = 1, 3 do
		for j = 1, 3 do
			local dot = R[1][i] * R[1][j] + R[2][i] * R[2][j] + R[3][i] * R[3][j]
			worst = math.max(worst, math.abs(dot - (i == j and 1 or 0)))
		end
	end
	local det = R[1][1] * (R[2][2] * R[3][3] - R[2][3] * R[3][2]) - R[1][2] * (R[2][1] * R[3][3] - R[2][3] * R[3][1])
		+ R[1][3] * (R[2][1] * R[3][2] - R[2][2] * R[3][1])
	worstDet = math.max(worstDet, math.abs(det - 1))
end
check("orthonormal columns, det +1 (20,000 random q)", worst < 1e-12 and worstDet < 1e-12, string.format("orth %.1e det %.1e", worst, worstDet))

-- (4) error codes
local thin = table.clone(ARMING)
thin[4] = table.clone(ARMING[4])
thin[4].size = { 0.20, 2.50, 0.019 }
local _, e1 = plan(thin)
check("size below MIN_DIM -> BadSize", e1 == "BadSize")
local many = {}
for i = 1, MAX_PARTS + 1 do
	many[i] = ARMING[3]
end
local _, e2 = plan(many)
check("25 parts -> TooManyParts", e2 == "TooManyParts")
local _, e3 = plan({})
check("no parts -> Empty", e3 == "Empty")
print(fails .. " failures")
