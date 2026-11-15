--!nocheck
local Analyze = require("../snapcap/src/shared/Physics/Analyze")
local Fx = require("../snapcap/docs/spec/prototypes/S2/v2/fixtures")
local L = require("./lib")
for _, b in ipairs(Fx.perf()) do
	if string.sub(b.name, 1, 2) == "P1" then
		local r = Analyze.run({ schema = 1, name = b.name, type = "Sword", parts = b.parts }, { measureInvalid = true })
		print(L.num(r.budget.hSurf), L.num(r.budget.hVol), r.budget.volSamples, L.num(r.physics.mass), L.num(r.physics.volume), L.num(r.physics.com[2]))
		local ids = {}
		for _, c in ipairs(r.cleaned) do table.insert(ids, c.partId) end
		print(table.concat(ids, ","))
	end
end
