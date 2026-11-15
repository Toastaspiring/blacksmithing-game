--!nocheck
-- The measure stays byte for byte: on every design whose verdicts (the kept row) agree, the tree before (../old) and the build
-- (../snapcap) return the same kept, exposedKept, contact, surfSamples, subSampled and hSurf, to the bit. Two builds are
-- compared: the build as it is, and the build with the tree before's rank key (SamplingOldRank: |cz| not yet before cz), so
-- that a difference can only come from the verdict or from the rank.
-- args: set [every]
local process = require("@lune/process")
local L = require("./lib")
local New = require("../snapcap/src/shared/Physics/Sampling")
local NewOldRank = require("../snapcap/src/shared/Physics/SamplingOldRank")
local NewShapes = require("../snapcap/src/shared/Physics/Shapes")
local fmt = string.format

local which = process.args[1] or "fixtures"
local EVERY = tonumber(process.args[2] or "1") or 1
local list
if which == "fixtures" then list = L.fixtures()
elseif which == "plausible" then list = L.plausible()
elseif which == "attacks" then list = L.attackCorpusA()
elseif which == "bfam" then list = L.bFamilies(EVERY) EVERY = 1
elseif which == "hostile" then
	list = {}
	for _, s in ipairs({ L.worstP(), L.climbed(), L.attacksJson() }) do
		for _, d in ipairs(s) do table.insert(list, d) end
	end
end

local function sameMeasure(a, b, N)
	if a.hSurf ~= b.hSurf or a.surfSamples ~= b.surfSamples or a.subSampled ~= b.subSampled then return false end
	for i = 1, N do
		if a.kept[i] ~= b.kept[i] or a.exposedKept[i] ~= b.exposedKept[i] then return false end
		for j = 1, N do
			if a.contact[i][j] ~= b.contact[i][j] then return false end
		end
	end
	return true
end
local function sameRow(a, b, N)
	for i = 1, N do
		if a.kept[i] ~= b.kept[i] then return false end
	end
	return true
end
local function sameOrder(P)
	local _, a = L.OldSampling.ranked(P)
	local _, b = New.ranked(P)
	for r = 1, #a do
		if a[r].index ~= b[r].index then return false end
	end
	return true
end

local st = { designs = 0, capped = 0, verdictDiff = 0, rankDiff = 0, sameRowOld = 0, eqOldRank = 0, neqOldRank = 0, sameRowNew = 0, eqNew = 0,
	neqNewRankSame = 0, neqNewRankDiff = 0 }
local examples = {}
for k, d in ipairs(list) do
	if (k - 1) % EVERY == 0 then
		st.designs += 1
		local Po = L.prep(d.parts, L.OldShapes)
		local Pn = L.prep(d.parts, NewShapes)
		local N = #Pn
		local old = L.OldSampling.exposure(Po)
		local new = New.exposure(Pn)
		local newOR = NewOldRank.exposure(Pn)
		if new.capped then
			st.capped += 1
		else
			local rankSame = sameOrder(Pn)
			if not rankSame then st.rankDiff += 1 end
			if sameRow(old, newOR, N) then
				st.sameRowOld += 1
				if sameMeasure(old, newOR, N) then
					st.eqOldRank += 1
				else
					st.neqOldRank += 1
					table.insert(examples, "old rank: " .. d.name)
				end
			end
			if sameRow(old, new, N) then
				st.sameRowNew += 1
				if sameMeasure(old, new, N) then
					st.eqNew += 1
				elseif rankSame then
					st.neqNewRankSame += 1
					table.insert(examples, "rank same: " .. d.name)
				else
					st.neqNewRankDiff += 1
				end
			else
				st.verdictDiff += 1
			end
		end
	end
end
print(fmt("%s every %d: %d designs (%d capped). Kept rows: old = new on %d, differ on %d; the rank's order differs on %d.", which, EVERY, st.designs, st.capped,
	st.sameRowNew, st.verdictDiff, st.rankDiff))
print(fmt("  build with the old rank key: the same kept row on %d, the same measure to the bit on %d, different on %d", st.sameRowOld, st.eqOldRank, st.neqOldRank))
print(fmt("  build as it is: the same measure on %d of %d; different on %d where the rank's order is the same, %d where it changed", st.eqNew, st.sameRowNew,
	st.neqNewRankSame, st.neqNewRankDiff))
for i = 1, math.min(10, #examples) do print("   " .. examples[i]) end
