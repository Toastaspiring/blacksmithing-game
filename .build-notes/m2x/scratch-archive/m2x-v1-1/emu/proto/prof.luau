local Analyze = require("./analyze")
local Fx = require("./fixtures")
local fmt = string.format
local list = { Fx.arming("Iron"), Fx.cleaver(), Fx.ornate(), Fx.gamey(true), Fx.golden()[5], Fx.perf()[1], Fx.perf()[4] }
for _, b in ipairs(list) do
	local best, R = math.huge, nil
	for _ = 1, 3 do
		local r = Analyze.run(b, { measureInvalid = true })
		if r.T.total < best then best, R = r.T.total, r end
	end
	local T = R.T
	print(fmt("%-40s total %.1f | validate %.1f surface %.1f mass %.1f edge %.1f factors %.1f | surf %d sub %d hS %.3f vol %d ovl %d cells %d", R.name, T.total*1000, (T.validate or 0)*1000, (T.surface or 0)*1000, (T.mass or 0)*1000, (T.edge or 0)*1000, (T.factors or 0)*1000, R.surfSamples or 0, R.subSampled or 0, R.hSurf or 0, R.volSamples or 0, R.refinedCells or 0, R.edge and R.edge.cells or 0))
end
