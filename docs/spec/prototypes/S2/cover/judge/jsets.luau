--!nocheck
-- The judge's design sets: { name, parts } lists, parts as PartData (ids 1..n). Paths point at the judge's repo copy
-- (repo/, today's build) and at the verifiers' and prototypes' folders, read only.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Fx = require("./repo/docs/spec/prototypes/S2/v2/fixtures")
local Blueprints = require("./repo/tests/fixtures/Blueprints")

local S = {}
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/"
S.SCR = SCR
S.JUDGE = SCR .. "m2x-judge/"
S.REPO = S.JUDGE .. "repo/"

local function clean(parts)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = { id = i, label = p.label, shape = p.shape, slot = p.slot or "Blade", material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end
S.clean = clean

function S.protoFixtures()
	local out = {}
	local function add(b) table.insert(out, { name = b.name, parts = clean(b.parts) }) end
	for _, b in ipairs(Fx.calibration()) do add(b) end
	for _, b in ipairs(Fx.golden()) do add(b) end
	for _, a in ipairs(Fx.adversarial()) do
		add(a.fixture)
		add({ name = "base of " .. a.fixture.name, parts = a.base.parts })
	end
	for _, b in ipairs(Fx.regression()) do
		if b.parts then add(b) elseif b.fixture then add(b.fixture) end
	end
	for _, b in ipairs(Fx.validation()) do
		if b.parts then add(b) elseif b.fixture then add(b.fixture) end
	end
	for _, b in ipairs(Fx.perf()) do add(b) end
	return out
end

function S.repoF()
	local out = {}
	for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do
		local core = Blueprints.core(id)
		table.insert(out, { name = "repo " .. id, parts = clean(core.parts) })
	end
	return out
end

function S.fixtures()
	local out = S.protoFixtures()
	for _, d in ipairs(S.repoF()) do table.insert(out, d) end
	return out
end

function S.json(path, prefix)
	if not fs.isFile(path) then return {} end
	local list = serde.decode("json", fs.readFile(path))
	local out = {}
	if type(list) == "table" and type(list.parts) == "table" then list = { list } end
	for k, d in ipairs(list) do
		if type(d) == "table" and type(d.parts) == "table" then
			table.insert(out, { name = (prefix or "") .. (d.name or d.from or tostring(k)), parts = clean(d.parts) })
		end
	end
	return out
end

function S.jsonl(path, prefix)
	local out = {}
	if not fs.isFile(path) then return out end
	for line in string.gmatch(fs.readFile(path), "[^\n]+") do
		local d = serde.decode("json", line)
		table.insert(out, { name = (prefix or "") .. (d.name or "?"), parts = clean(d.parts) })
	end
	return out
end

function S.worstP()
	return S.json(S.REPO .. "docs/spec/prototypes/S2/verdict/worst_P.json", "worst_P ")
end

-- every climbed design listed in the task (the verifiers' cost climbs)
function S.climbed()
	local out = {}
	local function add(list) for _, d in ipairs(list) do table.insert(out, d) end end
	for k = 1, 6 do add(S.json(SCR .. "m2r5-v1-1/out/d_climb_" .. k .. ".json", "v1-1 d_climb_" .. k .. " #")) end
	add(S.json(SCR .. "m2r5-v1-1/out/d_hand.json", "v1-1 d_hand "))
	add(S.json(SCR .. "m2r5-v2-1/study/worst_P_clamped.json", "v2-1 worst_P_clamped "))
	return out
end

function S.attacksJson()
	return S.json(SCR .. "m2r5-v2-2/h/out/attacks.json", "v2-2 attacks ")
end

-- protoA's recorded attack corpus (1,340 designs from 30 attack-script runs)
function S.attackCorpusA()
	return S.jsonl(SCR .. "m2x-protoA/out/corpus_all.jsonl", "")
end

-- protoA's and protoB's climbs on their own units
function S.climbA()
	local out = {}
	for k = 1, 4 do
		for _, d in ipairs(S.json(SCR .. "m2x-protoA/out/climb_" .. k .. ".json", "A climb_" .. k .. " ")) do table.insert(out, d) end
	end
	return out
end

function S.climbB()
	return S.json(SCR .. "m2x-protoB/out/corpus_uclimb_best.json", "B uclimb ")
end

-- the worst designs each prototype saved from its accuracy runs
function S.worstA()
	local out = {}
	for _, d in ipairs(S.json(SCR .. "m2x-protoA/out/m2_worst_attacks.json", "A worst attacks ")) do table.insert(out, d) end
	for _, d in ipairs(S.json(SCR .. "m2x-protoA/out/m2_worst_plausible.json", "A worst plausible ")) do table.insert(out, d) end
	return out
end

function S.worstB()
	return S.json(SCR .. "m2x-protoB/out/m2_worst_designs.json", "B worst ")
end

-- the verifiers' 12 families (m2r5-v1-1/b_sets.luau, through protoB's copy of it for the requires; the same code plus
-- one more family, not used here), every k-th design
function S.bFamilies(every, offset)
	local Sets = require("../m2x-protoB/b_sets")
	local out = {}
	for _, fam in ipairs(Sets.families()) do
		local list = Sets.get(fam)
		for j = 1 + (offset or 0), #list, every or 1 do
			local d = list[j]
			table.insert(out, { name = "b_" .. fam .. " " .. (d.name or tostring(j)), parts = clean(d.parts) })
		end
	end
	return out
end

return S
