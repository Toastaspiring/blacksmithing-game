local D = require("../../../../final/S3-score-distributions")
local n, cells = 0, 0
for _, c in D.cells do
	cells += 1
	n += #c.scores
	assert(#c.scores >= 2000)
	local pass = 0
	for _, v in c.scores do if v >= D.passThreshold then pass += 1 end end
	assert(math.abs(pass / #c.scores - c.passRate) < 1e-9, c.family .. c.tier .. c.material .. c.profile)
end
print("cells", cells, "scores", n, "pass", D.passThreshold, "AvgPTHardSteel", #D.get("PrecisionTrace", "Hard", "Steel", "Average"))
