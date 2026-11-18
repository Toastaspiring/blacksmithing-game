--!nocheck
local Sets = require("./b_sets")
for _, f in ipairs(Sets.families()) do
	local t0 = os.clock()
	local l = Sets.get(f)
	print(f, #l, string.format("%.2f s", os.clock() - t0))
end
