--!nocheck
local M = {}
function M.cage(L, r, g, b, wallT, wallS, c)
	wallT = wallT or 0.02
	wallS = wallS or 2 * r + 0.1
	c = c or { 0, 2.5, 0 }
	local parts = {}
	table.insert(parts, L.part("Pommel", "Ball", c, L.I, { 2 * r, 2 * r, 2 * r }))
	for a = 1, 3 do
		for _, s in ipairs({ -1, 1 }) do
			local pos = { c[1], c[2], c[3] }
			pos[a] += s * (r + g + wallT / 2)
			local size = { wallS, wallS, wallS }
			size[a] = wallT
			table.insert(parts, L.part("Blade", "Block", pos, L.I, size))
		end
	end
	local E = r + 0.06
	for a = 1, 3 do
		for bb = a + 1, 3 do
			for _, sa in ipairs({ -1, 1 }) do
				for _, sb in ipairs({ -1, 1 }) do
					local lo, hi = { -E, -E, -E }, { E, E, E }
					if sa > 0 then lo[a] = b else hi[a] = -b end
					if sb > 0 then lo[bb] = b else hi[bb] = -b end
					local pos, size = {}, {}
					for k = 1, 3 do
						pos[k] = c[k] + (lo[k] + hi[k]) / 2
						size[k] = hi[k] - lo[k]
					end
					table.insert(parts, L.part("Guard", "Block", pos, L.I, size))
				end
			end
		end
	end
	return L.renumber(parts)
end
return M
