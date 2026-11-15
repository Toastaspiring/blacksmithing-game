--!nocheck
-- m2x-fix-4 lab after V2's vlab.luau: a tree's modules by name ("base" round 4's base, "cap" / "nocap" the build with and
-- without a cap's circle, "minors" the base with fixW2 and fixD alone, "now" the repo), what its verdict reads on a part
-- (its own PhysicsHelpers.reads), the truth (its VisibleOracle), and D through V1's emulator on its measure (emu_<name>:
-- the S2 v2 prototype + verdict/analyze_build, the tree's src with a FORCE.kept hook; mkemu.sh).
--   local V = require("./vlab").tree("cap")
local S = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local W = S .. "/m2x-fix-4"
local ROOTS = { base = S .. "/m2x-r4-base/repo", cap = W .. "/var_cap", nocap = W .. "/var_nocap", minors = W .. "/var_minors",
	now = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game" }
local EMUS = { base = W .. "/emu_base", cap = W .. "/emu_cap", nocap = W .. "/emu_nocap", now = W .. "/emu_now" }
local fmt = string.format

local V = {}
local cache = {}

function V.tree(name)
	if cache[name] then
		return cache[name]
	end
	local root = ROOTS[name]
	local function req(p)
		return (require :: any)(root .. "/" .. p)
	end
	local L = { name = name, root = root }
	L.Shapes = req("src/shared/Physics/Shapes")
	L.Sampling = req("src/shared/Physics/Sampling")
	L.Cover = req("src/shared/Physics/Cover")
	L.Analyze = req("src/shared/Physics/Analyze")
	L.Quat = req("src/shared/Blueprint/Quat")
	L.Mirror = req("src/shared/Blueprint/Mirror")
	L.Balance = req("src/shared/Definitions/Balance")
	L.H = req("tests/Physics/PhysicsHelpers")
	L.Oracle = req("tests/Physics/VisibleOracle")
	L.Blueprints = req("tests/fixtures/Blueprints")
	L.Geo = L.Balance.Geometry
	local Shapes, Sampling = L.Shapes, L.Sampling

	-- parts as plain tables, renumbered 1…n
	function L.copy(parts)
		local out = table.create(#parts)
		for i, p in ipairs(parts) do
			out[i] = { id = i, label = p.label or p.shape, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron",
				pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
				size = { p.size[1], p.size[2], p.size[3] } }
		end
		return out
	end

	function L.part(slot, shape, pos, rot, size)
		return { id = 0, label = shape, slot = slot, shape = shape, material = "Iron", pos = { pos[1], pos[2], pos[3] },
			rot = rot or { 0, 0, 0, 1 }, size = { size[1], size[2], size[3] } }
	end

	function L.prep(parts)
		local P = table.create(#parts)
		for i, p in ipairs(parts) do
			P[i] = Shapes.prepare(p, i)
		end
		return P
	end

	-- the verdict's reading of every part that has a model (false for Dust and exact copies), and the kept row
	function L.reads(P)
		local _, _, hider = L.Oracle.flags(P)
		local out = {}
		for i = 1, #P do
			out[i] = if hider[i] then (L.H.reads(P, i)) else false
		end
		return out, Sampling.exposure(P).kept
	end

	-- the truth's share of each part in `only` (all when nil), and its kept row
	function L.truth(P, only)
		local _, _, hider = L.Oracle.flags(P)
		local out, row = {}, {}
		for i = 1, #P do
			out[i] = if hider[i] and (only == nil or only[i]) then L.Oracle.share(P, i, hider) else false
			row[i] = out[i] ~= false and out[i] >= L.Geo.ENCLOSED_EXPOSED_MAX
		end
		return out, row
	end

	-- D through the emulator on this tree's measure: its own verdict, or a forced kept row
	function L.emu(parts, keptRow)
		local Emu = (require :: any)(EMUS[name] .. "/proto/analyze_build")
		local ES = (require :: any)(EMUS[name] .. "/repo/src/shared/Physics/Sampling")
		ES.FORCE.kept = keptRow
		local ok, R = pcall(Emu.run, { name = "x", parts = L.copy(parts) }, { measureInvalid = true, build = true })
		ES.FORCE.kept = nil
		if not ok then
			error(R)
		end
		return R
	end

	function L.valid(parts)
		local r = L.Analyze.run({ schema = 1, name = "x", type = "Sword", parts = L.copy(parts) }, { measureInvalid = true })
		local codes = {}
		for _, e in ipairs(r.validation.errors) do
			table.insert(codes, e.code)
		end
		return r.validation.ok, table.concat(codes, ",")
	end

	cache[name] = L
	return L
end

function V.dline(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	return if #t == 0 then "no steps (" .. tostring(R.valid) .. ")" else table.concat(t, ", ")
end

-- the largest |ΔD| between two runs and whether a tier differs
function V.dDiff(Ra, Rb)
	if not Ra.steps or not Rb.steps then
		return -1, false
	end
	local worst, tier = 0, false
	for i, s in ipairs(Ra.steps) do
		worst = math.max(worst, math.abs(s.d - Rb.steps[i].d))
		tier = tier or s.tier ~= Rb.steps[i].tier
	end
	return worst, tier
end

function V.pct(x)
	return if x == false or x == nil then "-" else fmt("%.3f%%", 100 * x)
end

function V.dirs()
	local S3 = 1 / math.sqrt(3)
	return { { S3, S3, S3 }, { S3, -S3, S3 }, { S3, S3, -S3 }, { S3, -S3, -S3 } }
end

return V
