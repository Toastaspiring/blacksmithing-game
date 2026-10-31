--!strict
-- S6 prototype: check the closed quaternion forms of the mirror table (§11.14) against the matrix forms.
-- q = {w,x,y,z}; R(q) rows; S = reflection; forms: Block/Ball/Cyl S R S; Wedge S R Fx; CornerWedge S R G (sigma=-1)
-- Run: lune run mirror_quat.luau

type Q = { w: number, x: number, y: number, z: number }
type M = { { number } }

local function qmul(p: Q, q: Q): Q
	return {
		w = p.w * q.w - p.x * q.x - p.y * q.y - p.z * q.z,
		x = p.w * q.x + p.x * q.w + p.y * q.z - p.z * q.y,
		y = p.w * q.y - p.x * q.z + p.y * q.w + p.z * q.x,
		z = p.w * q.z + p.x * q.y - p.y * q.x + p.z * q.w,
	}
end
local function mat(q: Q): M
	local w, x, y, z = q.w, q.x, q.y, q.z
	return {
		{ 1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y) },
		{ 2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x) },
		{ 2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y) },
	}
end
local function mm(a: M, b: M): M
	local r = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
	for i = 1, 3 do
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end
local function maxdiff(a: M, b: M): number
	local d = 0
	for i = 1, 3 do
		for j = 1, 3 do
			d = math.max(d, math.abs(a[i][j] - b[i][j]))
		end
	end
	return d
end
local function diag(a: number, b: number, c: number): M
	return { { a, 0, 0 }, { 0, b, 0 }, { 0, 0, c } }
end
local h = math.sqrt(0.5)
local qY90, qYm90, qY180 = { w = h, x = 0, y = h, z = 0 }, { w = h, x = 0, y = -h, z = 0 }, { w = 0, x = 0, y = 1, z = 0 }
local Sx, Sz = diag(-1, 1, 1), diag(1, 1, -1)
local Fx = diag(-1, 1, 1)
local G = { { 0, 0, -1 }, { 0, 1, 0 }, { -1, 0, 0 } } -- sigma = -1 (S2 apex (+,+,-))

local seed = 99
local function rnd(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648 * 2 - 1
end

local worst = { 0, 0, 0, 0, 0, 0 }
for _ = 1, 20000 do
	local q = { w = rnd(), x = rnd(), y = rnd(), z = rnd() }
	local n = math.sqrt(q.w ^ 2 + q.x ^ 2 + q.y ^ 2 + q.z ^ 2)
	q = { w = q.w / n, x = q.x / n, y = q.y / n, z = q.z / n }
	local R = mat(q)
	local cx = { w = q.w, x = q.x, y = -q.y, z = -q.z }
	local cz = { w = q.w, x = -q.x, y = -q.y, z = q.z }
	worst[1] = math.max(worst[1], maxdiff(mat(cx), mm(mm(Sx, R), Sx)))           -- block x
	worst[2] = math.max(worst[2], maxdiff(mat(cz), mm(mm(Sz, R), Sz)))           -- block z
	worst[3] = math.max(worst[3], maxdiff(mat(cx), mm(mm(Sx, R), Fx)))           -- wedge x
	worst[4] = math.max(worst[4], maxdiff(mat(qmul(cz, qY180)), mm(mm(Sz, R), Fx))) -- wedge z
	worst[5] = math.max(worst[5], maxdiff(mat(qmul(cx, qY90)), mm(mm(Sx, R), G)))   -- cornerwedge x
	worst[6] = math.max(worst[6], maxdiff(mat(qmul(cz, qYm90)), mm(mm(Sz, R), G)))  -- cornerwedge z
end
print(string.format("max |R(form) - matrix| over 20k random q: Block x %.1e z %.1e | Wedge x %.1e z %.1e | CornerWedge x %.1e z %.1e",
	worst[1], worst[2], worst[3], worst[4], worst[5], worst[6]))
