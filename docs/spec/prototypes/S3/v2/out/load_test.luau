local D = require("./dist_test")
local s = D.get("PrecisionTrace", "Hard", "Steel", "Average")
print(#D.cells, #s, s[1], D.passThreshold)
