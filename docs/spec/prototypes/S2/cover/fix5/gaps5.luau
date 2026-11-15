--!nocheck
-- m2x-fix-5: checkpoint gaps (V1's t_time.luau's measure): per design the median of RUNS runs of the run's longest
-- stretch, from the start, between checkpoints, to the end, Analyze.run on a tree; every design once a round. With
-- `collect`, a full collection at every checkpoint, outside the stretches (the clock restarts after it), so that no
-- collection runs inside one. Sets: fixtures (the F, C and X fixtures: repo F1–F5, the prototype's calibration and
-- regression sets), perf (P1–P5), worst (worst_designs.luau: valid, then past the cap).
--   lune run gaps5 -- <tree root> <runs> <set,set,...> [collect]
local process = require("@lune/process")
local fmt = string.format
local root = process.args[1]
local RUNS = tonumber(process.args[2]) or 15
local COLLECT = process.args[4] == "collect"
local function req(p)
	return (require :: any)(root .. "/" .. p)
end
local Analyze = req("src/shared/Physics/Analyze")
local Fx = req("docs/spec/prototypes/S2/v2/fixtures")
local B = req("tests/fixtures/Blueprints")
local Worst = req("docs/spec/prototypes/S2/cover/worst_designs")
local designs = {}
for set in string.gmatch(process.args[3] or "fixtures,perf,worst", "[^,]+") do
	if set == "fixtures" then
		for _, id in ipairs(B.order) do
			table.insert(designs, { "F " .. id, B.core(id).parts })
		end
		for _, b in ipairs(Fx.calibration()) do
			if b.parts then
				table.insert(designs, { "C " .. string.sub(b.name, 1, 30), b.parts })
			end
		end
		for _, x in ipairs(Fx.regression()) do
			if x.fixture and x.fixture.parts then
				table.insert(designs, { "X " .. string.sub(x.fixture.name, 1, 30), x.fixture.parts })
			end
		end
	elseif set == "perf" then
		for _, b in ipairs(Fx.perf()) do
			if b.parts then
				table.insert(designs, { "P " .. string.sub(b.name, 1, 30), b.parts })
			end
		end
	elseif set == "worst" then
		for _, d in ipairs(Worst.valid) do
			table.insert(designs, { "valid " .. string.sub(d.name, 1, 26), d.parts })
		end
		for _, d in ipairs(Worst.tooComplex) do
			table.insert(designs, { "past " .. string.sub(d.name, 1, 27), d.parts })
		end
	end
end
local rows = {}
for k, d in ipairs(designs) do
	rows[k] = { name = d[1], core = { schema = 1, name = "g", type = "Sword", parts = d[2] }, g = {} }
end
for _ = 1, RUNS do
	for _, r in ipairs(rows) do
		local worst = 0
		local last = os.clock()
		Analyze.run(r.core, { measureInvalid = true, checkpoint = function()
			local now = os.clock()
			if now - last > worst then
				worst = now - last
			end
			if COLLECT then
				collectgarbage("collect")
			end
			last = os.clock()
		end })
		local now = os.clock()
		if now - last > worst then
			worst = now - last
		end
		table.insert(r.g, worst * 1000)
	end
end
local function median(t)
	table.sort(t)
	return t[(#t + 1) // 2]
end
local over = {}
for _, r in ipairs(rows) do
	local m = median(r.g)
	print(fmt("%-38s longest stretch, median of %d: %.3f ms (runs %.3f–%.3f)", r.name, RUNS, m, r.g[1], r.g[#r.g]))
	if m > 0.35 then
		table.insert(over, r.name)
	end
end
print(fmt("%s, %s: %d designs, %d past 0.35 ms: %s", root, if COLLECT then "a collection at every checkpoint" else "plain", #rows, #over,
	table.concat(over, "; ")))
