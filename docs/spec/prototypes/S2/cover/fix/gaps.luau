--!nocheck
-- V1's t_gaps.luau on the build: per design, RUNS runs of Analyze.run; each run's longest stretch between checkpoints
-- (start and end included); the median of those and the largest
local process = require("@lune/process")
local L = require("./lab")
local fmt = string.format
local RUNS = tonumber(process.args[1]) or 15
local designs = {}
for _, id in ipairs(L.Blueprints.order) do table.insert(designs, { id, L.Blueprints.core(id).parts }) end
table.insert(designs, { "C09", L.H.ornate().parts })
for _, s in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf() }) do
	for _, b in ipairs(s) do
		if b.parts then table.insert(designs, { b.name, b.parts }) elseif b.fixture then table.insert(designs, { b.fixture.name, b.fixture.parts }) end
	end
end
local nReal = #designs
for k, d in ipairs(L.Worst.valid) do table.insert(designs, { "worst valid " .. k, d.parts }) end
for k, d in ipairs(L.Worst.tooComplex) do if k <= 6 then table.insert(designs, { "tooComplex " .. k, d.parts }) end end
local function med(t) table.sort(t) return t[(#t + 1) // 2] end
local over, worst, worstName, worstReal, worstRealName, worstMax = 0, 0, "", 0, "", 0
for k, d in ipairs(designs) do
	local core = { schema = 1, name = "x", type = "Sword", parts = d[2] }
	local maxima = {}
	for r = 1, RUNS do
		local longest = 0
		local last = os.clock()
		L.Analyze.run(core, { measureInvalid = true, checkpoint = function()
			local now = os.clock()
			longest = math.max(longest, (now - last) * 1000)
			last = now
		end })
		longest = math.max(longest, (os.clock() - last) * 1000)
		maxima[r] = longest
	end
	local mx = math.max(table.unpack(maxima))
	local m = med(maxima)
	worstMax = math.max(worstMax, mx)
	if m > 0.35 then over += 1 end
	if m > worst then worst, worstName = m, d[1] end
	if k <= nReal and m > worstReal then worstReal, worstRealName = m, d[1] end
	print(fmt("%-40s med %.3f max %.3f", string.sub(d[1], 1, 40), m, mx))
end
print(fmt("%d designs; median longest stretch past 0.35 ms on %d; the worst median %.3f ms (%s); over the fixtures %.3f (%s); the largest single run %.3f",
	#designs, over, worst, worstName, worstReal, worstRealName, worstMax))
