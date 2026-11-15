--!nocheck
-- fix-2: Lune ms, median of RUNS rounds, every design once a round on each tree in turn: the verdict alone (SamplingV),
-- the whole exposure, Analyze.run. Designs: F5, C05, C09, X01, P1, P2, P4, fin's worst designs (valid, and past the cap:
-- Analyze.run, which answers TooComplex).   lune run timing -- <runs> <tree> [<tree> ...]   (folders of m2x-fix-2)
local process = require("@lune/process")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-2"
local fmt = string.format
local function req(p)
	return (require :: any)(p)
end
local RUNS = tonumber(process.args[1]) or 15
local trees = {}
for a = 2, #process.args do
	local root = W .. "/" .. process.args[a]
	table.insert(trees, { name = process.args[a], Shapes = req(root .. "/src/shared/Physics/Shapes"), Sampling = req(root .. "/src/shared/Physics/Sampling"),
		V = req(root .. "/src/shared/Physics/SamplingV"), Analyze = req(root .. "/src/shared/Physics/Analyze") })
end
local Fx = req(W .. "/fin/docs/spec/prototypes/S2/v2/fixtures")
local B = req(W .. "/fin/tests/fixtures/Blueprints")
local Worst = req(W .. "/fin/docs/spec/prototypes/S2/cover/worst_designs")
local function find(prefix)
	for _, list in ipairs({ Fx.calibration(), Fx.regression(), Fx.perf() }) do
		for _, b in ipairs(list) do
			local bb = b.fixture or b
			if string.sub(bb.name, 1, #prefix) == prefix then
				return bb.parts
			end
		end
	end
	error(prefix)
end
local designs = { { "F5", B.core("F5").parts }, { "C05", find("C05") }, { "C09", find("C09") }, { "X01", find("X01 ") }, { "P1", find("P1") },
	{ "P2", find("P2") }, { "P4", find("P4") } }
for _, d in ipairs(Worst.valid) do
	table.insert(designs, { "valid " .. string.sub(d.name, 1, 22), d.parts })
end
for _, d in ipairs(Worst.tooComplex) do
	table.insert(designs, { "past " .. string.sub(d.name, 1, 22), d.parts, true })
end
local data = {}
for k, d in ipairs(designs) do
	data[k] = {}
	for t, T in ipairs(trees) do
		local P = {}
		for i, p in ipairs(d[2]) do
			P[i] = T.Shapes.prepare(p, i)
		end
		local core = { schema = 1, name = "t", type = "Sword", parts = d[2] }
		local e = T.V.exposure(P)
		data[k][t] = { P = P, core = core, units = e.verdictWork, capped = e.capped, v = {}, e = {}, a = {} }
	end
end
for r = 1, RUNS do
	for k, d in ipairs(designs) do
		for t, T in ipairs(trees) do
			local x = data[k][t]
			local t0
			if not d[3] then
				t0 = os.clock()
				T.V.exposure(x.P)
				x.v[r] = (os.clock() - t0) * 1000
				t0 = os.clock()
				T.Sampling.exposure(x.P)
				x.e[r] = (os.clock() - t0) * 1000
			end
			t0 = os.clock()
			T.Analyze.run(x.core, { measureInvalid = true })
			x.a[r] = (os.clock() - t0) * 1000
		end
	end
end
local function med(t)
	if #t == 0 then
		return 0
	end
	local c = table.clone(t)
	table.sort(c)
	return c[(#c + 1) // 2]
end
for k, d in ipairs(designs) do
	local row = { fmt("%-28s", d[1]) }
	for t, T in ipairs(trees) do
		local x = data[k][t]
		table.insert(row, fmt("%s %10.1f u %s verdict %6.2f exposure %6.2f run %6.2f", T.name, x.units, x.capped and "CAP" or "ok ", med(x.v), med(x.e), med(x.a)))
	end
	print(table.concat(row, " | "))
end
