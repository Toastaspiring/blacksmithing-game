--!nocheck
-- V2 round 3: one Ball rivet at the 2.5 % band, its truth in the repo and in the original build (m2x-fix-1/base).
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local fmt = string.format
local PD = require(SCR .. "/m2x-v2-3/repo/tests/Physics/PlausibleDesigns")
local want = { ["ballRivet|C05|guardZ d0.10 z45 cap0.0250"] = 7, ["ballRivet|F1|hiltZ d0.10 unrot cap0.0250"] = 6, ["ballRivet|C02|guardZ d0.08 z45 cap0.0250"] = 7 }
for _, root in ipairs({ SCR .. "/m2x-v2-3/repo", SCR .. "/m2x-fix-1/base" }) do
	local Shapes = require(root .. "/src/shared/Physics/Shapes")
	local Oracle = require(root .. "/tests/Physics/VisibleOracle")
	for _, d in ipairs(PD.all()) do
		local i = want[d.name]
		if i then
			local P = {}
			for k, p in ipairs(d.parts) do
				P[k] = Shapes.prepare(p, k)
			end
			local _, _, hider = Oracle.flags(P)
			print(fmt("%-60s %-45s part %d: %.17g", string.sub(root, -20), d.name, i, Oracle.share(P, i, hider)))
		end
	end
end
