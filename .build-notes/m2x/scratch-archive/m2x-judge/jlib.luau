--!nocheck
-- The judge's harness: today's reading (repo/, the build), prototype A (subtraction) and prototype B (boundary
-- integral) read in place from their folders, the truth (VisibleOracle, true shapes) and the judge's own brute force on
-- the polyhedral model (JBrute). Parts are PartData lists; every reading gets the same Prepared parts.
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sampling = require("./repo/src/shared/Physics/Sampling") -- today's reading
local Balance = require("./repo/src/shared/Definitions/Balance")
local Oracle = require("./repo/tests/Physics/VisibleOracle")
local Quat = require("./repo/src/shared/Blueprint/Quat")
local ACover = require("../m2x-protoA/repo/src/shared/Physics/Cover")
local ASampling = require("../m2x-protoA/repo/src/shared/Physics/Sampling")
local BCover = require("../m2x-protoB/repo/src/shared/Physics/Cover")
local BSampling = require("../m2x-protoB/repo/src/shared/Physics/Sampling")
local JBrute = require("./JBrute")
local CoverC = require("./proto/CoverC") -- the conservative-probe option, a copy of A's Cover
local Geo = Balance.Geometry
local fmt = string.format

local L = {}
L.Shapes, L.Sampling, L.ACover, L.ASampling, L.BCover, L.BSampling, L.Oracle, L.Quat, L.JBrute, L.Geo =
	Shapes, Sampling, ACover, ASampling, BCover, BSampling, Oracle, Quat, JBrute, Geo
L.I = { 0, 0, 0, 1 }

function L.part(id, shape, slot, pos, rot, size, material)
	return { id = id, shape = shape, slot = slot or "Blade", material = material or "Iron", pos = pos, rot = rot or L.I,
		size = size }
end

