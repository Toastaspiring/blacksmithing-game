--!nocheck
-- V1's shared harness.
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Quat = require("./repo/src/shared/Blueprint/Quat")
local Sampling = require("./repo/src/shared/Physics/Sampling")
local Analyze = require("./repo/src/shared/Physics/Analyze")
local Force = require("./force/Sampling")
local Emu = require("./proto/analyze_build")
local Fx = require("./proto/fixtures")
local T = require("./truth")
local fmt = string.format
local Dump = require("./work/Dump")

local V = {}
V.I = { 0, 0, 0, 1 }
V.Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }
V.T, V.Sampling, V.Analyze, V.Shapes, V.Quat, V.Force, V.Emu, V.Fx = T, Sampling, Analyze, Shapes, Quat, Force, Emu, Fx

function V.axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end

function V.part(label, shape, slot, pos, rot, size, material)
	return { id = 0, label = label, shape = shape, slot = slot, material = material or "Iron", pos = pos, rot = rot or V.I, size = size }
end

function V.copyPart(p)
	return { id = p.id, label = p.label, slot = p.slot, shape = p.shape, material = p.material, pos = { p.pos[1], p.pos[2], p.pos[3] },
		rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
end

function V.copyParts(parts)
	local out = table.create(#parts)
	for i, p in ipairs(parts) do out[i] = V.copyPart(p) end
	return out
end

function V.renumber(parts)
	for i, p in ipairs(parts) do p.id = i end
	return parts
end

function V.prep(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	return P
end

function V.fixture(prefix)
	for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
		for _, b in ipairs(list) do
			if string.sub(b.name, 1, #prefix) == prefix then
				return V.copyParts(b.parts), b.name
			end
		end
	end
	error("no fixture " .. prefix)
end

-- the build's verdict, the row and what it reads per part (no early exit)
function V.reads(parts)
	Dump.add(parts)
	V.renumber(parts)
	local P = V.prep(parts)
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

-- D through the emulator, on the build's verdict or on a forced kept row (the same measure)
function V.emu(parts, keptRow)
	Dump.add(parts)
	V.renumber(parts)
	Force.FORCE.kept = keptRow
	local R = Emu.run({ name = "x", parts = parts }, { measureInvalid = true, build = true })
	Force.FORCE.kept = nil
	return R
end

function V.dline(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	return table.concat(t, ", ")
end

function V.dDiff(Ra, Rb)
	local worst, tier, step = 0, false, ""
	for i, s in ipairs(Ra.steps or {}) do
		local o = Rb.steps[i]
		if math.abs(s.d - o.d) > worst then
			worst, step = math.abs(s.d - o.d), s.step
		end
		tier = tier or s.tier ~= o.tier
	end
	return worst, tier, step
end

-- a table of parts: true share, the build's reading and verdict
function V.show(parts, labels, cell)
	local real, read = V.reads(parts)
	local shares = T.all(parts, cell)
	local t = {}
	for i, p in ipairs(parts) do
		local want = labels == nil
		if labels then
			for _, l in ipairs(labels) do
				if p.label == l then want = true end
			end
		end
		if want then
			table.insert(t, fmt("%s(%s) true %s read %s %s", tostring(p.label or i), p.shape, if shares[i] then fmt("%.2f%%", shares[i] * 100) else "-", if read[i] then fmt("%.2f%%", read[i] * 100) else "-", if real.kept[i] then "kept" else "CLEANED"))
		end
	end
	return table.concat(t, "; "), real, read, shares
end

function V.valid(parts)
	Dump.add(parts)
	V.renumber(parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = parts }
	local r = Analyze.run(core, { measureInvalid = true })
	return r.validation.ok, r
end

return V
