--!nocheck
-- M1 on A's other models (canonical frames; canonical + sagitta 0.002): A's reading against the judge's brute force run on
-- A's own model geometry (its facets and half-spaces, taken over as they are), with the tie bracket of xcheck.luau.
-- args: set [every] [model canon|fine]
local process = require("@lune/process")
local L = require("./jlib")
local S = require("./jsets")
local T = require("./tangles")
local JB = L.JBrute
local fmt = string.format

local set = process.args[1] or "fixtures"
local every = tonumber(process.args[2] or "1") or 1
local modelName = process.args[3] or "canon"
local opts = if modelName == "fine" then { canon = true, sag = 0.002 } else { canon = true }
local CoverC = require("./proto/CoverC")

local designs
if set == "fixtures" then
	designs = S.fixtures()
elseif set == "attacksA" then
	designs = S.attackCorpusA()
elseif set == "plausible" then
	local PD = require("./repo/tests/Physics/PlausibleDesigns")
	designs = {}
	for _, d in ipairs(PD.all()) do table.insert(designs, { name = d.name or "?", parts = S.clean(d.parts) }) end
elseif set == "bfam" then
	designs = S.bFamilies(1)
elseif string.sub(set, 1, 7) == "tangles" then
	designs = T.corpus(tonumber(string.sub(set, 8)) or 7, 4000, 3, 14)
end

-- A's model as the brute force's
local function toJ(am)
	local m = { part = am.part, facets = {}, planes = {}, nx = {}, ny = {}, nz = {}, area = {}, box = {}, total = am.total }
	for f = 1, am.n do
		m.facets[f] = am.poly[f]
		m.nx[f], m.ny[f], m.nz[f] = am.nx[f], am.ny[f], am.nz[f]
		m.area[f] = am.area[f]
		local b = 6 * (f - 1)
		m.box[f] = { am.box[b + 1], am.box[b + 2], am.box[b + 3], am.box[b + 4], am.box[b + 5], am.box[b + 6] }
	end
	for i = 1, am.np do
		m.planes[i] = { am.planes[4 * i - 3], am.planes[4 * i - 2], am.planes[4 * i - 1], am.planes[4 * i] }
	end
	m.sag = am.sag -- the conservative option's, when present
	return m
end

local st = { designs = 0, parts = 0, over = 0, aErr = 0, ties = 0, worst = 0, worstName = "", worstErr = 0, worstErrName = "", skipped = 0 }
local t0 = os.clock()
for k, d in ipairs(designs) do
	if (k - 1) % every == 0 then
		st.designs += 1
		local P = L.prep(d.parts)
		local flags = { L.flags(P) }
		local rank, byRank, isCopy, dust, hider = table.unpack(flags)
		local A, Am
		if modelName == "cons" then
			-- the conservative-probe option: CoverC's reading and models (with their sag)
			Am = {}
			for i = 1, #P do if hider[i] then Am[i] = CoverC.model(P[i], opts) end end
			A = {}
			for i = 1, #P do
				if hider[i] then
					local idx, higher = L.cands(P, i, rank, byRank, hider)
					local hm = {}
					for kk, j in ipairs(idx) do hm[kk] = Am[j] end
					A[i] = { shown = CoverC.shown(Am[i], hm, higher, math.huge, nil, true), area = Am[i].total }
				end
			end
		else
			A, Am = L.readA(P, opts, flags)
		end
		local Jm = {}
		for i = 1, #P do
			if Am[i] then Jm[i] = toJ(Am[i]) end
		end
		for i = 1, #P do
			if A[i] then
				st.parts += 1
				local idx, higher = L.cands(P, i, rank, byRank, hider)
				local hm = {}
				for kk, j in ipairs(idx) do hm[kk] = Jm[j] end
				local s, skip = 0, false
				for f = 1, #Jm[i].facets do
					local sf = JB.facetShown(Jm[i], f, hm, higher, 2000)
					if sf == nil then skip = true break end
					s += sf
				end
				if skip then
					st.skipped += 1
				else
					local a, j = A[i].shown / A[i].area, s / A[i].area
					local dd = math.abs(a - j)
					if dd > st.worst then st.worst, st.worstName = dd, fmt("%s part %d (%s): A %.12f J %.12f", d.name, i, P[i].shape, a, j) end
					if dd > 1e-9 then
						st.over += 1
						-- settle by the tie bracket, facet by facet
						local Af
						if modelName == "cons" then
							Af = {}
							local m = Am[i]
							local hmA = {}
							for kk, j in ipairs(idx) do hmA[kk] = Am[j] end
							for f = 1, m.n do
								local b = 6 * (f - 1)
								local sub = { part = m.part, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
									area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
									total = m.area[f], np = m.np, planes = m.planes, inner = m.inner, sag = { m.sag[f] } }
								if m.np ~= m.n then sub.sag = { 0 } end
								sub.np = 1 -- a one-facet target: its own sag lookup goes by facet 1
								Af[f] = CoverC.shown(sub, hmA, higher, math.huge, nil, true)
							end
						else
							Af = L.readAFacets(P, i, Am, flags)
						end
						local err, tie = 0, 0
						for f = 1, #Jm[i].facets do
							local lo = JB.facetShown(Jm[i], f, hm, higher, nil, 1e-11)
							local hi = JB.facetShown(Jm[i], f, hm, higher, nil, -1e-11)
							local tol = 1e-12 * Jm[i].area[f] + 1e-15
							err += math.max(0, lo - tol - Af[f], Af[f] - hi - tol)
							tie += hi - lo
						end
						err /= A[i].area
						if err > 1e-9 then
							st.aErr += 1
							if err > st.worstErr then st.worstErr, st.worstErrName = err, fmt("%s part %d (%s)", d.name, i, P[i].shape) end
						elseif tie / A[i].area > 1e-9 then
							st.ties += 1
						end
					end
				end
			end
		end
	end
end
print(fmt("M1 on A's %s model, %s every %d: %d designs, %d parts (%d over the edge limit), %.0f s", modelName, set, every, st.designs, st.parts, st.skipped, os.clock() - t0))
print(fmt("  largest |A - brute| %.3g (%s)", st.worst, st.worstName))
print(fmt("  parts over 1e-9: %d, of which exact ties %d, outside the tie bracket %d (worst %.3g %s)", st.over, st.ties, st.aErr, st.worstErr, st.worstErrName))
