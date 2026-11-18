--!nocheck
-- m3-plan-r2: how many checkpoints M3 adds (Analyze.spec asserts F2 < 150 in all, and P1 > 100), through analyze_gap.luau
-- in the measure's rank order with the prototype's charges at CHECK_UNITS 500: the snapshot's Analyze.run's checkpoints,
-- and the emulator's after its mark (edge and factors, with the phase checkpoints after the edge and the end).
--   lune run <abs>/proto/checks.luau -- <id> [<id> ...]
local L = require("./lib")
local Gap = require("./analyze_gap")
local process = require("@lune/process")
local Analyze = require("../repo/src/shared/Physics/Analyze")
local fmt = string.format

for i = 1, #process.args do
	local id = process.args[i]
	local b = L.find(id)
	local n2 = 0
	Analyze.run({ schema = 1, name = id, type = "Sword", parts = b.parts }, { checkpoint = function()
		n2 += 1
	end })
	local n3, armed = 0, false
	Gap.run(L.inRankOrder(b), { build = true, measureInvalid = true, mark = function()
		armed = true
	end, checkpoint = function()
		if armed then
			n3 += 1
		end
	end })
	print(fmt("%-5s M2 checkpoints %d, M3 (emulated) %d, total %d", id, n2, n3, n2 + n3))
end
