--!nocheck
-- V1 (m2x, round 3): the verdict's reports through `spend`: the largest single one, and on designs past the cap the report
-- that passes VERDICT_WORK_MAX, how far past it lands, and whether anything is reported after it. Also every design's
-- units against a run with the cap lifted (the units do not depend on the cap until it is passed).
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local Attacks = require("./repo/tests/Physics/CoverAttacks")
local SV = require("./vonly/src/shared/Physics/SamplingV") -- the verdict alone: every report is Cover's or the look's
local fmt = string.format
local CAP = L.Geo.VERDICT_WORK_MAX

local designs = {}
for _, list in ipairs({ L.Fx.calibration(), L.Fx.perf() }) do
	for _, b in ipairs(list) do
		if b.parts then
			table.insert(designs, { b.name, L.copyParts(b.parts) })
		end
	end
end
for _, d in ipairs(Attacks) do
	table.insert(designs, { "attack " .. d.name, L.copyParts(d.parts) })
end
for _, d in ipairs(Worst.valid) do
	table.insert(designs, { "valid " .. d.name, L.copyParts(d.parts) })
end
for _, d in ipairs(Worst.tooComplex) do
	table.insert(designs, { "past " .. d.name, L.copyParts(d.parts) })
end

local biggest, biggestWhere = 0, ""
local worstPast, after = 0, 0
for _, d in ipairs(designs) do
	L.renumber(d[2])
	local P = L.prep(d[2])
	local total, passed, passAt, later, maxOne = 0, false, 0, 0, 0
	local e = SV.exposure(P, function(u)
		if passed then
			later += 1
		end
		total += u
		maxOne = math.max(maxOne, u)
		if not passed and total > CAP then
			passed, passAt = true, total
		end
	end)
	if maxOne > biggest then
		biggest, biggestWhere = maxOne, d[1]
	end
	local u = L.units(P)
	local mark = ""
	if e.capped then
		worstPast = math.max(worstPast, passAt - CAP)
		after += later
		mark = fmt(" capped: passed at %.3f (%.3f past), %d reports after", passAt, passAt - CAP, later)
	elseif math.abs(e.verdictWork - u) > 1e-6 then
		mark = fmt(" UNITS %.3f vs uncapped %.3f", e.verdictWork, u)
	end
	print(fmt("%-60s units %11.3f largest report %8.3f%s", string.sub(d[1], 1, 60), e.verdictWork, maxOne, mark))
end
print(fmt("largest single report %.3f (%s); past the cap: at most %.3f units past it; reports after the passing one: %d", biggest,
	biggestWhere, worstPast, after))
