--!strict
-- S2 prototype v2: Blueprint/Mirror (RULINGS 2.13). The only mirror implementation: reflect a PartData across the
-- fixed blueprint planes x = 0 ("X", left/right) or z = 0 ("Z", front/back). No negative scale: the image of a
-- placed shape is the same shape with a proper rotation (and, for a CornerWedge, its X and Z sizes swapped).
-- Quat = {qx, qy, qz, qw}. Only + - * / and the literal SQRT_HALF.
local Quat = require("./quat")

local Mirror = {}
local H = 0.70710678118654757 -- sqrt(0.5), exact IEEE double

-- right factors (local symmetry of the shape): Block/Wedge/Cylinder/Ball reflect local X; CornerWedge uses the
-- diagonal reflection (x, y, z) -> (-z, y, -x), hence the size swap.
local F_X_CORNER = { 0, H, 0, H } -- +90 deg about local Y
local F_Z_PLAIN = { 0, 1, 0, 0 } -- 180 deg about local Y
local F_Z_CORNER = { 0, -H, 0, H } -- -90 deg about local Y

function Mirror.reflect(p: any, plane: string): any
	local q = p.rot
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local pos = { p.pos[1], p.pos[2], p.pos[3] }
	local size = { p.size[1], p.size[2], p.size[3] }
	local r
	if plane == "X" then
		pos[1] = -pos[1]
		r = { x, -y, -z, w }
		if p.shape == "CornerWedge" then
			r = Quat.mul(r, F_X_CORNER)
		end
	elseif plane == "Z" then
		pos[3] = -pos[3]
		r = { -x, -y, z, w }
		r = Quat.mul(r, if p.shape == "CornerWedge" then F_Z_CORNER else F_Z_PLAIN)
	else
		error("plane must be X or Z")
	end
	if p.shape == "CornerWedge" then
		size = { size[3], size[2], size[1] }
	end
	-- -0 -> 0 and the hemisphere rule (S1 Canonical would also apply them)
	pos = { pos[1] + 0, pos[2] + 0, pos[3] + 0 }
	return { id = p.id, label = p.label, shape = p.shape, slot = p.slot, material = p.material, pos = pos, rot = Quat.canonical(r), size = size }
end

return Mirror
