--!nocheck
-- worst_designs.luau: the whole exposure and Analyze.run, median of RUNS rounds; the designs past the cap: Analyze.run
local process = require("@lune/process")
local L = require("./lab")
local fmt = string.format
local RUNS = tonumber(process.args[1]) or 15
local designs = {}
for k, d in ipairs(L.Worst.valid) do table.insert(designs, { "valid " .. k .. " " .. string.sub(d.name, 1, 16), d.parts }) end
for k, d in ipairs(L.Worst.tooComplex) do table.insert(designs, { "tooComplex " .. k, d.parts }) end
local te, ta = {}, {}
for k, d in ipairs(designs) do
	d.P = L.prepared(d[2])
	d.core = { schema = 1, name = "t", type = "Sword", parts = d[2] }
	te[k], ta[k] = {}, {}
end
for r = 1, RUNS do
	for k, d in ipairs(designs) do
		local t0 = os.clock()
		L.Sampling.exposure(d.P)
		te[k][r] = (os.clock() - t0) * 1000
		t0 = os.clock()
		local run = L.Analyze.run(d.core, { measureInvalid = true })
		ta[k][r] = (os.clock() - t0) * 1000
		d.code = if run.validation.ok then "valid" else run.validation.errors[#run.validation.errors].code
	end
end
local function med(t) local c = table.clone(t) table.sort(c) return c[(#c + 1) // 2] end
for k, d in ipairs(designs) do
	print(fmt("%-30s exposure %6.2f  run %6.2f  %s", d[1], med(te[k]), med(ta[k]), d.code))
end
