--!nocheck
-- m2r5: where a design's time goes under a variant: the verdict alone, the whole exposure, Analyze.run, M3's edge and factors. args: rounds variant json...
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Analyze = require("./tree/src/shared/Physics/Analyze")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Emu = require("./proto/analyze_build")
local Fx = require("./proto/fixtures")
local V = require("./variants")
local fmt = string.format
local ROUNDS = tonumber(process.args[1]) or 15
local NAMES = string.split(process.args[2] or "P", " ")
local function median(t) table.sort(t) return t[(#t + 1) // 2] end
local list = {}
for _, b in ipairs(Fx.golden()) do if string.sub(b.name, 1, 2) == "F5" then table.insert(list, { "F5", b.parts }) end end
for _, b in ipairs(Fx.calibration()) do
	local tag = string.sub(b.name, 1, 3)
	if tag == "C09" or tag == "C10" then table.insert(list, { tag, b.parts }) end
end
for _, b in ipairs(Fx.perf()) do table.insert(list, { string.sub(b.name, 1, 2), b.parts }) end
for a = 3, #process.args do
	local data = serde.decode("json", fs.readFile(process.args[a]))
	for i, d in ipairs(data) do
		if i <= 12 then table.insert(list, { d.from or fmt("%s#%d", string.match(process.args[a], "[^/]*$"), i), d.parts }) end
	end
end
for _, it in ipairs(list) do
	local P = {}
	for i, p in ipairs(it[2]) do P[i] = Shapes.prepare(p, i) end
	local core = { schema = 1, name = "x", type = "Sword", parts = it[2] }
	for _, v in ipairs(NAMES) do
		V.apply(Sampling, v)
		local a, b, c, e, f = {}, {}, {}, {}, {}
		for r = 1, ROUNDS do
			Sampling.CFG.verdictOnly = true
			collectgarbage("collect")
			local t0 = os.clock()
			local ex = Sampling.exposure(P)
			a[r] = (os.clock() - t0) * 1000
			Sampling.CFG.verdictOnly = false
			collectgarbage("collect")
			t0 = os.clock()
			Sampling.exposure(P)
			b[r] = (os.clock() - t0) * 1000
			collectgarbage("collect")
			t0 = os.clock()
			Analyze.run(core, { measureInvalid = true })
			c[r] = (os.clock() - t0) * 1000
			if r <= 5 then
				local R = Emu.run({ name = "x", parts = it[2] }, { measureInvalid = true, build = true })
				e[r], f[r] = 1000 * (R.T.edge or 0), 1000 * (R.T.factors or 0)
			end
		end
		local ee, ff = median(e), median(f)
		print(fmt("%-18s %-6s verdict %5.2f, exposure %5.2f, Analyze.run %5.2f | M3 edge %5.2f factors %5.2f | total %5.2f (Studio %5.1f)", string.sub(it[1], 1, 18), v, median(a), median(b), median(c), ee, ff, median(c) + ee + ff, (median(c) + ee + ff) * 2.6))
	end
end
