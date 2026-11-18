--!nocheck
-- The 2.5 % band of the study's plausible set: how many ball rivets stand exactly on it.
local V = require("./v1")
local Sets = require("./b_sets")
local T = V.T
local fmt = string.format
local list = Sets.get("plausible")
local n, cleaned, sum = 0, 0, 0
local lo, hi = 1, 0
for _, d in ipairs(list) do
	if string.find(d.name, "ballRivet", 1, true) and string.find(d.name, "cap0.0250", 1, true) then
		n += 1
		local parts = V.renumber(d.parts)
		local P = V.prep(parts)
		local ex = V.Sampling.exposure(P)
		local i = #parts
		for k, p in ipairs(parts) do
			if p.label == "Rivet" then i = k end
		end
		if not ex.kept[i] then cleaned += 1 end
		if n <= 400 and n % 10 == 1 then
			local S = T.solids(parts)
			local hider = T.hidersOf(S)
			local s = T.share(S, i, hider, 0.0002)
			lo, hi = math.min(lo, s), math.max(hi, s)
		end
	end
end
print(fmt("rivets at cap 0.0250: %d designs, %d cleaned; sampled true share %.4f .. %.4f %%", n, cleaned, lo * 100, hi * 100))
