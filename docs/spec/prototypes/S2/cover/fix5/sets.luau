--!nocheck
-- m2x-fix-5: the three sets of designs, from the tree before this round (fix4/bc.luau's loader, its REPO the round's base):
-- plausible (tests/Physics/PlausibleDesigns, 33,389), corpus (the 1,340 attack designs, m2x-protoA/out), fixtures (the
-- prototype's fixture sets, F1–F5, the adversarial variants, the 17 attack designs, worst_designs.luau valid and
-- tooComplex: 193). Each design { name, parts } with parts copied, ids renumbered.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local REPO = SCR .. "/m2x-fix-5/base" -- a copy of m2x-r5-base/repo, the tree before this round
local function req(p)
	return (require :: any)(REPO .. "/" .. p)
end

local Sets = {}
Sets.REPO = REPO

local function copy(parts)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = { id = i, label = p.label, slot = p.slot, shape = p.shape, material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end
Sets.copy = copy

function Sets.load(set)
	local designs = {}
	local function add(name, parts)
		table.insert(designs, { name = name, parts = copy(parts) })
	end
	if set == "plausible" then
		for _, d in ipairs(req("tests/Physics/PlausibleDesigns").all()) do
			add(d.name, d.parts)
		end
	elseif set == "corpus" then
		for line in string.gmatch(fs.readFile(SCR .. "/m2x-protoA/out/corpus_all.jsonl"), "[^\n]+") do
			local d = serde.decode("json", line)
			add(d.name, d.parts)
		end
	elseif set == "fixtures" then
		local Fx = req("docs/spec/prototypes/S2/v2/fixtures")
		local B = req("tests/fixtures/Blueprints")
		local Adv = req("tests/fixtures/Adversarial")
		local Canonical = req("src/shared/Blueprint/Canonical")
		local Attacks = req("tests/Physics/CoverAttacks")
		local Worst = req("docs/spec/prototypes/S2/cover/worst_designs")
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
	else
		error("no set " .. tostring(set))
	end
	return designs
end

return Sets
