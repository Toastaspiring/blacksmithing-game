--!nocheck
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
for _, d in ipairs({ { "C09", L.fixture("C09") }, { "worst valid 1", L.copyParts(Worst.valid[1].parts) } }) do
	local where = {}
	L.Sampling.exposure(L.prep(L.renumber(d[2])), function(n)
		if n > 600 then
			local t = {}
			for level = 2, 4 do
				local s, nm, ln = debug.info(level, "snl")
				table.insert(t, (nm or "?") .. ":" .. tostring(ln))
			end
			local key = table.concat(t, "<")
			where[key] = math.max(where[key] or 0, n)
		end
	end)
	for k, v in pairs(where) do print(d[1], fmt("%.1f", v), k) end
end
