--!nocheck
-- Cross-check: A and B (baseline model, full reading, no early stop) per part on one corpus, and the judge's brute force
-- (JBrute, J0) on every part (up to an edge limit per facet union). Wherever two of A, B, J0 differ by more than 1e-9 of
-- the part's model area, every facet is settled against a bracket: J run with every moved half-space moved out by 1e-11
-- (J+, hides more) and in by 1e-11 (J−). A reading inside [J+, J−] (± 1e-12 of the facet) is right up to a tie (the hide
-- test's boundary lies on the facet within rounding, so the bits decide); outside it, that reading is wrong by the gap.
-- args: set [every] [bruteLimit] [shard] [shards]
-- Writes out/xcheck_<set>[_shard].jsonl (one row per part that differs, with the parts) and prints a summary.
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./jlib")
local S = require("./jsets")
local T = require("./tangles")
local JB = L.JBrute
local fmt = string.format

local set = process.args[1] or "fixtures"
local every = tonumber(process.args[2] or "1") or 1
local bruteLimit = tonumber(process.args[3] or "1500") or 1500
local shard = tonumber(process.args[4] or "0") or 0
local shards = tonumber(process.args[5] or "1") or 1
local TIE = 1e-11

local designs
if set == "fixtures" then
	designs = S.fixtures()
elseif set == "worstP" then
	designs = S.worstP()
elseif set == "climbed" then
	designs = S.climbed()
elseif set == "attacksJson" then
	designs = S.attacksJson()
elseif set == "attacksA" then
	designs = S.attackCorpusA()
elseif set == "climbA" then
	designs = S.climbA()
elseif set == "climbB" then
	designs = S.climbB()
elseif set == "bfam" then
	designs = S.bFamilies(1)
elseif set == "worstA" then
	designs = S.worstA()
elseif set == "worstB" then
	designs = S.worstB()
elseif set == "plausible" then
	local PD = require("./repo/tests/Physics/PlausibleDesigns")
	designs = {}
	for _, d in ipairs(PD.all()) do table.insert(designs, { name = d.name or d.family or "?", parts = S.clean(d.parts) }) end
elseif string.sub(set, 1, 7) == "tangles" then
	local seed = tonumber(string.sub(set, 8)) or 1
	designs = T.corpus(seed, 4000, 3, 14)
elseif string.sub(set, 1, 5) == "file:" then
	local path = string.sub(set, 6)
	if string.sub(path, -6) == ".jsonl" then designs = S.jsonl(path, "") else designs = S.json(path, "") end
else
	error("unknown set " .. set)
end

local tag = string.gsub(set, "[^%w_]", "_")
local outPath = fmt("%sout/xcheck_%s%s.jsonl", S.JUDGE, tag, if shards > 1 then "_" .. shard else "")
local lines = {}
local t0 = os.clock()
local st = { designs = 0, parts = 0, jParts = 0, jSkipped = 0, abOver = 0, worstAB = 0, worstABName = "",
	aErrParts = 0, bErrParts = 0, tieParts = 0, worstAErr = 0, worstBErr = 0, worstAErrName = "", worstBErrName = "",
	worstTie = 0, worstTieName = "", abHist = { 0, 0, 0, 0, 0, 0 }, areaDiff = 0, matchWorst = 0, unsettled = 0 }

local function classify(d, P, flags, i, A, Am, B, Bm, J0, Jm)
	local rank, byRank, isCopy, dust, hider = table.unpack(flags)
	local area = A[i].area
	local Af, Acent = L.readAFacets(P, i, Am, flags)
	local Bf, Bcent = B[i].per, L.centB(Bm[i])
	local Jcent = L.centJ(Jm[i])
	local mapA, wa = L.matchFacets(Jcent, Acent)
	local mapB, wb = L.matchFacets(Jcent, Bcent)
	st.matchWorst = math.max(st.matchWorst, wa, wb)
	local idx, higher = L.cands(P, i, rank, byRank, hider)
	local hm = {}
	for k, j in ipairs(idx) do hm[k] = Jm[j] end
	local aErr, bErr, tie, facets = 0, 0, 0, {}
	for f = 1, #Jm[i].facets do
		local lo = JB.facetShown(Jm[i], f, hm, higher, nil, TIE) -- pieces grown: the least that can show
		local hi = JB.facetShown(Jm[i], f, hm, higher, nil, -TIE)
		local a, b = Af[mapA[f]], Bf[mapB[f]]
		local tol = 1e-12 * Jm[i].area[f] + 1e-15
		local ea = math.max(0, lo - tol - a, a - hi - tol)
		local eb = math.max(0, lo - tol - b, b - hi - tol)
		aErr += ea
		bErr += eb
		tie += hi - lo
		if ea > 1e-9 * area or eb > 1e-9 * area or hi - lo > 1e-9 * area then
			table.insert(facets, fmt('{"f":%d,"a":%.12g,"b":%.12g,"lo":%.12g,"hi":%.12g,"area":%.6g}', f, a, b, lo, hi, Jm[i].area[f]))
		end
	end
	return aErr / area, bErr / area, tie / area, facets
end

for k, d in ipairs(designs) do
	if (k - 1) % every == 0 and ((k - 1) // every) % shards == shard then
		st.designs += 1
		local P = L.prep(d.parts)
		local flags = { L.flags(P) }
		local A, Am = L.readA(P, nil, flags)
		local B, Bm = L.readB(P, 32, 4, false, flags)
		local J0, Jm = JB.readAll(P, flags, L.cands, nil, bruteLimit)
		for i = 1, #P do
			if A[i] then
				st.parts += 1
				local area = A[i].area
				st.areaDiff = math.max(st.areaDiff, math.abs(area - B[i].area) / area, math.abs(area - J0[i].area) / area)
				local a, b = A[i].shown / area, B[i].shown / area
				local dAB = math.abs(a - b)
				local kk = if dAB < 1e-12 then 1 elseif dAB < 1e-10 then 2 elseif dAB < 1e-9 then 3 elseif dAB < 1e-6 then 4 elseif dAB < 1e-3 then 5 else 6
				st.abHist[kk] += 1
				if dAB > 1e-9 then st.abOver += 1 end
				if dAB > st.worstAB then
					st.worstAB, st.worstABName = dAB, fmt("%s part %d (%s): A %.12f B %.12f", d.name, i, P[i].shape, a, b)
				end
				local j = nil
				if J0[i].skipped then
					st.jSkipped += 1
				else
					st.jParts += 1
					j = J0[i].shown / area
				end
				local dmax = math.max(dAB, if j then math.abs(a - j) else 0, if j then math.abs(b - j) else 0)
				if dmax > 1e-9 then
					local row = fmt('{"d":"%s","i":%d,"shape":"%s","area":%.17g,"a":%.17g,"b":%.17g', d.name, i, P[i].shape, area, a, b)
					if j then
						local ea, eb, tie, facets = classify(d, P, flags, i, A, Am, B, Bm, J0, Jm)
						row ..= fmt(',"j":%.17g,"aErr":%.6g,"bErr":%.6g,"tie":%.6g,"facets":[%s]', j, ea, eb, tie, table.concat(facets, ","))
						if ea > 1e-9 then
							st.aErrParts += 1
							if ea > st.worstAErr then st.worstAErr, st.worstAErrName = ea, fmt("%s part %d (%s): A %.9f B %.9f J %.9f tie %.3g", d.name, i, P[i].shape, a, b, j, tie) end
						end
						if eb > 1e-9 then
							st.bErrParts += 1
							if eb > st.worstBErr then st.worstBErr, st.worstBErrName = eb, fmt("%s part %d (%s): A %.9f B %.9f J %.9f tie %.3g", d.name, i, P[i].shape, a, b, j, tie) end
						end
						if tie > 1e-9 then
							st.tieParts += 1
							if tie > st.worstTie then st.worstTie, st.worstTieName = tie, fmt("%s part %d (%s): A %.9f B %.9f J %.9f", d.name, i, P[i].shape, a, b, j) end
						end
					else
						st.unsettled += 1
					end
					row ..= ',"parts":' .. L.encodeParts(d.parts) .. "}"
					table.insert(lines, row)
				end
			end
		end
		if st.designs % 200 == 0 then
			print(fmt("  %d designs, %d parts, |A-B|>1e-9 %d, A err %d, B err %d, ties %d, %.1f s", st.designs, st.parts, st.abOver,
				st.aErrParts, st.bErrParts, st.tieParts, os.clock() - t0))
		end
	end
end
fs.writeFile(outPath, table.concat(lines, "\n") .. "\n")
print(fmt("XCHECK %s every %d shard %d/%d: %d designs, %d parts, %.1f s", set, every, shard, shards, st.designs, st.parts, os.clock() - t0))
print(fmt("  model area: largest relative difference between A, B, J %.3g; facet matching worst centroid gap %.3g", st.areaDiff, st.matchWorst))
print(fmt("  |A-B| share: <1e-12 %d, <1e-10 %d, <1e-9 %d, <1e-6 %d, <1e-3 %d, more %d", table.unpack(st.abHist)))
print(fmt("  largest |A-B| %.3g (%s)", st.worstAB, st.worstABName))
print(fmt("  brute force on %d parts (%d over the edge limit; %d differing parts unsettled for that)", st.jParts, st.jSkipped, st.unsettled))
print(fmt("  parts where A is outside the tie bracket by > 1e-9: %d, worst %.3g (%s)", st.aErrParts, st.worstAErr, st.worstAErrName))
print(fmt("  parts where B is outside the tie bracket by > 1e-9: %d, worst %.3g (%s)", st.bErrParts, st.worstBErr, st.worstBErrName))
print(fmt("  parts with a tie (bracket wider than 1e-9): %d, widest %.3g (%s)", st.tieParts, st.worstTie, st.worstTieName))
