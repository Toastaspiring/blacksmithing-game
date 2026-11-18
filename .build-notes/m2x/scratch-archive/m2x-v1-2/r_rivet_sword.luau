--!nocheck
-- F5 with its pommel a turned cube and a Ball set into the cube's corner (3 faces) or edge (2): valid? the Ball's reading,
-- truth, and D through the emulator under the build's verdict and under the truth's
local L = require("./lib")
local fmt = string.format
local Quat = L.Quat
local q = { -0.408255362455344, -0.40824817104248295, 6.7434908449009442e-06, 0.81649310457679225 }
local ux, vx, wx, uy, vy, wy, uz, vz, wz = Quat.toMatrix(q)
local U, V, W = { ux, uy, uz }, { vx, vy, vz }, { wx, wy, wz }
local function run(r, faces, ballSlot, side, kfrac)
	local h = (kfrac or 0.046) * r
	local base = L.repoFixture("F5")
	local parts = {}
	for i = 2, #base do table.insert(parts, base[i]) end
	-- the cube: its lowest point at y = 0.03
	local ext = side / 2 * (math.abs(U[2]) + math.abs(V[2]) + math.abs(W[2]))
	local c = { 0, 0.03 + ext, 0 }
	local depth = {}
	for k = 1, 3 do depth[k] = if k <= faces then (r - h) else (side / 2) end
	local lb = { side / 2 - depth[1], side / 2 - depth[2], side / 2 - depth[3] }
	local bc = { c[1] + lb[1] * U[1] + lb[2] * V[1] + lb[3] * W[1], c[2] + lb[1] * U[2] + lb[2] * V[2] + lb[3] * W[2],
		c[3] + lb[1] * U[3] + lb[2] * V[3] + lb[3] * W[3] }
	table.insert(parts, L.part("Pommel", "Block", c, q, { side, side, side }))
	table.insert(parts, L.part(ballSlot, "Ball", bc, L.I, { 2 * r, 2 * r, 2 * r }))
	L.renumber(parts)
	local bi = #parts
	local okc, why = L.canonical(L.copyParts(parts))
	local run = L.run(L.copyParts(parts), { measureInvalid = false })
	local P = L.prep(parts)
	local e = L.Sampling.exposure(P)
	local read = L.readOf(P, bi)
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.share(P, bi, hider)
	print(fmt("F5, pommel a turned cube %.2f (top %.3f), a Ball r %.2f in its %s through %d face(s) by %.4f, in the %s: canonical %s, valid %s (%s)",
		side, c[2] + ext, r, faces == 3 and "corner" or faces == 2 and "edge" or "face", faces, h, ballSlot, tostring(okc), tostring(run.validation.ok), L.codes(run)))
	print(fmt("   the Ball reads %.3f%% (%s), truth %.3f%%", 100 * read, e.kept[bi] and "kept" or "cleaned", 100 * truth))
	local Rb = L.emu(L.copyParts(parts))
	local row = table.clone(e.kept)
	row[bi] = truth >= 0.02
	local Rt = L.emu(L.copyParts(parts), row)
	local d, t, s = L.dDiff(Rb, Rt)
	print("   build " .. L.dline(Rb))
	print("   truth " .. L.dline(Rt))
	print(fmt("   |dD| %.4f on %s, tier flip %s", d, s, tostring(t)))
end
run(0.1, 3, "Pommel", 0.34)
run(0.1, 2, "Pommel", 0.34)
run(0.12, 3, "Pommel", 0.34)
run(0.1, 3, "Blade", 0.34)
