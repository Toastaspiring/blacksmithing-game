--!nocheck
-- m2x-fix-5: Lune µs to build one model (Cover.model) of a Cylinder, a Ball and a Block, median of 15 rounds of 200, with
-- its units and ns a unit; and Sampling's verdict on 24 parts of which 23 its own test hides at once.
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-5"
local function req(p)
	return (require :: any)(p)
end
local Shapes = req(W .. "/hook/src/shared/Physics/Shapes")
local Cover = req(W .. "/hook/src/shared/Physics/Cover")
local fmt = string.format
local parts = {
	{ id = 1, shape = "Cylinder", slot = "Blade", material = "Iron", pos = { 0.1, 2, 0.05 }, rot = { 0.1, 0.2, 0.3, 0.9273618495495703 }, size = { 0.2, 0.06, 0.06 } },
	{ id = 2, shape = "Ball", slot = "Blade", material = "Iron", pos = { 0.1, 2, 0.05 }, rot = { 0, 0, 0, 1 }, size = { 0.2, 0.2, 0.2 } },
	{ id = 3, shape = "Block", slot = "Blade", material = "Iron", pos = { 0.1, 2, 0.05 }, rot = { 0.1, 0.2, 0.3, 0.9273618495495703 }, size = { 0.2, 0.06, 0.1 } },
}
for _, p in ipairs(parts) do
	local P = Shapes.prepare(p, 1)
	local m = Cover.model(P)
	local t = {}
	for _ = 1, 15 do
		local t0 = os.clock()
		for _ = 1, 200 do
			Cover.model(P)
		end
		table.insert(t, (os.clock() - t0) / 200 * 1e6)
	end
	table.sort(t)
	print(fmt("%-8s model: %3d facets, %6.1f units, %6.2f µs, %5.1f ns a unit", p.shape, m.n, m.work, t[8], t[8] * 1000 / m.work))
end
