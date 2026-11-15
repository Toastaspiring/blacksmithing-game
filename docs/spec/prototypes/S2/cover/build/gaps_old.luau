--!nocheck
-- Checkpoint gaps of Analyze.run (the build's, with its cap: ../snapcap) per design: the longest and the median run between
-- two checkpoints, in Lune ms, the largest of RUNS runs for the longest and the median of medians; the verdict's units, and
-- whether the cap stopped it. A canonical core per design (Canonical.draft).
-- args: runs set|file.json ...
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local Analyze = require("../old/src/shared/Physics/Analyze")
local SamplingC = { exposure = function() return { verdictWork = 0 } end }
local fmt = string.format
local RUNS = tonumber(process.args[1]) or 5

local function designs(arg)
	if arg == "real" then return L.realFixtures() end
	if arg == "judge" then return L.judgeWorst() end
	local list = serde.decode("json", fs.readFile(arg))
	local out = {}
	for n, d in ipairs(list) do table.insert(out, { name = string.match(arg, "[^/\\]+$") .. " #" .. n, parts = L.clean(d.parts) }) end
	return out
end

print(fmt("%-46s %9s %6s %8s %8s %8s %8s %s", "design", "units", "checks", "longest", "med.max", "median", "total", "result"))
local worst = 0
for a = 2, #process.args do
	for _, d in ipairs(designs(process.args[a])) do
		local res = L.Canonical.draft({ schema = 1, name = "x", type = "Sword", parts = d.parts })
		if res.ok then
			local core = res.value
			local longest, medians, totals, count = 0, {}, {}, 0
			local maxima = {}
			local whereLong, prevWhere = "", "start"
			local result
			for r = 1, RUNS do
				local gaps = {}
				local last = os.clock()
				local t0 = last
				result = Analyze.run(core, { measureInvalid = true, checkpoint = function()
					local now = os.clock()
					local g = (now - last) * 1000
					table.insert(gaps, g)
					local names = {}
					for level = 2, 5 do
						local nm = debug.info(level, "n")
						if nm and nm ~= "" then table.insert(names, nm) end
					end
					local here = table.concat(names, "<")
					if g > longest then longest, whereLong = g, prevWhere .. " -> " .. here end
					prevWhere = here
					last = now
				end })
				table.insert(gaps, (os.clock() - last) * 1000)
				totals[r] = (os.clock() - t0) * 1000
				local m = 0
				for _, g in ipairs(gaps) do m = math.max(m, g) end
				maxima[r] = m
				medians[r] = L.median(gaps)
				count = #gaps
			end
			local e = SamplingC.exposure(L.prep(core.parts), nil)
			local codes = {}
			for _, er in ipairs(result.validation.errors) do table.insert(codes, er.code) end
			worst = math.max(worst, longest)
			print(fmt("%-46s %9.0f %6d %8.3f %8.3f %8.3f %8.2f %s", string.sub(d.name, 1, 46), e.verdictWork, count, longest, L.median(maxima), L.median(medians), L.median(totals),
				if result.validation.ok then "valid" else table.concat(codes, ",")) .. "  [" .. whereLong .. "]")
		end
	end
end
print(fmt("longest gap over all: %.3f ms", worst))
