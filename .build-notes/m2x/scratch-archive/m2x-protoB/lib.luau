--!nocheck
-- V1 round 2's harness: designs, the build's verdict and reading, D through the emulator.
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Quat = require("./repo/src/shared/Blueprint/Quat")
local Sampling = require("./repo/src/shared/Physics/Sampling")
local Analyze = require("./repo/src/shared/Physics/Analyze")
local Canonical = require("./repo/src/shared/Blueprint/Canonical")
local Force = require("./force/Sampling")
local Emu = require("./proto/analyze_build")
local Fx = require("./proto/fixtures")
local T = require("./truth")
local fmt = string.format
local Dump = require("./work/Dump")

local L = {}
L.I = { 0, 0, 0, 1 }
local S45 = 0.70710678118654757
L.Z90 = { 0, 0, S45, S45 } -- local X along world Y
L.Y90 = { 0, S45, 0, S45 } -- local X along world Z
L.T, L.Sampling, L.Analyze, L.Shapes, L.Quat, L.Force, L.Emu, L.Fx, L.Canonical = T, Sampling, Analyze, Shapes, Quat, Force, Emu, Fx, Canonical

function L.axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end

function L.part(label, shape, slot, pos, rot, size, material)
	return { id = 0, label = label, shape = shape, slot = slot, material = material or "Iron", pos = pos, rot = rot or L.I, size = size }
end

function L.copyPart(p)
	return { id = p.id, label = p.label, slot = p.slot, shape = p.shape, material = p.material, pos = { p.pos[1], p.pos[2], p.pos[3] },
		rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
end

function L.copyParts(parts)
	local out = table.create(#parts)
	for i, p in ipairs(parts) do out[i] = L.copyPart(p) end
	return out
end

function L.renumber(parts)
	for i, p in ipairs(parts) do p.id = i end
	return parts
end

function L.prep(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
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

-- the build's verdict and what it reads per part (no early exit in the instrumented copy, asserted equal)
function L.reads(parts)
	Dump.add(parts)
	L.renumber(parts)
	local P = L.prep(parts)
	local real = Sampling.exposure(P)
	Force.FORCE.read, Force.FORCE.fullRead = {}, true
	local ex = Force.exposure(P)
	local read = Force.FORCE.read
	Force.FORCE.read, Force.FORCE.fullRead = nil, nil
	for i = 1, #parts do
		assert(real.kept[i] == ex.kept[i], "the instrumented copy disagrees")
	end
	return real, read, P
end

-- D through the emulator, on the build's verdict or a forced kept row (the same measure)
function L.emu(parts, keptRow)
	Dump.add(parts)
	L.renumber(parts)
	Force.FORCE.kept = keptRow
	local R = Emu.run({ name = "x", parts = parts }, { measureInvalid = true, build = true })
	Force.FORCE.kept = nil
	return R
end

function L.dline(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	return table.concat(t, ", ")
end

function L.dDiff(Ra, Rb)
	local worst, tier, step = 0, false, ""
	if not Ra.steps or not Rb.steps then return -1, false, "nosteps" end
	for i, s in ipairs(Ra.steps) do
		local o = Rb.steps[i]
		if math.abs(s.d - o.d) > worst then
			worst, step = math.abs(s.d - o.d), s.step
		end
		tier = tier or s.tier ~= o.tier
	end
	return worst, tier, step
end

-- the design's validity through the build
function L.valid(parts)
	Dump.add(parts)
	L.renumber(parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local r = Analyze.run(core, { measureInvalid = true })
	local codes = {}
	for _, e in ipairs(r.validation.errors) do table.insert(codes, e.code .. (e.slot and ("/" .. e.slot) or "")) end
	return r.validation.ok, table.concat(codes, ","), r
end

-- true share, read and verdict of each named part
function L.show(parts, labels)
	local real, read = L.reads(parts)
	local shares = T.all(parts)
	local t = {}
	for i, p in ipairs(parts) do
		local want = labels == nil
		if labels then
			for _, l in ipairs(labels) do
				if p.label == l then want = true end
			end
		end
		if want then
			table.insert(t, fmt("%s#%d(%s) true %s read %s %s", tostring(p.label or i), i, p.shape, if shares[i] then fmt("%.2f%%", shares[i] * 100) else "-", if read[i] then fmt("%.2f%%", read[i] * 100) else "-", if real.kept[i] then "kept" else "CLEANED"))
		end
	end
	return table.concat(t, "; "), real, read, shares
end

-- a kept row by the truth: share >= 2 %
function L.truthRow(shares)
	local row = {}
	for i = 1, #shares do row[i] = shares[i] ~= false and shares[i] >= 0.02 end
	return row
end

-- the design against the truth: |dD| of the build's verdict and of the truth's
function L.vsTruth(parts)
	local real, read = L.reads(parts)
	local shares = T.all(parts)
	local row = L.truthRow(shares)
	local Rv, Rt = L.emu(parts), L.emu(parts, row)
	local w, tier, step = L.dDiff(Rv, Rt)
	return w, tier, step, Rv, Rt, shares, read, real
end

function L.ok(parts)
	local ok, codes = L.valid(parts)
	return if ok then "valid" else "INVALID " .. codes
end

return L
