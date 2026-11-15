--!nocheck
local L = require("./lab")
local V = require("./SamplingV")
local fmt = string.format
local want = { "C05", "X01 ", "P2" }
local designs = {}
for _, s in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf() }) do
	for _, b in ipairs(s) do
		local name = b.name or (b.fixture and b.fixture.name)
		local parts = b.parts or (b.fixture and b.fixture.parts)
		for _, w in ipairs(want) do
			if string.sub(name, 1, #w) == w then table.insert(designs, { name, parts }) end
		end
	end
end
for _, d in ipairs(designs) do
	local P = L.prepared(d[2])
	local tv, te = {}, {}
	for r = 1, 15 do
		local t0 = os.clock()
		local e = V.exposure(P)
		tv[r] = (os.clock() - t0) * 1000
		d.u = e.verdictWork
		t0 = os.clock()
		L.Sampling.exposure(P)
		te[r] = (os.clock() - t0) * 1000
	end
	table.sort(tv) table.sort(te)
	print(fmt("%-40s %10.3f units  verdict %.2f  exposure %.2f", d[1], d.u, tv[8], te[8]))
end
