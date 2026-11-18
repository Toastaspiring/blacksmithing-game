-- Evidence for the two deviations: difficulty frame (Fixed vs KeptGrip) and thin-share reference (Striking vs Set)
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local CFG = Analyze.CFG
local fmt = string.format
local function line(R)
	local t = {}
	for _, s in ipairs(R.steps) do table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1))) end
	return table.concat(t, " | ") .. fmt(" | Th(All) %.3f edge %.3f chains %d", R.sets.All.raw.Thinness, R.edge.length, #R.edge.chains)
end
local adv = Fx.adversarial()
for _, mode in ipairs({ "Fixed", "KeptGrip" }) do
	CFG.DIFF_FRAME = mode
	for _, a in ipairs(adv) do
		local B, X = Analyze.run(a.base), Analyze.run(a.fixture)
		local w = 0
		for i, s in ipairs(X.steps) do
			if a.steps == "all" or a.steps == s.step then w = math.max(w, math.abs(s.d - B.steps[i].d)) end
		end
		print(fmt("frame %-8s %-40s max|dD| %.4f (bound %.2f) | %s", mode, a.fixture.name, w, a.bound, line(X)))
	end
	local C15 = Fx.calibration()[15]
	print(fmt("frame %-8s %-40s %s", mode, C15.name, line(Analyze.run(C15))))
end
CFG.DIFF_FRAME = "Fixed"
local val = Fx.validation()
local list = { val[9], Fx.golden()[3], Fx.golden()[5], Fx.calibration()[2], Fx.calibration()[4], Fx.calibration()[10] }
for _, mode in ipairs({ "Striking", "Set" }) do
	CFG.THIN_REF = mode
	for _, b in ipairs(list) do
		print(fmt("thinRef %-8s %-40s %s", mode, b.name, line(Analyze.run(b))))
	end
end
CFG.THIN_REF = "Striking"
