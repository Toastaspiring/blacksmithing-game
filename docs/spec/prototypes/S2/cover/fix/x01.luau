--!nocheck
local L = require("./lab")
local E = require("./emulab")
local fmt = string.format
for _, b in ipairs(L.Fx.regression()) do
	local keys = {}
	for k in pairs(b) do table.insert(keys, k) end
	print(b.name or (b.fixture and b.fixture.name), table.concat(keys, ","))
end
for _, b in ipairs(L.Fx.regression()) do
	local name = b.name or (b.fixture and b.fixture.name) or "?"
	if string.sub(name, 1, 3) == "X01" or string.sub(name, 1, 3) == "X02" then
		local parts = b.parts or b.fixture.parts
		local R = E.run(parts)
		local e = L.Sampling.exposure(L.prepared(parts))
		local cl = {}
		for _, c in ipairs(e.cleaned) do table.insert(cl, c.partId) end
		print(fmt("%-40s %s  cleaned {%s}", name, E.dline(R), table.concat(cl, " ")))
		for k, v in pairs(b) do
			if type(v) == "table" and v.parts and v ~= b.fixture then
				local Rb = E.run(v.parts)
				local d, t, s = E.diff(R, Rb)
				print(fmt("   %-10s %s  |dD| %.4f on %s", k, E.dline(Rb), d, s))
			end
		end
	end
end
