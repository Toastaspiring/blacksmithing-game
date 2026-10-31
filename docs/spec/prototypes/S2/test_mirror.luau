-- General mirror across plane (unit normal n, point c): p' = p - 2((p-c).n) n ;
-- q' = canon((n*q*n) * f), f = (n.e, -(n x e)), e = local symmetry normal: (1,0,0), CornerWedge (1,0,1)/sqrt2 (+ size swap X<->Z)
local Shapes = require("./shapes")
local Swords = require("./swords")
local function qmulPure(nx, ny, nz, q) return Swords.qmul({ 0, nx, ny, nz }, q) end
local function mirror(p, n, c)
	local nx, ny, nz = n[1], n[2], n[3]
	local q = Swords.qmul(qmulPure(nx, ny, nz, p.rot), { 0, nx, ny, nz })
	local ex, ey, ez = 1, 0, 0
	local size = { p.size[1], p.size[2], p.size[3] }
	if p.shape == "CornerWedge" then
		ex, ez = math.sqrt(0.5), math.sqrt(0.5)
		size = { p.size[3], p.size[2], p.size[1] }
	end
	local dot = nx * ex + ny * ey + nz * ez
	local cx, cy, cz = ny * ez - nz * ey, nz * ex - nx * ez, nx * ey - ny * ex
	q = Swords.qmul(q, { dot, -cx, -cy, -cz })
	local d = (p.pos[1] - c[1]) * nx + (p.pos[2] - c[2]) * ny + (p.pos[3] - c[3]) * nz
	return Swords.part("M", p.shape, p.slot, p.material, { p.pos[1] - 2 * d * nx, p.pos[2] - 2 * d * ny, p.pos[3] - 2 * d * nz }, q, size)
end
local n0 = { 0.97, -0.24, 0.05 }
local l = math.sqrt(n0[1]^2 + n0[2]^2 + n0[3]^2)
local n = { n0[1] / l, n0[2] / l, n0[3] / l }
local c = { 0.05, 1.3, -0.02 }
for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
	local q = Swords.qmul(Swords.qAxis(0.3, 1, 0.2, 37), Swords.qAxis(1, 0.1, 0.4, 61))
	local p = Swords.part("A", shape, "Guard", "Iron", { 0.31, 1.7, 0.05 }, q, { 0.11, 0.23, 0.37 })
	local m = mirror(p, n, c)
	local PA = Shapes.prepare(Shapes.sanitizePart(p), 1)
	local PB = Shapes.prepare(Shapes.sanitizePart(m), 1)
	local xs, ys, zs = Shapes.volumeSamples(PA, 0.015, 3, 60, 40000)
	local worst = -math.huge
	for k = 1, #xs do
		local d = (xs[k] - c[1]) * n[1] + (ys[k] - c[2]) * n[2] + (zs[k] - c[3]) * n[3]
		local s = Shapes.sd(PB, xs[k] - 2 * d * n[1], ys[k] - 2 * d * n[2], zs[k] - 2 * d * n[3])
		if s > worst then worst = s end
	end
	print(string.format("%-12s samples=%d  max sd of mirrored samples in B = %.2e (<= 0 means all inside)  vol %.6f / %.6f", shape, #xs, worst, PA.volume, PB.volume))
end