function L.prep(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	return P
end

-- The flags of exposure, as Sampling computes them: rank, byRank, copies, Dust, hiders.
function L.flags(P)
	local N = #P
	local rank, byRank = Sampling.ranked(P)
	local isCopy = table.create(N, false)
	for r = 2, N do
		isCopy[byRank[r].index] = Shapes.sameSolid(byRank[r], byRank[r - 1])
	end
	local hider, dust = table.create(N, false), table.create(N, false)
	for i = 1, N do
		dust[i] = P[i].volume < Geo.MIN_PART_VOLUME
		hider[i] = not isCopy[i] and not dust[i]
	end
	return rank, byRank, isCopy, dust, hider
end

local REACH = Geo.HIDE_OFFSET + 2 * Geo.EPS_GEOM

-- candidates of part i in rank order: indices and higher flags
function L.cands(P, i, rank, byRank, hider)
	local idx, higher = {}, {}
	for r = 1, #P do
		local q = byRank[r]
		local j = q.index
		if j ~= i and hider[j] and Shapes.aabbOverlap(P[i], q, REACH) then
			table.insert(idx, j)
			table.insert(higher, r < rank[i])
		end
	end
	return idx, higher
end

-- A's full reading (no early stop): per part {shown, area, units} (nil for Dust/copies). opts: A's model options.
function L.readA(P, opts, flags)
	local rank, byRank, isCopy, dust, hider = table.unpack(flags or { L.flags(P) })
	local models = {}
	for i = 1, #P do
		if hider[i] then models[i] = ACover.model(P[i], opts) end
	end
	local out = {}
	for i = 1, #P do
		if hider[i] then
			local idx, higher = L.cands(P, i, rank, byRank, hider)
			local hm = {}
			for k, j in ipairs(idx) do hm[k] = models[j] end
			local units = 0
			local s, tests = ACover.shown(models[i], hm, higher, math.huge, function(u) units += u end, true)
			out[i] = { shown = s, area = models[i].total, units = units, tests = tests, nf = models[i].n }
		end
	end
	return out, models
end

-- B's full reading: the same, with B's context (cos, sin, ballGrid, canonical).
function L.readB(P, cyl, ballGrid, canonical, flags)
	local rank, byRank, isCopy, dust, hider = table.unpack(flags or { L.flags(P) })
	local cs, sn = Sampling.COS, Sampling.SIN
	local n = 32
	while n < (cyl or 32) do
		cs, sn = BCover.halve(cs, sn)
		n *= 2
	end
	local ctx = BCover.context(cs, sn, ballGrid or 4, canonical)
	local models = {}
	for i = 1, #P do
		if hider[i] then models[i] = BCover.model(ctx, P[i]) end
	end
	local out = {}
	for i = 1, #P do
		if hider[i] then
			local idx, higher = L.cands(P, i, rank, byRank, hider)
			local hp, hm = {}, {}
			for k, j in ipairs(idx) do
				hp[k], hm[k] = P[j], models[j]
			end
			local units = 0
			local per = BCover.facets(ctx, models[i], hp, hm, higher, function(u) units += u end)
			local s = 0
			for f = 1, #per do s += per[f] end
			out[i] = { shown = s, area = models[i].total, units = units, per = per, nf = models[i].nf }
		end
	end
	return out, models
end

-- the truth's share per part (false for Dust/copies)
function L.truth(P, i)
	local isCopy, isDust, hider = Oracle.flags(P)
	if not hider[i] then return false end
	return Oracle.share(P, i, hider)
end

function L.truthAll(P)
	local isCopy, isDust, hider = Oracle.flags(P)
	local out = {}
	for i = 1, #P do
		out[i] = if hider[i] then Oracle.share(P, i, hider) else false
	end
	return out
end

function L.axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end

function L.pct(x)
	if x == false or x == nil then return "-" end
	return fmt("%.4f%%", x * 100)
end

local function num(x)
	if x == math.floor(x) and math.abs(x) < 1e15 then return fmt("%d", x) end
	return fmt("%.17g", x)
end
L.num = num

function L.encodeParts(parts)
	local t = {}
	for _, p in ipairs(parts) do
		table.insert(t, fmt('{"id":%s,"label":"%s","shape":"%s","slot":"%s","material":"%s","pos":[%s,%s,%s],"rot":[%s,%s,%s,%s],"size":[%s,%s,%s]}',
			num(p.id), p.label or "", p.shape, p.slot, p.material or "Iron", num(p.pos[1]), num(p.pos[2]), num(p.pos[3]),
			num(p.rot[1]), num(p.rot[2]), num(p.rot[3]), num(p.rot[4]), num(p.size[1]), num(p.size[2]), num(p.size[3])))
	end
	return "[" .. table.concat(t, ",") .. "]"
end

function L.encodeDesign(name, parts)
	return fmt('{"name":"%s","parts":%s}', name, L.encodeParts(parts))
end

-- A per facet: each facet of part i's model read alone (a one-facet copy of the model), against the same hiders.
function L.readAFacets(P, i, models, flags)
	local rank, byRank, isCopy, dust, hider = table.unpack(flags)
	local m = models[i]
	local idx, higher = L.cands(P, i, rank, byRank, hider)
	local hm = {}
	for k, j in ipairs(idx) do hm[k] = models[j] end
	local out, cent = {}, {}
	for f = 1, m.n do
		local b = 6 * (f - 1)
		local sub = { part = m.part, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
			area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
			total = m.area[f], np = m.np, planes = m.planes, inner = m.inner }
		out[f] = ACover.shown(sub, hm, higher, math.huge, nil, true)
		local poly = m.poly[f]
		local cx, cy, cz, n = 0, 0, 0, #poly / 3
		for k = 1, #poly, 3 do cx, cy, cz = cx + poly[k], cy + poly[k + 1], cz + poly[k + 2] end
		cent[f] = { cx / n, cy / n, cz / n }
	end
	return out, cent
end

-- centroids of B's facets
function L.centB(m)
	local out = {}
	for f = 1, m.nf do
		local cx, cy, cz, n = 0, 0, 0, 0
		for k = m.first[f], m.first[f + 1] - 1 do
			cx, cy, cz, n = cx + m.wx[k], cy + m.wy[k], cz + m.wz[k], n + 1
		end
		out[f] = { cx / n, cy / n, cz / n }
	end
	return out
end

function L.centJ(m)
	local out = {}
	for f, v in ipairs(m.facets) do
		local cx, cy, cz, n = 0, 0, 0, #v / 3
		for k = 1, #v, 3 do cx, cy, cz = cx + v[k], cy + v[k + 1], cz + v[k + 2] end
		out[f] = { cx / n, cy / n, cz / n }
	end
	return out
end

-- map facets of list a to the nearest centroid in list b
function L.matchFacets(ca, cb)
	local map = {}
	local worst = 0
	for f, c in ipairs(ca) do
		local best, bi = math.huge, 0
		for g, d in ipairs(cb) do
			local dx, dy, dz = c[1] - d[1], c[2] - d[2], c[3] - d[3]
			local e = dx * dx + dy * dy + dz * dz
			if e < best then best, bi = e, g end
		end
		map[f] = bi
		worst = math.max(worst, math.sqrt(best))
	end
	return map, worst
end

-- the conservative-probe option's full reading (A's subtraction; round targets probe their sagitta further, round hiders'
-- half-spaces at the true support for the probe test only)
function L.readC(P, opts, flags)
	local rank, byRank, isCopy, dust, hider = table.unpack(flags or { L.flags(P) })
	local models = {}
	for i = 1, #P do
		if hider[i] then models[i] = CoverC.model(P[i], opts) end
	end
	local out = {}
	for i = 1, #P do
		if hider[i] then
			local idx, higher = L.cands(P, i, rank, byRank, hider)
			local hm = {}
			for k, j in ipairs(idx) do hm[k] = models[j] end
			local units = 0
			local s, tests = CoverC.shown(models[i], hm, higher, math.huge, function(u) units += u end, true)
			out[i] = { shown = s, area = models[i].total, units = units, tests = tests, nf = models[i].n }
		end
	end
	return out, models
end

return L
