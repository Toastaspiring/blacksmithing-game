--!nocheck
-- timing against the SPEC's references in the same rounds (so that load cancels in the ratio): the V1 cluster (verdict 26.3
-- ms), tclimb_2.json #5 (Analyze.run 41.5 ms), P1 (verdict 9.4–10.3, exposure 17.1–19.3), and the candidates given as JSON
-- files; median of 15, every design once a round. lune run t_compare -- <file.json,...>
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local SV = require("./vonly/src/shared/Physics/Sampling")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local designs = {}
for _, d in ipairs(Worst.valid) do
	if string.sub(d.name, 1, 2) == "V1" or d.name == "tclimb_2.json #5" then table.insert(designs, { d.name, L.copyParts(d.parts) }) end
end
local p1 = L.fixture("P1")
table.insert(designs, { "P1", p1 })
for _, f in ipairs(string.split(process.args[1] or "", ",")) do
	if f ~= "" then table.insert(designs, { f, serde.decode("json", fs.readFile(f)) }) end
end
local rows = {}
for k, d in ipairs(designs) do
	local parts = L.renumber(L.copyParts(d[2]))
	rows[k] = { name = d[1], P = L.prep(parts), core = { schema = 1, name = "x", type = "Sword", parts = parts }, v = {}, e = {}, a = {}, g = {} }
end
for round = 1, 15 do
	for _, r in ipairs(rows) do
		local t0 = os.clock()
		SV.exposure(r.P)
		local t1 = os.clock()
		local ex = L.Sampling.exposure(r.P)
		local t2 = os.clock()
		local last, worst = os.clock(), 0
		local t3 = os.clock()
		local an = L.Analyze.run(r.core, { checkpoint = function()
			local now = os.clock()
			if now - last > worst then worst = now - last end
			last = now
		end })
		local t4 = os.clock()
		table.insert(r.v, (t1 - t0) * 1000)
		table.insert(r.e, (t2 - t1) * 1000)
		table.insert(r.a, (t4 - t3) * 1000)
		table.insert(r.g, worst * 1000)
		r.units, r.capped, r.valid = ex.verdictWork, ex.capped, an.validation.ok
	end
end
local function med(t) table.sort(t) return t[8] end
for _, r in ipairs(rows) do
	print(fmt("%-48s units %10.1f%s %s  verdict %6.2f  exposure %6.2f  run %6.2f  gap %.3f ms", string.sub(tostring(r.name), 1, 48), r.units, r.capped and " (cap)" or "", r.valid and "valid" or "invalid", med(r.v), med(r.e), med(r.a), med(r.g)))
end
