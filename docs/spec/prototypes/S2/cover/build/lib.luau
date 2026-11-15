--!nocheck
-- The builder's measuring harness (m2x-build): design sets as { name, parts } lists, parts as PartData (ids 1..n), and
-- the readings: the snapshot of the build (../snap, the new verdict), the tree before (../old, the line reading), each with
-- a copy of Sampling cut after the verdict (SamplingV). Paths assume the scratch layout; other agents' folders are read only.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local L = {}
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/"
L.SCR = SCR

L.Shapes = require("../snap/src/shared/Physics/Shapes")
L.Sampling = require("../snap/src/shared/Physics/Sampling")
L.SamplingV = require("../snap/src/shared/Physics/SamplingV")
L.Cover = require("../snap/src/shared/Physics/Cover")
L.Analyze = require("../snap/src/shared/Physics/Analyze")
L.Balance = require("../snap/src/shared/Definitions/Balance")
L.Quat = require("../snap/src/shared/Blueprint/Quat")
L.Canonical = require("../snap/src/shared/Blueprint/Canonical")
L.Oracle = require("../snap/tests/Physics/VisibleOracle")
L.OldSampling = require("../old/src/shared/Physics/Sampling")
L.OldSamplingV = require("../old/src/shared/Physics/SamplingV")
L.OldShapes = require("../old/src/shared/Physics/Shapes")
local Fx = require("../snap/docs/spec/prototypes/S2/v2/fixtures")
local Blueprints = require("../snap/tests/fixtures/Blueprints")
L.Fx = Fx

local function clean(parts)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = { id = i, label = p.label, shape = p.shape, slot = p.slot or "Blade", material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end
L.clean = clean

function L.prep(parts, Shapes)
	local S = Shapes or L.Shapes
	local P = table.create(#parts)
	for i, p in ipairs(parts) do
		P[i] = S.prepare(p, i)
	end
	return P
end

function L.protoFixtures()
	local out = {}
	local function add(b)
		table.insert(out, { name = b.name, parts = clean(b.parts) })
	end
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

function L.repoF()
	local out = {}
	for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do
		table.insert(out, { name = "repo " .. id, parts = clean(Blueprints.core(id).parts) })
	end
	return out
end

function L.fixtures()
	local out = L.protoFixtures()
	for _, d in ipairs(L.repoF()) do table.insert(out, d) end
	return out
end

-- the real designs of the cap rule: F, C and X fixtures (and their bases), A22–A27 and P1–P5
function L.realFixtures()
	local out = {}
	for _, d in ipairs(L.fixtures()) do
		local c = string.sub(d.name, 1, 1)
		if c == "C" or c == "F" or c == "A" or c == "X" or c == "P" or string.sub(d.name, 1, 4) == "repo" or string.sub(d.name, 1, 7) == "base of" then
			table.insert(out, d)
		end
	end
	return out
end

function L.plausible()
	local PD = require("../snap/tests/Physics/PlausibleDesigns")
	local out = {}
	for _, d in ipairs(PD.all()) do
		table.insert(out, { name = d.name, parts = clean(d.parts) })
	end
	return out
end

function L.json(path, prefix)
	if not fs.isFile(path) then
		return {}
	end
	local list = serde.decode("json", fs.readFile(path))
	local out = {}
	if type(list) == "table" and type(list.parts) == "table" then
		list = { list }
	end
	for k, d in ipairs(list) do
		if type(d) == "table" and type(d.parts) == "table" then
			table.insert(out, { name = (prefix or "") .. (d.name or d.from or tostring(k)), parts = clean(d.parts) })
		end
	end
	return out
end

function L.jsonl(path, prefix)
	local out = {}
	if not fs.isFile(path) then
		return out
	end
	for line in string.gmatch(fs.readFile(path), "[^\n]+") do
		local d = serde.decode("json", line)
		table.insert(out, { name = (prefix or "") .. (d.name or "?"), parts = clean(d.parts) })
	end
	return out
end

function L.worstP()
	return L.json(SCR .. "m2x-build/snap/docs/spec/prototypes/S2/verdict/worst_P.json", "worst_P ")
end

function L.climbed()
	local out = {}
	local function add(list)
		for _, d in ipairs(list) do table.insert(out, d) end
	end
	for k = 1, 6 do
		add(L.json(SCR .. "m2r5-v1-1/out/d_climb_" .. k .. ".json", "v1-1 d_climb_" .. k .. " #"))
	end
	add(L.json(SCR .. "m2r5-v1-1/out/d_hand.json", "v1-1 d_hand "))
	add(L.json(SCR .. "m2r5-v2-1/study/worst_P_clamped.json", "v2-1 worst_P_clamped "))
	return out
end

function L.attacksJson()
	return L.json(SCR .. "m2r5-v2-2/h/out/attacks.json", "v2-2 attacks ")
end

function L.attackCorpusA()
	return L.jsonl(SCR .. "m2x-protoA/out/corpus_all.jsonl", "")
end

function L.climbA()
	local out = {}
	for k = 1, 4 do
		for _, d in ipairs(L.json(SCR .. "m2x-protoA/out/climb_" .. k .. ".json", "A climb_" .. k .. " ")) do
			table.insert(out, d)
		end
	end
	return out
end

function L.climbB()
	return L.json(SCR .. "m2x-protoB/out/corpus_uclimb_best.json", "B uclimb ")
end

function L.judgeWorst()
	return L.json(SCR .. "m2x-judge/out/judge_worst.json", "judge ")
end

function L.judgeTime()
	return L.json(SCR .. "m2x-judge/out/jtime_5_best.json", "judge jtime ")
end

-- the verifiers' 12 families (through protoB's copy of b_sets.luau), every k-th design
function L.bFamilies(every, offset)
	local Sets = require("../../m2x-protoB/b_sets")
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

function L.median(t)
	local c = table.clone(t)
	table.sort(c)
	local n = #c
	if n == 0 then
		return 0
	end
	if n % 2 == 1 then
		return c[(n + 1) / 2]
	end
	return (c[n / 2] + c[n / 2 + 1]) / 2
end

-- 17 significant digits, -0 kept, for Luau literals
function L.num(x)
	if x ~= x then
		return "0/0"
	end
	if x == 0 then
		return if 1 / x < 0 then "-0" else "0"
	end
	if x == math.floor(x) and math.abs(x) < 1e15 then
		return string.format("%d", x)
	end
	return string.format("%.17g", x)
end

function L.partLiteral(p)
	local n = L.num
	return string.format('{ id = %d, slot = "%s", shape = "%s", material = "%s", pos = { %s, %s, %s }, rot = { %s, %s, %s, %s }, size = { %s, %s, %s } }',
		p.id, p.slot, p.shape, p.material, n(p.pos[1]), n(p.pos[2]), n(p.pos[3]), n(p.rot[1]), n(p.rot[2]), n(p.rot[3]),
		n(p.rot[4]), n(p.size[1]), n(p.size[2]), n(p.size[3]))
end

return L
