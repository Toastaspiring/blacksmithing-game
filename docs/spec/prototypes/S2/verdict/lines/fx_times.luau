--!nocheck
-- Every F, C and X fixture's total, M2 + M3 emulated: 5 rounds, median. Which is the slowest real design?
local V = require("./v1")
local Fx = V.Fx
local fmt = string.format
local list = {}
for _, group in ipairs({ Fx.calibration(), Fx.golden() }) do
	for _, b in ipairs(group) do table.insert(list, b) end
end
for _, r in ipairs(Fx.regression()) do
	if r.fixture and r.fixture.parts then table.insert(list, r.fixture) end
end
local rows = {}
for _, b in ipairs(list) do
	local parts = V.renumber(V.copyParts(b.parts))
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local T = {}
	for r = 1, 7 do
		collectgarbage("collect")
		local t0 = os.clock()
		V.Analyze.run(core, { measureInvalid = true })
		local m2 = (os.clock() - t0) * 1000
		local R = V.Emu.run({ name = "x", parts = parts }, { measureInvalid = true, build = true })
		table.insert(T, m2 + 1000 * ((R.T.edge or 0) + (R.T.factors or 0)))
	end
	table.sort(T)
	table.insert(rows, { b.name, T[4] })
end
table.sort(rows, function(a, c) return a[2] > c[2] end)
for k = 1, 8 do
	print(fmt("%-40s %.2f ms, %.1f Studio", string.sub(rows[k][1], 1, 40), rows[k][2], rows[k][2] * 2.6))
end
