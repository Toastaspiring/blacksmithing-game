--!nocheck
-- Lune ms, median of RUNS rounds (every design once a round): the verdict alone (SamplingV), the whole exposure, Analyze.run
local process = require("@lune/process")
local L = require("./lab")
local V = require("./SamplingV")
local fmt = string.format
local RUNS = tonumber(process.args[1]) or 15
local designs = { { "F5", L.Blueprints.core("F5").parts }, { "C09", L.H.ornate().parts }, { "P1", L.H.p1().parts } }
for _, b in ipairs(L.Fx.perf()) do if string.sub(b.name, 1, 2) == "P4" then table.insert(designs, { "P4", b.parts }) end end
for k = 1, 3 do table.insert(designs, { "worst valid " .. k .. " " .. string.sub(L.Worst.valid[k].name, 1, 14), L.Worst.valid[k].parts }) end
for k = 1, 4 do table.insert(designs, { "tooComplex " .. k, L.Worst.tooComplex[k].parts }) end
local tv, te, ta = {}, {}, {}
for k, d in ipairs(designs) do
	d.P = L.prepared(d[2])
	d.core = { schema = 1, name = "t", type = "Sword", parts = d[2] }
	tv[k], te[k], ta[k] = {}, {}, {}
	V.exposure(d.P)
end
for r = 1, RUNS do
	for k, d in ipairs(designs) do
		local t0 = os.clock()
		local e = V.exposure(d.P)
		tv[k][r] = (os.clock() - t0) * 1000
		d.units = e.verdictWork
		t0 = os.clock()
		L.Sampling.exposure(d.P)
		te[k][r] = (os.clock() - t0) * 1000
		t0 = os.clock()
		L.Analyze.run(d.core, { measureInvalid = true })
		ta[k][r] = (os.clock() - t0) * 1000
	end
end
local function med(t) local c = table.clone(t) table.sort(c) return c[(#c + 1) // 2], c[1] end
for k, d in ipairs(designs) do
	local v, vb = med(tv[k])
	local e = med(te[k])
	local a = med(ta[k])
	print(fmt("%-34s %10.1f units  verdict %6.2f (best %6.2f, %4.1f ns a unit)  exposure %6.2f  run %6.2f", d[1], d.units, v, vb, 1e6 * v / d.units, e, a))
end
