--!nocheck
local L = require("./lab")
local fmt = string.format
local function biggest(parts)
	local big, n, total = 0, 0, 0
	local e = L.Sampling.exposure(L.prepared(parts), function(u)
		big = math.max(big, u)
		n += 1
		total += u
	end)
	return big, e.verdictWork, e.capped, n
end
local designs = {
	{ "P1", L.H.p1().parts },
	{ "C09", L.H.ornate().parts },
	{ "F3", L.Blueprints.core("F3").parts },
	{ "F5", L.Blueprints.core("F5").parts },
	{ "atk3 " .. L.Attacks[3].name, L.Attacks[3].parts },
	{ "atk15 " .. L.Attacks[15].name, L.Attacks[15].parts },
}
for _, perf in ipairs(L.Fx.perf()) do table.insert(designs, { perf.name, perf.parts }) end
for k, d in ipairs(L.Worst.valid) do table.insert(designs, { "worst valid " .. k .. " " .. d.name, d.parts }) end
for k, d in ipairs(L.Worst.tooComplex) do table.insert(designs, { "tooComplex " .. k .. " " .. d.name, d.parts }) end
for _, d in ipairs(designs) do
	local big, units, capped, n = biggest(d[2])
	print(fmt("%-60s units %14.3f %s largest report %9.3f (%d reports)", string.sub(d[1], 1, 60), units, capped and "CAPPED" or "      ", big, n))
end
