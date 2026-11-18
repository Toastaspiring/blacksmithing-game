--!nocheck
-- M3 (b) by the judge on a design set: the kept rows of today's reading, A canon and the conservative option against the
-- truth's (VisibleOracle share ≥ 2 %), and wherever a row differs, |dD| and tier flips through the emulator.
-- args: set [every] [offset]
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./jlib")
local S = require("./jsets")
local M3 = require("./m3j")
local fmt = string.format
local set = process.args[1] or "attacksA"
local every = tonumber(process.args[2] or "2") or 2
local offset = tonumber(process.args[3] or "0") or 0
local designs
if set == "attacksA" then designs = S.attackCorpusA()
elseif set == "fixtures" then designs = S.fixtures()
elseif set == "climbed" then designs = S.climbed()
else designs = S.json(set, "") end

local readers = {
	{ "today", function(P, flags) return L.Sampling.exposure(P).kept end },
	{ "Acanon", function(P, flags)
		local r = L.readA(P, { canon = true }, flags)
		local row = {}
		for i = 1, #P do row[i] = r[i] ~= nil and r[i].shown >= 0.02 * r[i].area end
		return row
	end },
	{ "cons", function(P, flags)
		local r = L.readC(P, { canon = true }, flags)
		local row = {}
		for i = 1, #P do row[i] = r[i] ~= nil and r[i].shown >= 0.02 * r[i].area end
		return row
	end },
}
local st = {}
for _, r in ipairs(readers) do st[r[1]] = { differ = 0, flips = 0, worst = 0, worstName = "", fe = 0, fk = 0 } end
local nd = 0
local t0 = os.clock()
for k, d in ipairs(designs) do
	if (k - 1 - offset) % every == 0 then
		nd += 1
		local parts = d.parts
		local P = L.prep(parts)
		local flags = { L.flags(P) }
		local truth = L.truthAll(P)
		local trow = {}
		for i = 1, #P do trow[i] = truth[i] ~= false and truth[i] >= 0.02 end
		for _, r in ipairs(readers) do
			local row = r[2](P, flags)
			local same = true
			for i = 1, #P do
				if row[i] ~= trow[i] then
					same = false
					if row[i] then st[r[1]].fk += 1 else st[r[1]].fe += 1 end
				end
			end
			if not same then
				local s = st[r[1]]
				s.differ += 1
				local dd, tier = M3.compare(parts, row, trow)
				if dd then
					if tier then s.flips += 1 end
					if dd > s.worst then s.worst, s.worstName = dd, d.name end
				end
			end
		end
	end
end
print(fmt("M3 %s every %d offset %d: %d designs, %.0f s", set, every, offset, nd, os.clock() - t0))
for _, r in ipairs(readers) do
	local s = st[r[1]]
	print(fmt("  %-7s rows differ from the truth's in %d designs (parts cleaned that the truth keeps %d, kept that it cleans %d); tier flips %d; worst |dD| %.4f (%s)",
		r[1], s.differ, s.fe, s.fk, s.flips, s.worst, s.worstName))
end
