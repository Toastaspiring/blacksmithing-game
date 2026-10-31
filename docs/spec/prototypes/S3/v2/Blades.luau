--!strict
-- S3 prototype v2: reference blade edges as S2 EdgeChains (blueprint XY studs, CCW: up the +X edge, over the tip,
-- down the -X edge), plus stress edges. Grip point and axis as S2 reports them.
local M = {}

local function chain(points: { { number } }): { points: { { number } }, length: number }
	local L = 0
	for i = 2, #points do
		local dx, dy = points[i][1] - points[i - 1][1], points[i][2] - points[i - 1][2]
		L += math.sqrt(dx * dx + dy * dy)
	end
	return { points = points, length = L }
end
M.chain = chain

-- S2 draft 4.6: arming sword (fixture F1) main chain, 6 points, length 5.604
M.arming = {
	name = "arming sword (F1, S2 main chain)",
	chains = { chain({ { 0.100, 1.480 }, { 0.100, 3.930 }, { 0.010, 4.260 }, { -0.020, 4.250 }, { -0.100, 3.930 }, { -0.100, 1.480 } }) },
	grip = { 0, 0.88, 0 },
	axis = { 0, 1 },
}

-- straight double edge with taper (the draft's "longsword" reference), as one CCW chain
local function doubleEdge(name: string, halfW: number, base: number, taperFrom: number, tip: number)
	return {
		name = name,
		chains = { chain({ { halfW, base }, { halfW, taperFrom }, { 0, tip }, { -halfW, taperFrom }, { -halfW, base } }) },
		grip = { 0, 0.88, 0 },
		axis = { 0, 1 },
	}
end
M.longsword = doubleEdge("longsword 3.6 st", 0.22, 1.48, 4.38, 5.08)
M.dagger = doubleEdge("dagger 1.5 st", 0.16, 1.48, 2.58, 2.98)

-- single curved edge (sabre): chain runs base -> tip on +X only
do
	local e = {}
	for i = 0, 16 do
		local y = 1.48 + 3.2 * i / 16
		table.insert(e, { 0.24 + 0.35 * ((y - 1.48) / 3.4) ^ 2, y })
	end
	table.insert(e, { 0.62, 1.48 + 3.45 })
	M.sabre = { name = "sabre, 1 curved edge 3.45 st", chains = { chain(e) }, grip = { 0, 0.88, 0 }, axis = { 0, 1 } }
end

-- flamberge: wavy edges voxelized at 0.05, one CCW chain
do
	local a, b = {}, {}
	local function q(x: number): number
		return math.floor(x / 0.05 + 0.5) * 0.05
	end
	for i = 0, 60 do
		local y = 1.48 + 3.0 * i / 60
		local w = 0.24 + 0.05 * math.sin(2 * math.pi * (y - 1.48) / 0.55)
		table.insert(a, { q(w), q(y) })
		table.insert(b, { q(-w), q(y) })
	end
	local pts = {}
	for _, p in a do
		table.insert(pts, p)
	end
	table.insert(pts, { 0, 1.48 + 3.7 })
	for i = #b, 1, -1 do
		table.insert(pts, b[i])
	end
	M.flamberge = { name = "flamberge, wavy, voxel 0.05", chains = { chain(pts) }, grip = { 0, 0.88, 0 }, axis = { 0, 1 } }
end

-- serrated / saw edges (R4b pt_stress): teeth of `depth` every `pitch`
local function serrated(name: string, len: number, halfW: number, pitch: number, depth: number)
	local a, b = {}, {}
	for i = 0, math.floor(len / pitch) do
		local y = 1.48 + i * pitch
		local w = if i % 2 == 0 then halfW else halfW - depth
		table.insert(a, { w, y })
		table.insert(b, { -w, y })
	end
	local pts = {}
	for _, p in a do
		table.insert(pts, p)
	end
	table.insert(pts, { 0, 1.48 + len + 0.3 })
	for i = #b, 1, -1 do
		table.insert(pts, b[i])
	end
	return { name = name, chains = { chain(pts) }, grip = { 0, 0.88, 0 }, axis = { 0, 1 } }
end
M.serrated = serrated("serrated 3.4 st, pitch 0.10, depth 0.10", 3.4, 0.20, 0.10, 0.10)
M.saw = serrated("saw 3.4 st, pitch 0.05, depth 0.15", 3.4, 0.25, 0.05, 0.15)

-- tilted grip (axis 30 deg from +Y) arming sword: same blade rotated about the grip point
do
	local ang = math.rad(30)
	local c, s = math.cos(ang), math.sin(ang)
	local pts = {}
	for _, p in M.arming.chains[1].points do
		local x, y = p[1], p[2] - 0.88
		table.insert(pts, { x * c - y * s, 0.88 + x * s + y * c })
	end
	M.tilted = { name = "arming sword, grip axis tilted 30 deg", chains = { chain(pts) }, grip = { 0, 0.88, 0 }, axis = { -s, c } }
end

-- 256-point zigzag in blueprint space spanning the blade (worst case for the source bound)
do
	local pts = {}
	for i = 0, 255 do
		local y = 1.48 + 3.4 * i / 255
		table.insert(pts, { if i % 2 == 0 then 0.30 else -0.30, y })
	end
	M.zigzag = { name = "zigzag 256 points, +-0.30 st", chains = { chain(pts) }, grip = { 0, 0.88, 0 }, axis = { 0, 1 } }
end

M.ORDER = { "arming", "longsword", "dagger", "sabre", "flamberge", "tilted", "serrated", "saw", "zigzag" }

return M
