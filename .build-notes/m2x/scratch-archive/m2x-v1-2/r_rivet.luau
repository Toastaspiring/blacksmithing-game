--!nocheck
-- A Ball set into a block's corner (or edge, or face), the block turned so its face normals run where the Ball's model lies
-- deepest under its sphere (0.0474 r along three perpendicular directions): the Ball pokes through each face by h, just
-- under that depth. Its model reaches no face, so it reads 0 % (buried); truly its caps show, about h/(2r) each.
local L = require("./lib")
local fmt = string.format
local Quat = L.Quat
local q = { -0.408255362455344, -0.40824817104248295, 6.7434908449009442e-06, 0.81649310457679225 }
local ux, vx, wx, uy, vy, wy, uz, vz, wz = Quat.toMatrix(q)
local U, V, W = { ux, uy, uz }, { vx, vy, vz }, { wx, wy, wz }
local function design(r, h, faces, side, centre, ballSlot, blockSlot)
	-- block of side `side`, its corner (+U, +V, +W) region holds the Ball: the Ball's centre at r − h inside each of
	-- `faces` faces (1: +U; 2: +U, +V; 3: all three), and deep inside along the others
	local depth = {}
	for k = 1, 3 do
		depth[k] = if k <= faces then (r - h) else (side / 2) -- distance from the Ball's centre to the +face
	end
	-- the Ball's centre in the block's frame: side/2 − depth along each axis
	local lb = { side / 2 - depth[1], side / 2 - depth[2], side / 2 - depth[3] }
	local c = centre
	local bc = {
		c[1] + lb[1] * U[1] + lb[2] * V[1] + lb[3] * W[1],
		c[2] + lb[1] * U[2] + lb[2] * V[2] + lb[3] * W[2],
		c[3] + lb[1] * U[3] + lb[2] * V[3] + lb[3] * W[3],
	}
	return {
		L.part(blockSlot or "Pommel", "Block", c, q, { side, side, side }),
		L.part(ballSlot or "Pommel", "Ball", bc, L.I, { 2 * r, 2 * r, 2 * r }),
	}
end
for _, r in ipairs({ 0.1, 0.15, 0.2 }) do
	for _, faces in ipairs({ 1, 2, 3 }) do
		local h = 0.046 * r
		local parts = design(r, h, faces, 2 * r + 0.06, { 0, 0, 0 })
		L.renumber(parts)
		local P = L.prep(parts)
		local read = L.readOf(P, 2)
		local _, _, hider = L.Oracle.flags(P)
		local truth = L.Oracle.share(P, 2, hider)
		local ex = L.Sampling.exposure(P)
		print(fmt("r %.2f, through %d face(s) by %.4f: reads %.3f%%, truth %.3f%% (h/2r × faces %.3f%%): %s", r, faces, h, 100 * read, 100 * truth, 100 * faces * h / (2 * r), ex.kept[2] and "kept" or "cleaned"))
	end
end
