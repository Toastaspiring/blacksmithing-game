--!nocheck
-- V2 round 3: how far a round model's half-spaces, moved out by their sag, stand past the part's box, over every vertex
-- of that polytope (every triple of planes whose meeting point satisfies all the others), against OVER_BALL / OVER_CYLINDER.
local R = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Cover = require(R .. "/src/shared/Physics/Cover")
local fmt = string.format

local function check(shape, size, rot)
	local P = Shapes.prepare({ id = 1, slot = "Blade", shape = shape, material = "Iron", pos = { 0.1, 2, -0.05 }, rot = rot, size = size }, 1)
	local m = Cover.model(P)
	local p = m.planes
	local np = m.np
	local worst = -math.huge
	for i = 1, np - 2 do
		local a1, a2, a3, d1 = p[4 * i - 3], p[4 * i - 2], p[4 * i - 1], p[4 * i] + m.sag[i]
		for j = i + 1, np - 1 do
			local b1, b2, b3, d2 = p[4 * j - 3], p[4 * j - 2], p[4 * j - 1], p[4 * j] + m.sag[j]
			for k = j + 1, np do
				local c1, c2, c3, d3 = p[4 * k - 3], p[4 * k - 2], p[4 * k - 1], p[4 * k] + m.sag[k]
				local det = a1 * (b2 * c3 - b3 * c2) - a2 * (b1 * c3 - b3 * c1) + a3 * (b1 * c2 - b2 * c1)
				if math.abs(det) > 1e-9 then
					local x = (d1 * (b2 * c3 - b3 * c2) - a2 * (d2 * c3 - b3 * d3) + a3 * (d2 * c2 - b2 * d3)) / det
					local y = (a1 * (d2 * c3 - b3 * d3) - d1 * (b1 * c3 - b3 * c1) + a3 * (b1 * d3 - d2 * c1)) / det
					local z = (a1 * (b2 * d3 - d2 * c2) - a2 * (b1 * d3 - d2 * c1) + d1 * (b1 * c2 - b2 * c1)) / det
					local ok = true
					for l = 1, np do
						if p[4 * l - 3] * x + p[4 * l - 2] * y + p[4 * l - 1] * z > p[4 * l] + m.sag[l] + 1e-12 then
							ok = false
							break
						end
					end
					if ok then
						local out = math.max(x - P.maxx, P.minx - x, y - P.maxy, P.miny - y, z - P.maxz, P.minz - z)
						worst = math.max(worst, out)
					end
				end
			end
		end
	end
	print(fmt("%s size %s rot {%.3f,%.3f,%.3f,%.3f}: worst vertex past the box %.6f r, the model's over %.4f r", shape,
		table.concat(size, "×"), rot[1], rot[2], rot[3], rot[4], worst / P.r, m.over / P.r))
end

local S = math.sqrt(0.5)
for _, rot in ipairs({ { 0, 0, 0, 1 }, { 0, 0, S, S }, { 0.2, 0.3, 0.1, math.sqrt(1 - 0.04 - 0.09 - 0.01) }, { 0.5, 0.5, 0.5, 0.5 } }) do
	check("Ball", { 0.6, 0.6, 0.6 }, rot)
	check("Cylinder", { 1.0, 0.3, 0.3 }, rot)
	check("Cylinder", { 0.05, 0.6, 0.6 }, rot)
end
