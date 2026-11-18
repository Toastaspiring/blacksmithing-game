--!nocheck
-- exactness on V1's round-2 tangles: lune run x_tangles -- <seed> <count>
local process = require("@lune/process")
local L = require("./lib")
local E = require("./exactlib")
local T = require("./tangles")
local TestRng = require("./repo/tests/lib/TestRng")
local fmt = string.format
local seed, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 100
local rng = TestRng.new(seed)
local t0 = os.clock()
local tot = { designs = 0, parts = 0, checked = 0, ties = 0, past = 0, bad = 0, nonfinite = 0 }
local worst = 0
for d = 1, count do
	local parts = T.tangle(rng)
	local P = L.prep(parts)
	local ok, r = pcall(E.check, P)
	if not ok then
		print("ERROR design " .. d .. ": " .. tostring(r))
	else
		tot.designs += 1
		tot.parts += #P
		tot.checked += r.checked
		tot.ties += r.ties
		tot.past += r.past
		tot.bad += #r.bad
		tot.nonfinite += r.nonfinite
		worst = math.max(worst, r.maxdiff)
		if #r.bad > 0 or r.nonfinite > 0 then
			print(fmt("design %d (seed %d): BAD %d nonfinite %d", d, seed, #r.bad, r.nonfinite))
			for _, b in ipairs(r.bad) do
				print(fmt("   part %d (%s) facet %d: cover %.17g outside [%.17g, %.17g] (miss %.3g of the part)", b.part, b.shape, b.facet, b.c, b.lo, b.hi, b.miss / b.total))
			end
			local f = io and io.open
			print("   parts: " .. require("@lune/serde").encode("json", parts))
		end
	end
end
print(fmt("seed %d: %d tangles, %d parts, checked %d, ties %d, past the cell limit %d, outside the bracket %d (worst %.3g), nonfinite %d (%.1f s)",
	seed, tot.designs, tot.parts, tot.checked, tot.ties, tot.past, tot.bad, worst, tot.nonfinite, os.clock() - t0))
