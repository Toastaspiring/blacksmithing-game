--!nocheck
-- m2x-fix-4 lab (fix3/lab.luau): a tree's modules by name ("now" the repo, "base" round 4's base, "cap" / "nocap" the
-- build with and without a cap's circle, "minors" the base with fixW2 and fixD alone; or a root), its truth
-- (VisibleOracle), its reading, D through V1's emulator on a copy of its src (emu_<name>, mkemu.sh).
--   local L = require("./lab").tree("now")
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local W = SCR .. "/m2x-fix-4"
local ROOTS = {
	now = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game",
	base = SCR .. "/m2x-r4-base/repo",
	cap = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game",
	nocap = W .. "/var_nocap",
	minors = W .. "/var_minors",
}
local EMUS = { now = W .. "/emu_now", base = W .. "/emu_base", cap = W .. "/emu_cap", nocap = W .. "/emu_nocap" }
local fmt = string.format

local Lab = {}
Lab.SCR, Lab.ROOTS = SCR, ROOTS
local cache = {}

function Lab.tree(name)
	if cache[name] then
		return cache[name]
	end
	local root = ROOTS[name] or name
	local function req(p)
		return (require :: any)(root .. "/" .. p)
	end
	local L = {}
	L.root = root
	L.Shapes = req("src/shared/Physics/Shapes")
	L.Sampling = req("src/shared/Physics/Sampling")
	L.Cover = req("src/shared/Physics/Cover")
	L.Analyze = req("src/shared/Physics/Analyze")
	L.MassProps = req("src/shared/Physics/MassProps")
	L.Balance = req("src/shared/Definitions/Balance")
	L.EquipmentTypes = req("src/shared/Definitions/EquipmentTypes")
	L.Quat = req("src/shared/Blueprint/Quat")
	L.Mirror = req("src/shared/Blueprint/Mirror")
	L.Canonical = req("src/shared/Blueprint/Canonical")
	L.Oracle = req("tests/Physics/VisibleOracle")
	L.Brute = req("tests/Physics/CoverBrute")
	L.Fx = req("docs/spec/prototypes/S2/v2/fixtures")
	L.Blueprints = req("tests/fixtures/Blueprints")
	L.Geo = L.Balance.Geometry
	local Shapes, Sampling, Cover, Oracle, Quat = L.Shapes, L.Sampling, L.Cover, L.Oracle, L.Quat
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

	function L.part(slot, shape, pos, rot, size, material)
		return { id = 0, label = shape, shape = shape, slot = slot, material = material or "Iron",
			pos = { pos[1], pos[2], pos[3] }, rot = rot or L.I, size = { size[1], size[2], size[3] } }
	end

	function L.copyPart(p)
		return { id = p.id, label = p.label, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end

	function L.codes(r)
		local codes = {}
		for _, e in ipairs(r.validation.errors) do
			table.insert(codes, e.code .. (e.slot and ("/" .. e.slot) or "") .. (e.partId and ("#" .. e.partId) or ""))
		end
		return table.concat(codes, ",")
	end

	function L.canonical(parts)
		L.renumber(parts)
		return L.Canonical.isCanonical({ schema = 1, name = "x", type = "Sword", parts = parts })
	end

	function L.copyParts(parts)
		local out = table.create(#parts)
		for i, p in ipairs(parts) do
			out[i] = { id = p.id, label = p.label, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron",
				pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
				size = { p.size[1], p.size[2], p.size[3] } }
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
		for _, list in ipairs({ L.Fx.calibration(), L.Fx.golden(), L.Fx.perf(), L.Fx.regression() }) do
			for _, b in ipairs(list) do
				if string.sub(b.name, 1, #prefix) == prefix then
					return L.copyParts(b.parts), b.name
				end
			end
		end
		error("no fixture " .. prefix)
	end

	function L.repoFixture(id)
		return L.copyParts(L.Blueprints.core(id).parts)
	end

	-- exact copies as Sampling marks them
	function L.copies(P)
		local _, order = Sampling.ranked(P)
		local isCopy = {}
		for r = 2, #order do
			local p = order[r]
			for t = r - 1, 1, -1 do
				local q = order[t]
				if q.cx == p.cx and q.cy == p.cy and q.cz == p.cz and Shapes.sameSolid(p, q) then
					isCopy[p.index] = true
					break
				end
			end
		end
		return isCopy
	end

	function L.models(P)
		local isCopy = L.copies(P)
		local models = {}
		for i = 1, #P do
			if not isCopy[i] and P[i].volume >= L.Geo.MIN_PART_VOLUME then
				models[i] = Cover.model(P[i])
			end
		end
		return models, isCopy
	end

	-- Sampling's hiders of part i: reach + over + 2 EPS, rank order
	function L.hidersOf(P, i, models)
		local rank, order = Sampling.ranked(P)
		local reach = models[i].reach + 2 * L.Geo.EPS_GEOM
		local out, higher = {}, {}
		for r = 1, #order do
			local q = order[r]
			local j = q.index
			if j ~= i and models[j] and Shapes.aabbOverlap(P[i], q, reach + models[j].over) then
				table.insert(out, j)
				table.insert(higher, r < rank[i])
			end
		end
		return out, higher
	end

	-- the reading of part i, whole: (share of its model, units, shown area)
	function L.readOf(P, i, models)
		models = models or (L.models(P))
		local index, higher = L.hidersOf(P, i, models)
		local hm = {}
		for k, j in ipairs(index) do
			hm[k] = models[j]
		end
		local m = models[i]
		local shown, used = Cover.shown(m, hm, higher, math.huge, math.huge)
		return shown / m.total, used, shown
	end

	function L.readAll(P)
		local models = L.models(P)
		local out = {}
		for i = 1, #P do
			out[i] = if models[i] then (L.readOf(P, i, models)) else false
		end
		return out
	end

	-- the truth's share of part i (fine lattice), or of every part
	function L.truth(P, i, points)
		local _, _, hider = Oracle.flags(P)
		if points then
			return Oracle.measure(P, i, hider, points)
		end
		return Oracle.share(P, i, hider)
	end

	function L.truthAll(P, only)
		local _, _, hider = Oracle.flags(P)
		local out = {}
		for i = 1, #P do
			out[i] = if hider[i] and (only == nil or only[i]) then Oracle.share(P, i, hider) else false
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

	-- D through the emulator on this tree's measure, its own verdict or a forced kept row
	function L.emu(parts, keptRow)
		local emu = EMUS[name] or (root .. "/emu")
		local Emu = (require :: any)(emu .. "/proto/analyze_build")
		local ESampling = (require :: any)(emu .. "/repo/src/shared/Physics/Sampling")
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
		return L.Analyze.run({ schema = 1, name = "x", type = "Sword", parts = parts }, opts or { measureInvalid = true })
	end

	function L.valid(parts)
		local r = L.run(parts)
		local codes = {}
		for _, e in ipairs(r.validation.errors) do
			table.insert(codes, e.code)
		end
		return r.validation.ok, table.concat(codes, ",")
	end

	function L.pct(x)
		if x == false or x == nil then
			return "-"
		end
		return fmt("%.3f%%", 100 * x)
	end

	-- the verdicts' units without the cap (Sampling's verdict loop: the models, each part's look, each reading to 2 %)
	function L.units(P)
		local models, isCopy = L.models(P)
		local N = #P
		local total = 0
		for i = 1, N do
			if models[i] then
				total += models[i].work
			end
		end
		for i = 1, N do
			if models[i] then
				local index, higher = L.hidersOf(P, i, models)
				local hm = {}
				for k, j in ipairs(index) do
					hm[k] = models[j]
				end
				total += Cover.UNITS_PER_BOX * N
				local _, used = Cover.shown(models[i], hm, higher, L.Geo.ENCLOSED_EXPOSED_MAX * models[i].total, math.huge)
				total += used
			end
		end
		return total
	end

	cache[name] = L
	return L
end

return Lab
