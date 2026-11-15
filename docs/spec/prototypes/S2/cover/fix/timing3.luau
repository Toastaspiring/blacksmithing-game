--!nocheck
-- the F, C and X fixtures (and P1–P5): the verdict alone and the whole exposure, median of 15 rounds
local L = require("./lab")
local V = require("./SamplingV")
local fmt = string.format
local designs = {}
for _, id in ipairs(L.Blueprints.order) do table.insert(designs, { id, L.Blueprints.core(id).parts }) end
for _, s in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf() }) do
	for _, b in ipairs(s) do
		if b.parts then table.insert(designs, { b.name, b.parts }) elseif b.fixture then table.insert(designs, { b.fixture.name, b.fixture.parts }) end
	end
end
local tv, te = {}, {}
for k, d in ipairs(designs) do d.P = L.prepared(d[2]); tv[k], te[k] = {}, {} end
for r = 1, 15 do
	for k, d in ipairs(designs) do
		local t0 = os.clock()
		V.exposure(d.P)
		tv[k][r] = (os.clock() - t0) * 1000
		t0 = os.clock()
		L.Sampling.exposure(d.P)
		te[k][r] = (os.clock() - t0) * 1000
	end
end
local mv, mvn, me, men = 0, "", 0, ""
for k, d in ipairs(designs) do
	table.sort(tv[k]) table.sort(te[k])
	local v, e = tv[k][8], te[k][8]
	local c = string.sub(d[1], 1, 1)
	if c ~= "P" then
		if v > mv then mv, mvn = v, d[1] end
		if e > me then me, men = e, d[1] end
	end
	if c == "P" then print(fmt("%-40s verdict %.2f exposure %.2f", d[1], v, e)) end
end
print(fmt("F, C and X: the verdict at most %.2f (%s), the whole exposure at most %.2f (%s)", mv, mvn, me, men))
