--!nocheck
-- V1 (m2x) harness: designs, the build's verdict and reading, the truth (VisibleOracle), D through the emulator.
-- ./repo is the pristine copy; ./emu/repo a copy whose Sampling takes FORCE.kept (the emulator's only).
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Sampling = require("./repo/src/shared/Physics/Sampling")
local Cover = require("./repo/src/shared/Physics/Cover")
local Analyze = require("./repo/src/shared/Physics/Analyze")
local Balance = require("./repo/src/shared/Definitions/Balance")
local Quat = require("./repo/src/shared/Blueprint/Quat")
local Mirror = require("./repo/src/shared/Blueprint/Mirror")
local Canonical = require("./repo/src/shared/Blueprint/Canonical")
local Oracle = require("./repo/tests/Physics/VisibleOracle")
local Fx = require("./repo/docs/spec/prototypes/S2/v2/fixtures")
local Blueprints = require("./repo/tests/fixtures/Blueprints")
local Emu = require("./emu/proto/analyze_build")
local ESampling = require("./emu/repo/src/shared/Physics/Sampling")
local fmt = string.format

local L = {}
L.Shapes, L.Sampling, L.Cover, L.Analyze, L.Balance, L.Quat, L.Mirror, L.Canonical, L.Oracle, L.Fx, L.Blueprints, L.Emu =
	Shapes, Sampling, Cover, Analyze, Balance, Quat, Mirror, Canonical, Oracle, Fx, Blueprints, Emu
L.Geo = Balance.Geometry
L.I = { 0, 0, 0, 1 }
local S45 = 0.70710678118654757
L.Z90 = { 0, 0, S45, S45 }
L.Y90 = { 0, S45, 0, S45 }
L.X90 = { S45, 0, 0, S45 }

function L.axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end

function L.part(slot, shape, pos, rot, size, material, label)
	return { id = 0, label = label or shape, shape = shape, slot = slot, material = material or "Iron",
		pos = { pos[1], pos[2], pos[3] }, rot = rot or L.I, size = { size[1], size[2], size[3] } }
end

function L.copyPart(p)
	return { id = p.id, label = p.label, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron",
		pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
		size = { p.size[1], p.size[2], p.size[3] } }
end

function L.copyParts(parts)
	local out = table.create(#parts)
	for i, p in ipairs(parts) do
		out[i] = L.copyPart(p)
	end
	return out
end

function L.renumber(parts)
	for i, p in ipairs(parts) do
		p.id = i
	end
	return parts
end

function L.prep(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do
		P[i] = Shapes.prepare(p, i)
	end
	return P
end

function L.fixture(prefix)
	for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
		for _, b in ipairs(list) do
			if string.sub(b.name, 1, #prefix) == prefix then
				return L.copyParts(b.parts), b.name
			end
		end
	end
	error("no fixture " .. prefix)
end

function L.repoFixture(id)
	return L.copyParts(Blueprints.core(id).parts)
end

-- Sampling's hiders of part i (as Sampling.exposure hands them over)
function L.hidersOf(P, i)
	local rank, order = Sampling.ranked(P)
	local reach = L.Geo.HIDE_OFFSET + 2 * L.Geo.EPS_GEOM
	local out, higher = {}, {}
	for r = 1, #order do
		local q = order[r]
		local j = q.index
		local copy = r > 1 and Shapes.sameSolid(q, order[r - 1])
		if j ~= i and not copy and q.volume >= L.Geo.MIN_PART_VOLUME and Shapes.aabbOverlap(P[i], q, reach) then
			table.insert(out, j)
			table.insert(higher, r < rank[i])
		end
	end
	return out, higher
end

-- the build's reading of part i, whole: share of its model
function L.readOf(P, i, models)
	local index, higher = L.hidersOf(P, i)
	local hm = {}
	for k, j in ipairs(index) do
		hm[k] = (models and models[j]) or Cover.model(P[j])
	end
	local m = (models and models[i]) or Cover.model(P[i])
	local shown, used = Cover.shown(m, hm, higher, math.huge, math.huge)
	return shown / m.total, used
end

-- per part: the build's whole reading (false for copies and Dust)
function L.readAll(P)
	local _, order = Sampling.ranked(P)
	local isCopy = {}
	for r = 2, #order do
		isCopy[order[r].index] = Shapes.sameSolid(order[r], order[r - 1])
	end
	local models = {}
	for i = 1, #P do
		if not isCopy[i] and P[i].volume >= L.Geo.MIN_PART_VOLUME then
			models[i] = Cover.model(P[i])
		end
	end
	local out = {}
	for i = 1, #P do
		if models[i] then
			out[i] = (L.readOf(P, i, models))
		else
			out[i] = false
		end
	end
	return out
end

-- per part: the truth's share (false for copies and Dust)
function L.truthAll(P, only)
	local _, _, hider = Oracle.flags(P)
	local out = {}
	for i = 1, #P do
		if hider[i] and (only == nil or only[i]) then
			out[i] = Oracle.share(P, i, hider)
		else
			out[i] = false
		end
	end
	return out
end

function L.truthRow(shares)
	local row = {}
	for i = 1, #shares do
		row[i] = shares[i] ~= false and shares[i] >= L.Geo.ENCLOSED_EXPOSED_MAX
	end
	return row
end

-- D through the emulator, on the build's verdict or a forced kept row
function L.emu(parts, keptRow)
	L.renumber(parts)
	ESampling.FORCE.kept = keptRow
	local ok, R = pcall(Emu.run, { name = "x", parts = parts }, { measureInvalid = true, build = true })
	ESampling.FORCE.kept = nil
	if not ok then
		error(R)
	end
	return R
end

function L.dline(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	if #t == 0 then
		return "no steps (" .. tostring(R.valid) .. ")"
	end
	return table.concat(t, ", ")
end

function L.dDiff(Ra, Rb)
	local worst, tier, step = 0, false, ""
	if not Ra.steps or not Rb.steps then
		return -1, false, "nosteps"
	end
	for i, s in ipairs(Ra.steps) do
		local o = Rb.steps[i]
		if math.abs(s.d - o.d) > worst then
			worst, step = math.abs(s.d - o.d), s.step
		end
		tier = tier or s.tier ~= o.tier
	end
	return worst, tier, step
end

function L.run(parts, opts)
	L.renumber(parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	return Analyze.run(core, opts or { measureInvalid = true })
end

function L.codes(r)
	local codes = {}
	for _, e in ipairs(r.validation.errors) do
		table.insert(codes, e.code .. (e.slot and ("/" .. e.slot) or "") .. (e.partId and ("#" .. e.partId) or ""))
	end
	return table.concat(codes, ",")
end

-- canonical form check through the repo's Canonical
function L.canonical(parts)
	L.renumber(parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local ok, why = Canonical.isCanonical(core)
	return ok, why
end

function L.pct(x)
	if x == false or x == nil then
		return "-"
	end
	return fmt("%.3f%%", 100 * x)
end

return L
