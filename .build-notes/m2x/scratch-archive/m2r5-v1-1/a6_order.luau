--!nocheck
-- Invisible construction choices: part order (ids) of kept parts, when the measure's sub-grid budget runs out in part order.
local V = require("./v1")
local fmt = string.format
local L = { "C09", "P1", "P2", "P3", "P4", "P5", "C05", "C02 Arming (Iron)", "C10", "C11", "C06" }
local seed = 12345
local function rnd(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n + 1
end
for _, name in ipairs(L) do
	local base = V.fixture(name)
	local Ra = V.emu(V.copyParts(base))
	local lo, hi = {}, {}
	for i, s in ipairs(Ra.steps) do lo[i], hi[i] = s.d, s.d end
	local tiers = {}
	local flips = 0
	local N = if name == "C09" then 300 else 60
	local keptChanges = 0
	local exb = V.Sampling.exposure(V.prep(base))
	for t = 1, N do
		local parts = V.copyParts(base)
		for i = #parts, 2, -1 do
			local j = rnd(i)
			parts[i], parts[j] = parts[j], parts[i]
		end
		local R = V.emu(parts)
		local flip = false
		for i, s in ipairs(R.steps) do
			lo[i], hi[i] = math.min(lo[i], s.d), math.max(hi[i], s.d)
			flip = flip or s.tier ~= Ra.steps[i].tier
		end
		if flip then flips += 1 end
		if #R.cleaned ~= #exb.cleaned then keptChanges += 1 end
	end
	local t = {}
	for i, s in ipairs(Ra.steps) do
		table.insert(t, fmt("%s %.4f [%.4f, %.4f]", string.sub(s.step, 1, 2), s.d, lo[i], hi[i]))
	end
	print(fmt("%-22s subSampled %4d of budget: %s | %d orders, tier flips %d, cleaned count changed %d", string.sub(name, 1, 22), exb.subSampled, table.concat(t, ", "), N, flips, keptChanges))
end
