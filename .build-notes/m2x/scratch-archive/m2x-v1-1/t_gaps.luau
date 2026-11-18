--!nocheck
-- checkpoint gaps of Analyze.run: per design, RUNS runs; each run's longest stretch between checkpoints (start and end
-- included); the median of those and the largest
local process = require("@lune/process")
local L = require("./lib")
local T = require("./tsets")
local fmt = string.format
local RUNS = tonumber(process.args[1]) or 15
local which = process.args[2] or "all"
local function med(t) table.sort(t) return t[(#t + 1) // 2] end
local over = 0
local worstMed, worstName = 0, ""
print(fmt("%-34s %9s %7s %8s %8s %s", "design", "units", "checks", "med.max", "max", "result"))
for _, d in ipairs(T.sets(which)) do
	local parts = L.renumber(d.parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local maxima = {}
	local checks = 0
	local res
	for k = 1, RUNS do
		local longest, n = 0, 0
		local last = os.clock()
		res = L.Analyze.run(core, { measureInvalid = true, checkpoint = function()
			local now = os.clock()
			local g = (now - last) * 1000
			if g > longest then longest = g end
			n += 1
			last = now
		end })
		local g = (os.clock() - last) * 1000
		if g > longest then longest = g end
		maxima[k] = longest
		checks = n
	end
	local m = med(table.clone(maxima))
	local mx = 0
	for _, v in ipairs(maxima) do mx = math.max(mx, v) end
	if m > 0.35 then over += 1 end
	if m > worstMed then worstMed, worstName = m, d.name end
	local e = L.Sampling.exposure(L.prep(parts))
	print(fmt("%-34s %9.0f %7d %8.3f %8.3f %s", string.sub(d.name, 1, 34), e.verdictWork, checks, m, mx, if res.validation.ok then "valid" else L.codes(res)))
end
print(fmt("designs whose median longest gap passes 0.35 ms: %d; the worst median %.3f ms (%s)", over, worstMed, worstName))
