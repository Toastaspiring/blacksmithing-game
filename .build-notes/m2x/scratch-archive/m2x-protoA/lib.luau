--!nocheck
-- protoA's shared harness: the new reading (repo/, Physics/Cover), the old one (base/, the build before), the truth
-- (repo/tests/Physics/VisibleOracle.luau, true shapes), on PartData lists.
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sampling = require("./repo/src/shared/Physics/Sampling")
local Cover = require("./repo/src/shared/Physics/Cover")
local BaseSampling = require("./base/src/shared/Physics/Sampling")
local BaseShapes = require("./base/src/shared/Physics/Shapes")
local Oracle = require("./repo/tests/Physics/VisibleOracle")
local Balance = require("./repo/src/shared/Definitions/Balance")
local Quat = require("./repo/src/shared/Blueprint/Quat")
local Geo = Balance.Geometry
local fmt = string.format

local L = {}
L.Shapes, L.Sampling, L.Cover, L.BaseSampling, L.Oracle, L.Quat = Shapes, Sampling, Cover, BaseSampling, Oracle, Quat
L.I = { 0, 0, 0, 1 }

function L.part(id, shape, slot, pos, rot, size, material)
	return { id = id, shape = shape, slot = slot or "Blade", material = material or "Iron", pos = pos, rot = rot or L.I, size = size }
end

function L.prep(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	return P
end

function L.prepBase(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do P[i] = BaseShapes.prepare(p, i) end
	return P
end

-- the flags of exposure: copies, dust, hiders (rank-based, as Sampling)
function L.flags(P)
	local N = #P
	local rank, byRank = Sampling.ranked(P)
	local isCopy = table.create(N, false)
	for r = 2, N do
		isCopy[byRank[r].index] = Shapes.sameSolid(byRank[r], byRank[r - 1])
	end
	local hider = table.create(N, false)
	local dust = table.create(N, false)
	for i = 1, N do
		dust[i] = P[i].volume < Geo.MIN_PART_VOLUME
		hider[i] = not isCopy[i] and not dust[i]
	end
	return rank, byRank, isCopy, dust, hider
end

-- The new reading in full (no early stop): per part share shown/modelArea (false for dust/copies), tests, verdict.
-- modelFn lets a variant model be used (default Cover.model).
function L.newShares(P, modelFn, coverMod)
	local C = coverMod or Cover
	local mf = modelFn or C.model
	local N = #P
	local rank, byRank, isCopy, dust, hider = L.flags(P)
	local models = {}
	for i = 1, N do
		if hider[i] then models[i] = mf(P[i]) end
	end
	local share, tests, kept, shown, area = {}, {}, {}, {}, {}
	local reach = Geo.HIDE_OFFSET + 2 * Geo.EPS_GEOM
	for i = 1, N do
		if hider[i] then
			local cand, higher = {}, {}
			for r = 1, N do
				local q = byRank[r]
				local j = q.index
				if j ~= i and hider[j] and Shapes.aabbOverlap(P[i], q, reach) then
					table.insert(cand, models[j])
					table.insert(higher, r < rank[i])
				end
			end
			local s, t = C.shown(models[i], cand, higher, math.huge, nil, true)
			share[i], tests[i], shown[i], area[i] = s / models[i].total, t, s, models[i].total
			kept[i] = s >= Geo.ENCLOSED_EXPOSED_MAX * models[i].total
		else
			share[i], tests[i], kept[i] = false, 0, false
		end
	end
	return share, kept, tests, shown, area
end

function L.newVerdict(parts)
	return Sampling.exposure(L.prep(parts)).kept
end

function L.oldVerdict(parts)
	return BaseSampling.exposure(L.prepBase(parts)).kept
end

-- truth: the oracle's share per part (false for dust/copies)
function L.truth(P)
	local isCopy, isDust, hider = Oracle.flags(P)
	local out = {}
	for i = 1, #P do
		if hider[i] then
			out[i] = Oracle.share(P, i, hider)
		else
			out[i] = false
		end
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
	return fmt("%.3f%%", x * 100)
end

-- JSON-ish encode of a parts list (for saving designs)
local function num(x)
	if x == math.floor(x) and math.abs(x) < 1e15 then return fmt("%d", x) end
	return fmt("%.17g", x)
end
function L.encodeParts(parts)
	local t = {}
	for _, p in ipairs(parts) do
		table.insert(t, fmt('{"id":%s,"shape":"%s","slot":"%s","material":"%s","pos":[%s,%s,%s],"rot":[%s,%s,%s,%s],"size":[%s,%s,%s]}',
			num(p.id), p.shape, p.slot, p.material or "Iron", num(p.pos[1]), num(p.pos[2]), num(p.pos[3]),
			num(p.rot[1]), num(p.rot[2]), num(p.rot[3]), num(p.rot[4]), num(p.size[1]), num(p.size[2]), num(p.size[3])))
	end
	return "[" .. table.concat(t, ",") .. "]"
end

return L
