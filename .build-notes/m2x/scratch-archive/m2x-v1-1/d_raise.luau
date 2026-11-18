--!nocheck
-- a checkpoint that raises at the k-th call (every STEP-th k, all through Cover's reports), then a clean run: bit-identical
local process = require("@lune/process")
local L = require("./lib")
local T = require("./tsets")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local mk = require("./cagelib")
local fmt = string.format
local STEP = tonumber(process.args[1]) or 7
local function dump(v, out)
	local t = type(v)
	if t == "number" then
		table.insert(out, string.format("%.17g", v))
	elseif t == "table" then
		local keys = {}
		for k in pairs(v) do table.insert(keys, tostring(k)) end
		table.sort(keys)
		table.insert(out, "{")
		for _, k in ipairs(keys) do
			table.insert(out, k .. "=")
			local val = v[k]
			if val == nil then val = v[tonumber(k)] end
			dump(val, out)
		end
		table.insert(out, "}")
	else
		table.insert(out, tostring(v))
	end
end
local function digest(r) local o = {} dump(r, o) return table.concat(o, ",") end
local designs = {
	{ name = "P1", parts = L.fixture("P1") },
	{ name = "C09", parts = L.fixture("C09") },
	{ name = "worst valid 1", parts = L.copyParts(Worst.valid[1].parts) },
	{ name = "tooComplex 1", parts = L.copyParts(Worst.tooComplex[1].parts) },
	{ name = "caged ball sword", parts = (function()
		local c = mk.cage(L, 0.2, 0.002769, 0.051018)
		return c
	end)() },
	{ name = "ball cluster", parts = T.cluster(0.54, 0.05803, 0.25, 0.3) },
}
for _, d in ipairs(designs) do
	local parts = L.renumber(d.parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local calls = 0
	local base = L.Analyze.run(core, { measureInvalid = true, checkpoint = function() calls += 1 end })
	local want = digest(base)
	local raised, same = 0, 0
	for k = 1, calls, STEP do
		local n = 0
		local ok = pcall(L.Analyze.run, core, { measureInvalid = true, checkpoint = function()
			n += 1
			if n == k then error("cancel") end
		end })
		if not ok then raised += 1 end
		local again = L.Analyze.run(core, { measureInvalid = true, checkpoint = function() end })
		if digest(again) == want then same += 1 end
	end
	print(fmt("%-18s %5d checkpoints; raised at %d of them, the next run bit-identical %d times", d.name, calls, raised, same))
end
