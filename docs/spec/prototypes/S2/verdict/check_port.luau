--!nocheck
-- m2r5-build: the port in the repo (copied to port/) against the study's rec, on every set: the same kept row, cleaned list, measure and budgets, and the same work
-- reported through spend. Adapted from m2r5-study/check_rec.luau. args: set shard nshards
local process = require("@lune/process")
local New = require("./port/src/shared/Physics/Sampling")
local Rec = require("../m2r5-study/rec/src/shared/Physics/Sampling")
local Shapes = require("../m2r5-study/tree/src/shared/Physics/Shapes")
local Sets = require("../m2r5-study/sets")
local fmt = string.format

local setName, shard, nshards = process.args[1], tonumber(process.args[2]), tonumber(process.args[3])
local list = Sets.get(setName)
local bad, n, parts, cleanedParts, unitsTotal = 0, 0, 0, 0, 0
local function report(...)
	bad += 1
	if bad <= 20 then
		print("DIFF", ...)
	end
end
for k, d in ipairs(list) do
	if (k - 1) % nshards == shard then
		local P = table.create(#d.parts)
		for i, p in ipairs(d.parts) do
			P[i] = Shapes.prepare(p, i)
		end
		local ua, ub = 0, 0
		local a = Rec.exposure(P, function(u)
			ua += u
		end)
		local b = New.exposure(P, function(u)
			ub += u
		end)
		n += 1
		unitsTotal += ub
		if ua ~= ub then
			report(d.name, "units", ua, ub)
		end
		for i = 1, #P do
			parts += 1
			if a.kept[i] ~= b.kept[i] then
				report(d.name, i, "kept", a.kept[i], b.kept[i])
			end
			if a.exposedKept[i] ~= b.exposedKept[i] then
				report(d.name, i, "exposedKept", a.exposedKept[i], b.exposedKept[i])
			end
			if not b.kept[i] and b.exposedKept[i] ~= 0 then
				report(d.name, i, "a cleaned part's exposedKept", b.exposedKept[i])
			end
			for j = 1, #P do
				if a.contact[i][j] ~= b.contact[i][j] then
					report(d.name, i, j, "contact", a.contact[i][j], b.contact[i][j])
				end
			end
		end
		cleanedParts += #b.cleaned
		if #a.cleaned ~= #b.cleaned then
			report(d.name, "cleaned count", #a.cleaned, #b.cleaned)
		else
			for c = 1, #a.cleaned do
				if a.cleaned[c].partId ~= b.cleaned[c].partId or a.cleaned[c].reason ~= b.cleaned[c].reason then
					report(d.name, "cleaned", c)
				end
			end
		end
		if a.hKept ~= b.hSurf then
			report(d.name, "hSurf", a.hKept, b.hSurf)
		end
		if a.surfSamples ~= b.surfSamples then
			report(d.name, "surfSamples", a.surfSamples, b.surfSamples)
		end
		if a.subSampled ~= b.subSampled then
			report(d.name, "subSampled", a.subSampled, b.subSampled)
		end
		if b.hKept ~= nil or b.exposedArea ~= nil or b.visibleArea ~= nil then
			report(d.name, "a removed field")
		end
	end
end
print(fmt("%s %d/%d: %d designs, %d parts, %d cleaned, %d differences, %d units", setName, shard, nshards, n, parts, cleanedParts, bad, unitsTotal))
