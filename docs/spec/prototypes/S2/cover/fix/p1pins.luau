--!nocheck
-- P1 through Analyze.run: the fields Reference.spec exempts from the prototype, to 17 digits
local L = require("./lab")
for _, b in ipairs(L.Fx.perf()) do
	if string.sub(b.name, 1, 2) == "P1" then
		local run = L.Analyze.run({ schema = 1, name = b.name, type = "Sword", parts = b.parts }, { measureInvalid = true })
		local p = run.physics
		for _, f in ipairs({ "mass", "volume", "balance", "balanceFromHand", "comOffAxis" }) do print(f, string.format("%.17g", p[f])) end
		print("com", string.format("%.17g %.17g %.17g", p.com[1], p.com[2], p.com[3]))
		print("hSurf", string.format("%.17g", run.budget.hSurf), "hVol", string.format("%.17g", run.budget.hVol), "volSamples", run.budget.volSamples)
		local ids = {}
		for _, c in ipairs(run.cleaned) do table.insert(ids, c.partId) end
		print("cleaned", table.concat(ids, " "))
	end
end
