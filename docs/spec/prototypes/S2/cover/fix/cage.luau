--!nocheck
-- V1's caged-Ball sword (m2x-v1-1/a_cagesword.luau + cagelib.luau), as PartData: 23 parts, the Ball part 5
local M = {}
function M.sword(r, g, b, ballSlot)
	r, g, b = r or 0.2, g or 0.002769, b or 0.051018
	local c = { 0, 2.4, 0 }
	local wallT, wallS = 0.02, 2 * r + 0.1
	local parts = {}
	local function add(slot, shape, pos, size)
		table.insert(parts, { id = #parts + 1, slot = slot, shape = shape, material = "Iron", pos = pos, rot = { 0, 0, 0, 1 }, size = size })
	end
	add("Grip", "Block", { 0, 0.75, 0 }, { 0.16, 0.9, 0.16 })
	add("Guard", "Block", { 0, 1.29, 0 }, { 1.0, 0.18, 0.24 })
	local wallBottom, wallTop = c[2] - (r + g + wallT), c[2] + (r + g + wallT)
	add("Blade", "Block", { 0, (1.38 + wallBottom) / 2, 0 }, { 0.16, wallBottom - 1.38, 0.06 })
	add("Blade", "Block", { 0, (wallTop + 4.0) / 2, 0 }, { 0.16, 4.0 - wallTop, 0.06 })
	add(ballSlot or "Blade", "Ball", { c[1], c[2], c[3] }, { 2 * r, 2 * r, 2 * r })
	local wallSlots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Pommel" }
	local k = 0
	for a = 1, 3 do
		for _, s in ipairs({ -1, 1 }) do
			k += 1
			local pos, size = { c[1], c[2], c[3] }, { wallS, wallS, wallS }
			pos[a] += s * (r + g + wallT / 2)
			size[a] = wallT
			add(wallSlots[k], "Block", pos, size)
		end
	end
	local edgeSlots = { "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip" }
	local E = r + 0.06
	k = 0
	for a = 1, 3 do
		for bb = a + 1, 3 do
			for _, sa in ipairs({ -1, 1 }) do
				for _, sb in ipairs({ -1, 1 }) do
					local lo, hi = { -E, -E, -E }, { E, E, E }
					if sa > 0 then lo[a] = b else hi[a] = -b end
					if sb > 0 then lo[bb] = b else hi[bb] = -b end
					local pos, size = {}, {}
					for q = 1, 3 do
						pos[q] = c[q] + (lo[q] + hi[q]) / 2
						size[q] = hi[q] - lo[q]
					end
					k += 1
					add(edgeSlots[k], "Block", pos, size)
				end
			end
		end
	end
	return parts
end
return M
