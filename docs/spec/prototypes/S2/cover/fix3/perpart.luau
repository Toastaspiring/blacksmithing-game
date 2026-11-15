--!nocheck
-- m2x-fix-3: per part, the reading's units and share on the base and the build (whole reading, need = 2 %)
local Lab = require("./lab")
local process = require("@lune/process")
local fmt = string.format
local B, N = Lab.tree(Lab.SCR .. "/m2x-fix-3/var_ABA"), Lab.tree("now")
local id = process.args[1] or "F3"
local parts = if string.sub(id, 1, 1) == "F" then N.repoFixture(id) else (N.fixture(id))
for _, T in ipairs({ B, N }) do
	local P = T.prep(parts)
	local models = T.models(P)
	local total = 0
	local row = {}
	for i = 1, #P do
		if models[i] then
			local index, higher = T.hidersOf(P, i, models)
			local hm = {}
			for k, j in ipairs(index) do
				hm[k] = models[j]
			end
			local need = T.Geo.ENCLOSED_EXPOSED_MAX * models[i].total
			local shown, used = T.Cover.shown(models[i], hm, higher, need, math.huge)
			total += used
			table.insert(row, fmt("%d:%s %.1f", i, string.sub(parts[i].shape, 1, 2), used))
		end
	end
	print(fmt("%s total readings %.3f | %s", T == B and "ABA " or "now ", total, table.concat(row, "  ")))
end
