--!nocheck
-- Shape queries of the verdict alone on the cost designs: sd, aabb, chord. Run in an alt folder. args: json...
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local C = require("./count/Sampling")
local fmt = string.format
local COUNT = C.COUNT
local list = {}
local function add(name, parts)
	table.insert(list, { name = name, parts = V.renumber(V.copyParts(parts)) })
end
for _, n in ipairs({ "F5", "C02 Arming (Iron)", "C05", "C09", "C10", "P1", "P2", "P3", "P4", "P5" }) do
	add(string.sub(n, 1, 3), (V.fixture(n)))
end
for a = 1, #process.args do
	local data = serde.decode("json", fs.readFile(process.args[a]))
	local stem = string.match(process.args[a], "[^/\\]*$")
	for i, d in ipairs(data) do
		add(fmt("%s#%d", string.sub(stem, 1, 12), i), d.parts)
	end
end
print(fmt("%-22s %8s %8s %8s %8s %6s", "design", "sd", "aabb", "chord", "score", "cleaned"))
for _, it in ipairs(list) do
	local P = V.prep(it.parts)
	COUNT.sd, COUNT.aabb, COUNT.chord = 0, 0, 0
	C.FORCE.verdictOnly = true
	local ex = C.exposure(P)
	C.FORCE.verdictOnly = nil
	print(fmt("%-22s %8d %8d %8d %8.0f %6d", it.name, COUNT.sd, COUNT.aabb, COUNT.chord, COUNT.sd + 0.25 * COUNT.aabb + 2 * COUNT.chord, #ex.cleaned))
end
