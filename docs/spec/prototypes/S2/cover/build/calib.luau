--!nocheck
-- Units against time for the new verdict: per design, Cover's units (the build's weights) and its counts by kind (tests,
-- boxes, polygons, facets; from copies of Cover with one weight at a time), the verdict's Lune ms (SamplingV, median of
-- RUNS, interleaved with the old reading's verdict) and the whole exposure's.
-- args: set [runs] [every] [outfile]
local process = require("@lune/process")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local L = require("./lib")
local fmt = string.format

local which = process.args[1] or "fixtures"
local RUNS = tonumber(process.args[2] or "9") or 9
local EVERY = tonumber(process.args[3] or "1") or 1
local outFile = process.args[4]
local QUICK = process.args[5] == "verdict" -- the new verdict's time alone
local MINU = tonumber(process.args[6] or "0") or 0 -- designs under this many units are skipped

local designs = {}
local function add(list)
	for k, d in ipairs(list) do
		if (k - 1) % EVERY == 0 then table.insert(designs, d) end
	end
end
if which == "fixtures" then add(L.fixtures())
elseif which == "real" then add(L.realFixtures())
elseif which == "plausible" then add(L.plausible())
elseif which == "worstP" then add(L.worstP())
elseif which == "climbed" then add(L.climbed())
elseif which == "attacks" then add(L.attackCorpusA())
elseif which == "climbA" then add(L.climbA())
elseif which == "climbB" then add(L.climbB())
elseif which == "judge" then add(L.judgeWorst())
elseif which == "jtime" then add(L.judgeTime())
elseif which == "bfam" then add(L.bFamilies(1))
elseif which == "hostile" then
	add(L.worstP()) add(L.climbed()) add(L.judgeWorst()) add(L.judgeTime()) add(L.climbA()) add(L.climbB()) add(L.attacksJson())
elseif string.sub(which, 1, 5) == "file:" then
	local path = string.sub(which, 6)
	if string.sub(path, -6) == ".jsonl" then add(L.jsonl(path, "")) else add(L.json(path, "")) end
end

-- Cover with one kind weighted 1 and the others 0 (the counts by kind), the facets' vertices counted as tests
local SRC = fs.readFile(L.SCR .. "m2x-build/snap/src/shared/Physics/Cover.luau")
local function variant(t, b, p, f)
	local s = SRC
	s = string.gsub(s, "local UNITS_PER_TEST = [%d%.]+", "local UNITS_PER_TEST = " .. t)
	s = string.gsub(s, "local UNITS_PER_BOX = [%d%.]+", "local UNITS_PER_BOX = " .. b)
	s = string.gsub(s, "local UNITS_PER_POLYGON = [%d%.]+", "local UNITS_PER_POLYGON = " .. p)
	s = string.gsub(s, "local UNITS_PER_FACET = [%d%.]+", "local UNITS_PER_FACET = " .. f)
	local mods = { ["../Definitions/Balance"] = L.Balance, ["./Shapes"] = L.Shapes }
	return luau.load(s, { debugName = "CoverK", environment = { require = function(n) return mods[n] end, math = math, table = table, string = string } })()
end
local K = { test = variant(1, 0, 0, 0), box = variant(0, 1, 0, 0), poly = variant(0, 0, 1, 0), facet = variant(0, 0, 0, 1) }

-- the verdict's units by a Cover: models, looks, readings (Sampling's loop, no cap)
local function units(C, P)
	local N = #P
	local rank, byRank = L.Sampling.ranked(P)
	local Geo = L.Balance.Geometry
	local isCopy = table.create(N, false)
	for r = 2, N do isCopy[byRank[r].index] = L.Shapes.sameSolid(byRank[r], byRank[r - 1]) end
	local hider, models = {}, {}
	local u = 0
	for i = 1, N do
		hider[i] = not isCopy[i] and P[i].volume >= Geo.MIN_PART_VOLUME
		if hider[i] then
			models[i] = C.model(P[i])
			u += models[i].work
		end
	end
	local reach = Geo.HIDE_OFFSET + 2 * Geo.EPS_GEOM
	for i = 1, N do
		if hider[i] then
			local cand, higher = {}, {}
			for r = 1, N do
				local q = byRank[r]
				if q.index ~= i and hider[q.index] and L.Shapes.aabbOverlap(P[i], q, reach) then
					table.insert(cand, models[q.index])
					table.insert(higher, r < rank[i])
				end
			end
			u += C.UNITS_PER_BOX * N
			local _, w = C.shown(models[i], cand, higher, Geo.ENCLOSED_EXPOSED_MAX * models[i].total, math.huge)
			u += w
		end
	end
	return u
end

local rows = {}
print(fmt("%-46s %5s %9s %9s %8s %8s %8s %7s | %9s %8s %8s %6s", "design", "parts", "units", "verdict", "exposure", "old v", "old exp", "ns/u",
	"tests", "boxes", "polys", "facets"))
for _, d in ipairs(designs) do
	local P = L.prep(d.parts)
	local Po = L.prep(d.parts, L.OldShapes)
	local ex = L.SamplingV.exposure(P, nil)
	local vw = ex.verdictWork
	if vw < MINU then continue end
	local e = if QUICK then ex else L.Sampling.exposure(P, nil)
	local calls = 0
	for i = 1, #P do if P[i].volume >= L.Balance.Geometry.MIN_PART_VOLUME then calls += 1 end end
	local counts = { test = units(K.test, P), box = units(K.box, P), poly = units(K.poly, P), facet = units(K.facet, P) }
	local tv, te, to, toe = {}, {}, {}, {}
	for r = 1, RUNS do
		local t0 = os.clock()
		L.SamplingV.exposure(P, nil)
		local t1 = os.clock()
		if QUICK then
			tv[r], to[r], te[r], toe[r] = (t1 - t0) * 1000, 0, 0, 0
		else
			L.OldSamplingV.exposure(Po, nil)
			local t2 = os.clock()
			L.Sampling.exposure(P, nil)
			local t3 = os.clock()
			L.OldSampling.exposure(Po, nil)
			local t4 = os.clock()
			tv[r], to[r], te[r], toe[r] = (t1 - t0) * 1000, (t2 - t1) * 1000, (t3 - t2) * 1000, (t4 - t3) * 1000
		end
	end
	local mv, me, mo, moe = L.median(tv), L.median(te), L.median(to), L.median(toe)
	print(fmt("%-46s %5d %9.0f %9.3f %8.3f %8.3f %8.3f %7.1f | %9.0f %8.0f %8.0f %6.0f%s", string.sub(d.name, 1, 46), #P, vw, mv, me, mo, moe,
		mv * 1e6 / math.max(vw, 1), counts.test, counts.box, counts.poly, counts.facet, if e.capped then " CAPPED" else ""))
	table.insert(rows, fmt('{"name":%q,"parts":%d,"units":%.3f,"verdict":%.4f,"exposure":%.4f,"oldVerdict":%.4f,"oldExposure":%.4f,"tests":%.1f,"boxes":%.1f,"polys":%.1f,"facets":%.1f,"calls":%d,"capped":%s}',
		d.name, #P, vw, mv, me, mo, moe, counts.test, counts.box, counts.poly, counts.facet, calls, tostring(e.capped)))
end
if outFile then
	fs.writeFile(outFile, "[\n" .. table.concat(rows, ",\n") .. "\n]\n")
end
