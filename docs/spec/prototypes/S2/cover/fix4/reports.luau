--!nocheck
-- fix-4 (fix3/reports.luau; fix2/reports.luau with the trees by root and the designs from the repo): the largest single report through spend
-- (Sampling.exposure, the verdict and the measure), per tree, over the fixtures, the attack designs, worst_designs.luau
-- (valid and past the cap) and V1's caps under a Ball (h_report.json and its 3 parts alone), and the plate ringed by 20 Balls
-- of Cover.spec (f); the work between a report and the next is what a report carries.
--   lune run reports -- <tree root> [<tree root> ...]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local REPO = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local fmt = string.format
local function req(p)
	return (require :: any)(p)
end
local Fx = req(REPO .. "/docs/spec/prototypes/S2/v2/fixtures")
local B = req(REPO .. "/tests/fixtures/Blueprints")
local Attacks = req(REPO .. "/tests/Physics/CoverAttacks")
local Worst = req(REPO .. "/docs/spec/prototypes/S2/cover/worst_designs")
local designs = {}
local function add(name, parts)
	table.insert(designs, { name = name, parts = parts })
end
for _, b in ipairs(Fx.calibration()) do add(b.name, b.parts) end
for _, b in ipairs(Fx.golden()) do add(b.name, b.parts) end
for _, x in ipairs(Fx.regression()) do add(x.fixture.name, x.fixture.parts) end
for _, b in ipairs(Fx.perf()) do add(b.name, b.parts) end
for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do add(id, B.core(id).parts) end
for _, d in ipairs(Attacks) do add("attack " .. d.name, d.parts) end
for _, d in ipairs(Worst.valid) do add("worst " .. d.name, d.parts) end
for _, d in ipairs(Worst.tooComplex) do add("past the cap " .. d.name, d.parts) end
local sword = serde.decode("json", fs.readFile(SCR .. "/m2x-v1-2/out/h_report.json"))
add("V1's sword (h_report.json)", sword.parts or sword)
local I, Z90 = { 0, 0, 0, 1 }, { 0, 0, 0.70710678118654757, 0.70710678118654757 }
add("a cap 0.006 proud under a Ball r 0.04, alone", {
	{ id = 1, slot = "Blade", shape = "Block", material = "Iron", pos = { 0, 1, 0 }, rot = I, size = { 0.7, 0.6, 0.65 } },
	{ id = 2, slot = "Blade", shape = "Cylinder", material = "Iron", pos = { 0, 1.006, 0 }, rot = Z90, size = { 0.6, 0.4, 0.4 } },
	{ id = 3, slot = "Guard", shape = "Ball", material = "Iron", pos = { 0, 1.306, 0 }, rot = I, size = { 0.08, 0.08, 0.08 } },
})
local ring = { { id = 1, slot = "Blade", shape = "Block", material = "Iron", pos = { 0, 2, 0 }, rot = I, size = { 0.6, 0.02, 0.6 } } }
for _, t in ipairs({ -0.24, -0.12, 0, 0.12, 0.24 }) do
	for _, at in ipairs({ { 0.36, t }, { -0.36, t }, { t, 0.36 }, { t, -0.36 } }) do
		table.insert(ring, { id = #ring + 1, slot = "Guard", shape = "Ball", material = "Iron", pos = { at[1], 2, at[2] }, rot = I, size = { 0.1, 0.1, 0.1 } })
	end
end
add("a plate ringed by 20 Balls, alone", ring)
for a = 1, #process.args do
	local root = process.args[a]
	local Shapes = req(root .. "/src/shared/Physics/Shapes")
	local Sampling = req(root .. "/src/shared/Physics/Sampling")
	local worst, worstName, rows = 0, "", {}
	for _, d in ipairs(designs) do
		local P = {}
		for i, p in ipairs(d.parts) do
			P[i] = Shapes.prepare(p, i)
		end
		local most = 0
		local e = Sampling.exposure(P, function(n)
			most = math.max(most, n)
		end)
		table.insert(rows, { d.name, most, e.verdictWork, e.capped })
		if most > worst then
			worst, worstName = most, d.name
		end
	end
	table.sort(rows, function(x, y) return x[2] > y[2] end)
	print(fmt("%s: the largest single report %.3f units (%s)", string.match(root, "[^/]+$"), worst, worstName))
	for k = 1, 8 do
		print(fmt("   %10.3f  %-60s %12.3f units%s", rows[k][2], string.sub(rows[k][1], 1, 60), rows[k][3], if rows[k][4] then " CAPPED" else ""))
	end
	local fixturesMax = 0
	for _, r in ipairs(rows) do
		if not string.find(r[1], "V1's sword", 1, true) and not string.find(r[1], "alone", 1, true) then
			fixturesMax = math.max(fixturesMax, r[2])
		end
	end
	print(fmt("   over the fixtures, attack and worst designs: %.3f", fixturesMax))
end
