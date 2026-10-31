--!strict
-- S6 prototype: conditioning of gizmo drag math vs view angle (pure, blueprint-space doubles).
-- Axis drag: closest point on the axis line to the mouse ray. Plane drag: ray/plane hit.
-- Measures how far (in blueprint studs) the result moves for a 1 px mouse jitter.
-- Run: lune run gizmo_math.luau

type V = { x: number, y: number, z: number }
local function v(x: number, y: number, z: number): V return { x = x, y = y, z = z } end
local function add(a: V, b: V): V return v(a.x + b.x, a.y + b.y, a.z + b.z) end
local function sub(a: V, b: V): V return v(a.x - b.x, a.y - b.y, a.z - b.z) end
local function mul(a: V, s: number): V return v(a.x * s, a.y * s, a.z * s) end
local function dot(a: V, b: V): number return a.x * b.x + a.y * b.y + a.z * b.z end
local function cross(a: V, b: V): V return v(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
local function unit(a: V): V local n = math.sqrt(dot(a, a)) return mul(a, 1 / n) end

-- param t of the point on line P + tA (A unit) closest to ray O + sD (D unit)
local function axisParam(P: V, A: V, O: V, D: V): number?
	local w0 = sub(P, O)
	local b = dot(A, D)
	local denom = 1 - b * b
	if denom < 1e-9 then return nil end
	local d, e = dot(A, w0), dot(D, w0)
	return (b * e - d) / denom
end

local function planeHit(P: V, N: V, O: V, D: V): V?
	local den = dot(N, D)
	if math.abs(den) < 1e-9 then return nil end
	local s = dot(sub(P, O), N) / den
	return add(O, mul(D, s))
end

-- camera at distance dist looking at origin along direction dir; pinhole with focal f px
local FOV, VH = 50, 1080
local f = (VH / 2) / math.tan(math.rad(FOV / 2))
local K = 4 -- display scale; we work in blueprint units: camera distance in bp = dist/K
local dist = 21.0 / K -- frame distance from camera_fit (display 21.0)

local function cameraRay(angleDeg: number, px: number): (V, V)
	-- axis = blueprint +Y (1 = along screen-right at 90 deg). camera direction makes angle with axis.
	local th = math.rad(angleDeg)
	local dir = unit(v(0, math.cos(th), math.sin(th))) -- view direction from camera toward target
	local O = mul(dir, -dist)
	-- camera basis: right = perpendicular in screen. choose up = X axis.
	local up = v(1, 0, 0)
	local right = unit(cross(dir, up))
	local trueUp = cross(right, dir)
	-- pixel offset px along the screen projection of the axis
	local axisScreen = unit(add(mul(right, dot(v(0, 1, 0), right)), mul(trueUp, dot(v(0, 1, 0), trueUp))))
	local D = unit(add(mul(dir, f), mul(axisScreen, px)))
	return O, D
end

print("angle(axis,view)  dt per 1px (bp studs)  ratio vs 90deg")
local base: number? = nil
for _, ang in { 90, 60, 45, 30, 20, 15, 10, 7, 5, 3 } do
	local O0, D0 = cameraRay(ang, 0)
	local O1, D1 = cameraRay(ang, 1)
	local t0 = axisParam(v(0, 0, 0), v(0, 1, 0), O0, D0)
	local t1 = axisParam(v(0, 0, 0), v(0, 1, 0), O1, D1)
	if t0 and t1 then
		local dt = math.abs(t1 - t0)
		base = base or dt
		print(string.format("%6d deg  %20.5f  %10.2fx", ang, dt, dt / (base :: number)))
	end
end

-- plane drag: plane z=0 (normal Z), view tilted toward edge-on
print("\nangle(plane,view)  hit shift per 1px (bp studs)")
for _, ang in { 90, 45, 30, 20, 15, 10, 5 } do
	local th = math.rad(ang)
	local dir = unit(v(0, math.cos(th), -math.sin(th)))
	local O = mul(dir, -dist)
	local right = unit(cross(dir, v(1, 0, 0)))
	local up = cross(right, dir)
	local D0 = dir
	local D1 = unit(add(mul(dir, f), right)); local _ = up
	local h0 = planeHit(v(0, 0, 0), v(0, 0, 1), O, D0)
	local h1 = planeHit(v(0, 0, 0), v(0, 0, 1), O, D1)
	if h0 and h1 then
		local d = math.sqrt(dot(sub(h1, h0), sub(h1, h0)))
		print(string.format("%6d deg  %12.5f", ang, d))
	end
end

-- screen-constant gizmo: length in bp studs for 110 design px at scale s, at camera distance d (bp)
print("\ngizmo arm length (bp studs) for 110 design px:")
for _, s in { 0.75, 1.0, 1.333 } do
	local line = ""
	for _, d in { 0.25, 1.0, 5.25, 20 } do
		local wpp = 2 * d * math.tan(math.rad(FOV / 2)) / VH -- bp studs per px at depth d
		line ..= string.format("  scale %.2f depth %5.2f bp -> %.4f bp  ", s, d, 110 * s * wpp)
	end
	print(line)
end
