--!nocheck
-- m2x-fix-5: O9 (b) along a Cylinder's prism side, not only at its corners. A round guard disk (a Cylinder r 0.8 along Z,
-- 0.5 long, the largest round part a sword's hitbox holds) and a plate (Block, Wedge or CornerWedge) w across × 0.02
-- (radial) × b along the axis, lying flat on a side of the disk's prism (its outer face parallel to the prism's face over
-- edge 1), centred y_c from the edge's middle along it, its outer face's plane δ inside the true side on the edge's middle
-- line: at y from that line it stands y²/2r − δ out of the true side, and over the edge's length (2r·tan(π/32) = 0.1576)
-- it lies within the prism. The reading (the build) against the truth (VisibleOracle, 400,000 points).
--   lune run plate_side -- [tree root] [NS: the tree's prism has NS sides (mkprism.py); plates sized to its sides]
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-5"
local root = process.args[1] or (W .. "/hook")
local NS = tonumber(process.args[2]) or 32
local function req(p)
	return (require :: any)(root .. "/" .. p)
end
local Shapes = req("src/shared/Physics/Shapes")
local Sampling = req("src/shared/Physics/Sampling")
local Cover = req("src/shared/Physics/Cover")
local Quat = req("src/shared/Blueprint/Quat")
local Oracle = req("tests/Physics/VisibleOracle")
local fmt = string.format
local R, C = 0.8, { 0, 2, 0 }
local S45 = 0.70710678118654757
local Y90 = { 0, S45, 0, S45 }
local T32 = 0.098491403357164253 -- tan(π/32)

local function part(slot, shape, pos, rot, size)
	return { id = 0, label = shape, shape = shape, slot = slot, material = "Iron", pos = { pos[1], pos[2], pos[3] }, rot = rot,
		size = { size[1], size[2], size[3] } }
end

-- the reading of part 2 against the disk, as Sampling hands it over (the disk ranks higher)
local function reads(P)
	local m1, m2 = Cover.model(P[1]), Cover.model(P[2])
	return Cover.shown(m2, { m1 }, { true }, math.huge, math.huge) / m2.total
end

local disk = part("Guard", "Cylinder", C, Y90, { 0.5, 2 * R, 2 * R })
local P0 = Shapes.prepare(disk, 1)
local m0 = Cover.model(P0)
-- edge 1's middle: its facet's normal n; the plate's frame: local −Y along n (its bottom, a Wedge's and a CornerWedge's
-- whole rectangle, outward, as V1's plate_cyl2.luau lays them), local Z along the axis, local X = Y × Z
local n = { m0.nx[1], m0.ny[1], m0.nz[1] }
local y = { -n[1], -n[2], -n[3] }
local z = { P0.ux, P0.uy, P0.uz }
local x = { y[2] * z[3] - y[3] * z[2], y[3] * z[1] - y[1] * z[3], y[1] * z[2] - y[2] * z[1] }
local q = Quat.hemisphere(Quat.normalize(Quat.fromMatrix(x[1], y[1], z[1], x[2], y[2], z[2], x[3], y[3], z[3])))
local half = if NS == 32 then R * T32 else R * math.tan(math.pi / NS)
print(fmt("disk r %.1f, %d sides: the prism's side over an edge %.4f long, its corners %.5f past the true side", R, NS, 2 * half, R * (math.sqrt(1 + (half / R) ^ 2) - 1)))
for _, shape in ipairs({ "Block", "Wedge", "CornerWedge" }) do
	local sizes = if NS == 32 then { { 0.15, 0.5 }, { 0.10, 0.5 }, { 0.07, 0.5 }, { 0.065, 0.4 }, { 0.04, 0.5 } }
		else { { 1.9 * half, 0.5 }, { 1.2 * half, 0.5 }, { 0.8 * half, 0.5 } }
	for _, wb in ipairs(sizes) do
		local w, b = wb[1], wb[2]
		for _, yc in ipairs({ 0, half / 2, half - w / 2 - 1e-4 }) do
			if math.abs(yc) + w / 2 <= half and (yc == 0 or w <= half) then
				for _, f in ipairs({ 1e-6, 1e-5, 1e-4 }) do
					local delta = f * R
					local k = R - delta - 0.01
					local pos = { C[1] + k * n[1] + yc * x[1], C[2] + k * n[2] + yc * x[2], C[3] + k * n[3] + yc * x[3] }
					local parts = { disk, part("Blade", shape, pos, q, { w, 0.02, b }) }
					parts[1].id, parts[2].id = 1, 2
					local P = { Shapes.prepare(parts[1], 1), Shapes.prepare(parts[2], 2) }
					if P[2].volume >= 0.0002 then
						local _, _, hider = Oracle.flags(P)
						local truth = Oracle.measure(P, 2, hider, 400000)
						local r = reads(P)
						local far = (math.abs(yc) + w / 2) ^ 2 / (2 * R) - delta
						print(fmt("%-11s %.3f × 0.02 × %.1f, centred %.4f from the middle, δ %.0e r: out by up to %.5f; reads %6.3f%%, truly %6.3f%%%s",
							shape, w, b, yc, f, far, 100 * r, 100 * truth, if (r >= 0.02) ~= (truth >= 0.02) then "  <- cleaned" else ""))
					end
				end
			end
		end
	end
end
