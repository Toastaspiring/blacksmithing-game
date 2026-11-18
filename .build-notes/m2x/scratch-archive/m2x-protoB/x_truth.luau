--!nocheck
-- V2: the attack designs' true shares by a plain grid of my own: §4.4's hide test point by point, on the build's Shapes.sd and rank; the verdict through the unmodified Sampling.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sampling = require("./repo/src/shared/Physics/Sampling")
local fmt = string.format
local EPS, DELTA = 1e-7, 0.012

local designs = serde.decode("json", fs.readFile("out/attacks.json"))
for _, d in ipairs(designs) do
	local P = {}
	for i, part in ipairs(d.parts) do P[i] = Shapes.prepare(part, i) end
	local rank = Sampling.ranked(P)
	local exposure = Sampling.exposure(P)
	-- the core: the part at z = 0, widest, of the blade: id 4
	local i = 4
	local p = P[i]
	local function hidden(x, y, z, nx, ny, nz)
		local ox, oy, oz = x + DELTA * nx, y + DELTA * ny, z + DELTA * nz
		for j = 1, #P do
			if j ~= i then
				local q = P[j]
				if Shapes.aabbContains(q, x, y, z, 2 * EPS) then
					local d0 = Shapes.sd(q, x, y, z)
					if d0 < -EPS or (rank[j] < rank[i] and d0 <= EPS) then return true end
				end
				if Shapes.aabbContains(q, ox, oy, oz, 2 * EPS) and Shapes.sd(q, ox, oy, oz) <= EPS then return true end
			end
		end
		return false
	end
	local shown, total = 0, 0
	local H = 0.0011 -- no multiple of the lines' pitch
	local function face(ax, ay, az, bx, by, bz, cx, cy, cz, nx, ny, nz, la, lb)
		local na, nb = math.ceil(la / H), math.ceil(lb / H)
		local w = la * lb / (na * nb)
		for a = 0, na - 1 do
			local s = (a + 0.5) / na - 0.5
			for b = 0, nb - 1 do
				local t = (b + 0.5) / nb - 0.5
				total += w
				if not hidden(cx + s * la * ax + t * lb * bx, cy + s * la * ay + t * lb * by, cz + s * la * az + t * lb * bz, nx, ny, nz) then
					shown += w
				end
			end
		end
	end
	local ex, ey, ez = 2 * p.hx, 2 * p.hy, 2 * p.hz
	for s = -1, 1, 2 do
		face(p.vx, p.vy, p.vz, p.wx, p.wy, p.wz, p.cx + s * p.hx * p.ux, p.cy + s * p.hx * p.uy, p.cz + s * p.hx * p.uz, s * p.ux, s * p.uy, s * p.uz, ey, ez)
		face(p.ux, p.uy, p.uz, p.wx, p.wy, p.wz, p.cx + s * p.hy * p.vx, p.cy + s * p.hy * p.vy, p.cz + s * p.hy * p.vz, s * p.vx, s * p.vy, s * p.vz, ex, ez)
		face(p.ux, p.uy, p.uz, p.vx, p.vy, p.vz, p.cx + s * p.hz * p.wx, p.cy + s * p.hz * p.wy, p.cz + s * p.hz * p.wz, s * p.wx, s * p.wy, s * p.wz, ex, ey)
	end
	print(fmt("%-58s id %d %s %.2f x %.2f x %.2f: grid share %.3f %%, build %s", d.name, p.id, p.shape, ex, ey, ez, shown / total * 100, if exposure.kept[i] then "kept" else "cleaned"))
end
