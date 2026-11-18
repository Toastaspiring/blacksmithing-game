--!nocheck
-- Cost of the recommended options in the prototype: the re-run measure alone (R0r) against the void-face rule (B05) and
-- the ladder Thinness probes (L), best of 5, total ms and the prototype's surface/factor phases. Indicative only: the
-- prototype measures in two passes where the build measures once.
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local CFG = Analyze.CFG
local fmt = string.format

local function best(b, set)
	CFG.RECOMPUTE, CFG.THIN_MERGE, CFG.VOID_GAP, CFG.THIN_LADDER = set.r, set.tm, set.vg, set.l
	local t, surf, fac = math.huge, 0, 0
	for _ = 1, 5 do
		local R = Analyze.run(b)
		if R.T.total < t then
			t, surf, fac = R.T.total, R.T.surface, R.T.factors
		end
	end
	CFG.RECOMPUTE, CFG.THIN_MERGE, CFG.VOID_GAP, CFG.THIN_LADDER = false, 0.01, 0, false
	return t * 1000, surf * 1000, fac * 1000
end
local list = {}
for _, b in ipairs(Fx.calibration()) do
	local id = string.match(b.name, "^(C%d+)")
	if id == "C05" or id == "C09" then
		table.insert(list, b)
	end
end
for _, b in ipairs(Fx.perf()) do
	table.insert(list, b)
end
for _, b in ipairs(list) do
	local a, as, af = best(b, { r = true, tm = 0.01, vg = 0, l = false })
	local c, cs, cf = best(b, { r = true, tm = 0.05, vg = 0.05, l = false })
	local d, ds, df = best(b, { r = true, tm = 0.01, vg = 0, l = true })
	print(fmt("%-40s R0r %.1f ms (surface %.1f, factors %.1f) | B05 %.1f (%.1f, %.1f) %+.0f %% | L %.1f (%.1f, %.1f) %+.0f %%", string.sub(b.name, 1, 40),
		a, as, af, c, cs, cf, (c / a - 1) * 100, d, ds, df, (d / a - 1) * 100))
end
