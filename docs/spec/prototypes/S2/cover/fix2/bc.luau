--!nocheck
-- fix-2 bit-compare (after V2's bc.luau): per design, per tree given by root, the verdict (kept row, cleaned, capped), the
-- measure (hSurf, surfSamples, subSampled, exposedKept, contact), mass (ownership and report) and the volume probes, as
-- %.17g strings, and the verdict's units.
--   lune run bc -- <set> <k> <n> <out> <root1> [<root2> ...]
-- set: plausible | corpus | fixtures
local process = require("@lune/process")
local fs = require("@lune/fs")
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local SRC = SCR .. "/m2x-fix-2/cur"
local args = process.args
local set, k, n, out = args[1], tonumber(args[2]), tonumber(args[3]), args[4]
local roots = {}
for i = 5, #args do
	table.insert(roots, args[i])
end
local fmt = string.format

local function tree(root)
	local function req(p)
		return (require :: any)(root .. "/" .. p)
	end
	return {
		Shapes = req("src/shared/Physics/Shapes"),
		Sampling = req("src/shared/Physics/Sampling"),
		MassProps = req("src/shared/Physics/MassProps"),
		EquipmentTypes = req("src/shared/Definitions/EquipmentTypes"),
	}
end
local trees = {}
for i, r in ipairs(roots) do
	trees[i] = tree(r)
end

local designs = {}
local function add(name, parts)
	local copy = {}
	for i, p in ipairs(parts) do
		copy[i] = { id = i, label = p.label, slot = p.slot, shape = p.shape, material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	table.insert(designs, { name = name, parts = copy })
end
if set == "plausible" then
	local PD = (require :: any)(SRC .. "/tests/Physics/PlausibleDesigns")
	for _, d in ipairs(PD.all()) do
		table.insert(designs, { name = d.name, parts = d.parts })
	end
elseif set == "corpus" then
	local serde = require("@lune/serde")
	for line in string.gmatch(fs.readFile(SCR .. "/m2x-protoA/out/corpus_all.jsonl"), "[^\n]+") do
		local d = serde.decode("json", line)
		add(d.name, d.parts)
	end
elseif set == "fixtures" then
	local Fx = (require :: any)(SRC .. "/docs/spec/prototypes/S2/v2/fixtures")
	local B = (require :: any)(SRC .. "/tests/fixtures/Blueprints")
	local Adv = (require :: any)(SRC .. "/tests/fixtures/Adversarial")
	local Canonical = (require :: any)(SRC .. "/src/shared/Blueprint/Canonical")
	local Attacks = (require :: any)(SRC .. "/tests/Physics/CoverAttacks")
	local Worst = (require :: any)(SRC .. "/docs/spec/prototypes/S2/cover/worst_designs")
	for _, b in ipairs(Fx.calibration()) do
		add("proto " .. b.name, b.parts)
	end
	for _, b in ipairs(Fx.golden()) do
		add("proto " .. b.name, b.parts)
	end
	for _, a in ipairs(Fx.adversarial()) do
		add("proto " .. a.fixture.name, a.fixture.parts)
		add("proto base of " .. a.fixture.name, a.base.parts)
	end
	for _, x in ipairs(Fx.regression()) do
		add("proto " .. x.fixture.name, x.fixture.parts)
		add("proto ref of " .. x.fixture.name, x.base.parts)
	end
	for _, b in ipairs(Fx.validation()) do
		add("proto " .. b.name, b.parts)
	end
	for _, b in ipairs(Fx.perf()) do
		add("proto " .. b.name, b.parts)
	end
	for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do
		add("repo " .. id, B.core(id).parts)
	end
	for _, v in ipairs(Adv.variants) do
		local ok, res = pcall(function()
			return Canonical.draft(v.draft())
		end)
		if ok and type(res) == "table" and res.ok and res.value and res.value.parts then
			add("adv " .. v.key, res.value.parts)
		end
	end
	for _, d in ipairs(Attacks) do
		add("attack " .. d.name, d.parts)
	end
	for _, d in ipairs(Worst.valid) do
		add("worst valid " .. d.name, d.parts)
	end
	for _, d in ipairs(Worst.tooComplex) do
		add("worst tooComplex " .. d.name, d.parts)
	end
end

local function g(x)
	return fmt("%.17g", x)
end

local function analyze(T, parts)
	local P = {}
	for i, p in ipairs(parts) do
		P[i] = T.Shapes.prepare(p, i)
	end
	local ex = T.Sampling.exposure(P)
	local N = #P
	local kept, cl = {}, {}
	for i = 1, N do
		kept[i] = ex.kept[i] and "1" or "0"
	end
	for _, c in ipairs(ex.cleaned) do
		table.insert(cl, c.partId .. c.reason:sub(1, 1))
	end
	local verdict = table.concat(kept) .. "/" .. table.concat(cl, ",") .. (ex.capped and "/CAPPED" or "")
	local m = { g(ex.hSurf), g(ex.surfSamples), g(ex.subSampled) }
	for i = 1, N do
		table.insert(m, g(ex.exposedKept[i]))
	end
	local c = {}
	for i = 1, N do
		for j = 1, N do
			table.insert(c, g(ex.contact[i][j]))
		end
	end
	local mass, probes = "-", "-"
	if not ex.capped then
		local typeDef = T.EquipmentTypes.get("Sword")
		local rankOf = {}
		for _, s in ipairs(typeDef.slots) do
			rankOf[s.id] = s.rank
		end
		local gp, ga = T.MassProps.physicsFrame(P, typeDef.geometry.gripSlot)
		local own = T.MassProps.ownership(P, ex.kept, rankOf)
		local rep = T.MassProps.report(P, ex.kept, own, typeDef.geometry, gp, ga)
		local ms = { g(rep.mass), g(rep.volume), g(rep.com[1]), g(rep.com[2]), g(rep.com[3]), g(rep.balance),
			g(rep.balanceFromHand), g(rep.reach), g(rep.bladeLength), g(rep.totalLength), g(rep.comOffAxis), g(rep.guardPos),
			g(rep.gripPoint[1]), g(rep.gripPoint[2]), g(rep.gripPoint[3]), g(rep.gripAxis[1]), g(rep.gripAxis[2]) }
		for i = 1, N do
			table.insert(ms, g(rep.ownedVolume[i]))
		end
		mass = table.concat(ms, " ")
		local pr = T.Sampling.volumeProbes(P, ex.kept)
		local ps = { g(pr.h), g(pr.total) }
		for i = 1, N do
			table.insert(ps, g(pr.byPart[i].n))
		end
		probes = table.concat(ps, " ")
	end
	return verdict, table.concat(m, " ") .. " | " .. table.concat(c, " "), mass, probes, ex.verdictWork or -1
end

local lines = {}
for idx, d in ipairs(designs) do
	if (idx - 1) % n == k then
		local row = { tostring(idx), d.name }
		for _, T in ipairs(trees) do
			local ok, v, m, ms, pr, units = pcall(analyze, T, d.parts)
			if not ok then
				table.insert(row, "ERROR " .. tostring(v))
				for _ = 1, 4 do
					table.insert(row, "-")
				end
			else
				table.insert(row, v)
				table.insert(row, m)
				table.insert(row, ms)
				table.insert(row, pr)
				table.insert(row, g(units))
			end
		end
		table.insert(lines, table.concat(row, "\t"))
	end
end
fs.writeFile(out, table.concat(lines, "\n") .. "\n")
print(fmt("%s slice %d/%d: %d designs", set, k, n, #lines))
