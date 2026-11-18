--!nocheck
-- a checkpoint that raises at its k-th call, for every k of a run (spaced on long runs): the next run, uninterrupted, gives
-- the same Analysis to the bit
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local function dump(v, out)
	local t = typeof(v)
	if t == "table" then
		local keys = {}
		for k in pairs(v) do table.insert(keys, k) end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		table.insert(out, "{")
		for _, k in ipairs(keys) do
			table.insert(out, tostring(k) .. "=")
			dump(v[k], out)
			table.insert(out, ",")
		end
		table.insert(out, "}")
	elseif t == "number" then
		table.insert(out, fmt("%.17g", v))
	else
		table.insert(out, tostring(v))
	end
end
local function text(a)
	local out = {}
	dump(a, out)
	return table.concat(out)
end
local designs = { { "F5", L.repoFixture("F5") }, { "C09", (L.fixture("C09")) }, { "P1", (L.fixture("P1")) }, { "P4", (L.fixture("P4")) } }
table.insert(designs, { Worst.valid[1].name, L.copyParts(Worst.valid[1].parts) })
table.insert(designs, { Worst.tooComplex[1].name, L.copyParts(Worst.tooComplex[1].parts) })
for _, d in ipairs(designs) do
	local parts = L.renumber(L.copyParts(d[2]))
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local calls = 0
	local ref = text(L.Analyze.run(core, { checkpoint = function() calls += 1 end }))
	local ks = {}
	local step = math.max(1, math.floor(calls / 150))
	for k = 1, calls, step do table.insert(ks, k) end
	local bad, raised = 0, 0
	for _, k in ipairs(ks) do
		local c = 0
		local ok = pcall(L.Analyze.run, core, { checkpoint = function()
			c += 1
			if c == k then error("cancel") end
		end })
		if not ok then raised += 1 end
		local again = text(L.Analyze.run(core))
		if again ~= ref then bad += 1 end
	end
	print(fmt("%-50s %5d checkpoints; raised at %d of them; the next run differs %d times", string.sub(d[1], 1, 50), calls, raised, bad))
end
