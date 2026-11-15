--!nocheck
-- fix-2 harness: a tree by name (S = the repo as the verifiers read it, V = the trial, R1 = the build before the fix round,
-- or any folder holding src/ and tests/), its verdict, units and D through its emulator (V2's: the prototype's edge and factor
-- formulas on the tree's kept, exposedKept, contact and ownership).
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-2"
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local fmt = string.format

local ROOTS = { S = W .. "/cur", V = W .. "/v", R1 = SCR .. "/m2x-fix-1/base" }
local EMUS = { S = W .. "/emuS", V = W .. "/emuV", R1 = W .. "/emuR1" }

local M = {}
M.W, M.SCR = W, SCR

local cache = {}
function M.tree(name)
	if cache[name] then
		return cache[name]
	end
	local root = ROOTS[name] or name
	local function req(p)
		return (require :: any)(root .. "/" .. p)
	end
	local T = {
		name = name,
		root = root,
		Shapes = req("src/shared/Physics/Shapes"),
		Sampling = req("src/shared/Physics/Sampling"),
		Cover = req("src/shared/Physics/Cover"),
		Analyze = req("src/shared/Physics/Analyze"),
		MassProps = req("src/shared/Physics/MassProps"),
		Balance = req("src/shared/Definitions/Balance"),
		Canonical = req("src/shared/Blueprint/Canonical"),
		EquipmentTypes = req("src/shared/Definitions/EquipmentTypes"),
	}
	if EMUS[name] then
		T.Emu = (require :: any)(EMUS[name] .. "/proto/analyze_build")
		T.ESampling = (require :: any)(EMUS[name] .. "/repo/src/shared/Physics/Sampling")
	end
	cache[name] = T
	return T
end

M.I = { 0, 0, 0, 1 }
local S45 = 0.70710678118654757
M.Z90 = { 0, 0, S45, S45 }
M.Y90 = { 0, S45, 0, S45 }

function M.part(slot, shape, pos, rot, size, material)
	return { id = 0, shape = shape, slot = slot, material = material or "Iron", pos = { pos[1], pos[2], pos[3] },
		rot = { rot[1], rot[2], rot[3], rot[4] }, size = { size[1], size[2], size[3] } }
end

function M.copyParts(parts)
	local out = table.create(#parts)
	for i, p in ipairs(parts) do
		out[i] = { id = i, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end

function M.renumber(parts)
	for i, p in ipairs(parts) do
		p.id = i
	end
	return parts
end

local Fx = (require :: any)(W .. "/cur/docs/spec/prototypes/S2/v2/fixtures")
local Blueprints = (require :: any)(W .. "/cur/tests/fixtures/Blueprints")
M.Fx, M.Blueprints = Fx, Blueprints

function M.fixture(prefix)
	for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf(), Fx.regression() }) do
		for _, b in ipairs(list) do
			local bb = b.fixture or b
			if string.sub(bb.name, 1, #prefix) == prefix then
				return M.copyParts(bb.parts), bb.name
			end
		end
	end
	error("no fixture " .. prefix)
end

function M.repo(id)
	return M.copyParts(Blueprints.core(id).parts)
end

function M.prep(T, parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do
		P[i] = T.Shapes.prepare(p, i)
	end
	return P
end

function M.exposure(T, parts)
	return T.Sampling.exposure(M.prep(T, parts))
end

function M.units(T, parts)
	return T.Sampling.exposure(M.prep(T, parts)).verdictWork
end

-- D through the tree's emulator, on its own verdict or on a forced kept row
function M.emu(T, parts, keptRow)
	M.renumber(parts)
	T.ESampling.FORCE.kept = keptRow
	local ok, R = pcall(T.Emu.run, { name = "x", parts = M.copyParts(parts) }, { measureInvalid = true, build = true })
	T.ESampling.FORCE.kept = nil
	if not ok then
		error(R)
	end
	return R
end

function M.dline(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	if #t == 0 then
		return "no steps"
	end
	return table.concat(t, ", ")
end

function M.dOf(R, step)
	for _, s in ipairs(R.steps or {}) do
		if s.step == step then
			return s.d, s.tier
		end
	end
	return nil
end

function M.run(T, parts, opts)
	M.renumber(parts)
	return T.Analyze.run({ schema = 1, name = "x", type = "Sword", parts = M.copyParts(parts) }, opts)
end

function M.canonical(T, parts)
	M.renumber(parts)
	return T.Canonical.isCanonical({ schema = 1, name = "x", type = "Sword", parts = M.copyParts(parts) })
end

function M.mainBlade(parts)
	local best, bi = -1, nil
	for i, p in ipairs(parts) do
		if p.slot == "Blade" and p.size[1] * p.size[2] * p.size[3] > best then
			best, bi = p.size[1] * p.size[2] * p.size[3], i
		end
	end
	return bi
end

return M
