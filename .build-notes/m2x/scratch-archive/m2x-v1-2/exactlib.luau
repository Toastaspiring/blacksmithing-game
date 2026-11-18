--!nocheck
-- V1 (m2x, round 2): the build's reading of every hider of a design (as Sampling hands its hiders over) against arrbrute
-- with every part that hides and no box test; a difference past EXACT of the part's area is then checked facet by facet
-- against the bracket of every moved half-space ±TIE.
local L = require("./lib")
local AB = require("./arrbrute")
AB.init(L.Geo)
local Cover = L.Cover

local E = {}
E.EXACT = 1e-9
E.TIE = 1e-11

local function oneFacet(m, f)
	local b = 6 * (f - 1)
	return {
		part = m.part, round = m.round, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
		area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
		total = m.area[f], np = 0, planes = {}, sag = { if m.round then m.sag[f] else 0 }, inner = 0, reach = m.reach,
		over = m.over, work = 0,
	}
end
E.oneFacet = oneFacet

local function finite(x)
	return x == x and x ~= math.huge and x ~= -math.huge
end

-- returns a list of records for parts outside the bracket, and counts
function E.check(P, opts)
	opts = opts or {}
	local models = L.models(P)
	local out = { checked = 0, ties = 0, past = 0, bad = {}, nonfinite = 0, maxdiff = 0 }
	for i = 1, #P do
		if models[i] and (opts.only == nil or opts.only[i]) then
			local m = models[i]
			local idx, higher = L.hidersOf(P, i, models)
			local hm = {}
			for k, j in ipairs(idx) do
				hm[k] = models[j]
			end
			local aidx, ahigher = L.allHiders(P, i, models)
			local am = {}
			for k, j in ipairs(aidx) do
				am[k] = models[j]
			end
			local shown, used = Cover.shown(m, hm, higher, math.huge, math.huge)
			if not finite(shown) or not finite(used) then
				out.nonfinite += 1
			end
			local brute = AB.shown(m, am, ahigher, 0)
			if brute == nil then
				out.past += 1
			else
				out.checked += 1
				local diff = math.abs(shown - brute)
				if diff > E.EXACT * m.total then
					out.ties += 1
					local worst = 0
					for f = 1, m.n do
						local lo = AB.facetShown(m, f, am, ahigher, E.TIE)
						local hi = AB.facetShown(m, f, am, ahigher, -E.TIE)
						if lo and hi then
							local c = Cover.shown(oneFacet(m, f), hm, higher, math.huge, math.huge)
							local tol = 1e-11 * m.area[f] + 1e-15
							local miss = math.max(lo - tol - c, c - hi - tol, 0)
							if miss > 0 then
								worst = math.max(worst, miss)
								table.insert(out.bad, { part = i, facet = f, c = c, lo = lo, hi = hi, total = m.total,
									shape = P[i].shape, miss = miss })
							end
						end
					end
					out.maxdiff = math.max(out.maxdiff, worst / m.total)
				end
			end
		end
	end
	return out
end

return E
