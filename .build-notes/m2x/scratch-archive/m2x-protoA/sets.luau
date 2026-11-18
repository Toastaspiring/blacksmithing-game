--!nocheck
-- protoA's design sets: { name, parts } lists, parts as PartData (ids 1..n).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Fx = require("./proto_base/fixtures")
local Blueprints = require("./repo/tests/fixtures/Blueprints")

local S = {}
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/"
S.SCR = SCR

local function clean(parts)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = { id = i, label = p.label, shape = p.shape, slot = p.slot, material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end
S.clean = clean

-- the prototype's fixtures (S2/v2): calibration C01-C15, golden F1-F5, adversarial A25-A27 and their bases, regression X,
-- validation V, perf P1-P5
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

-- the repo's F1-F5
function S.repoF()
	local out = {}
	for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do
		local core = Blueprints.core(id)
		table.insert(out, { name = "repo " .. id, parts = clean(core.parts) })
	end
	return out
end

function S.json(path, prefix)
	local list = serde.decode("json", fs.readFile(path))
	local out = {}
	for k, d in ipairs(list) do
		if d.parts then
			table.insert(out, { name = (prefix or "") .. (d.name or d.from or tostring(k)), parts = clean(d.parts) })
		end
	end
	return out
end

S.REPO = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game/"

function S.worstP()
	return S.json(S.REPO .. "docs/spec/prototypes/S2/verdict/worst_P.json", "worst_P ")
end

-- every climbed design listed in the task
function S.climbed()
	local out = {}
	local function add(list) for _, d in ipairs(list) do table.insert(out, d) end end
	for k = 1, 6 do add(S.json(SCR .. "m2r5-v1-1/out/d_climb_" .. k .. ".json", "v1-1 d_climb_" .. k .. " #")) end
	add(S.json(SCR .. "m2r5-v1-1/out/d_hand.json", "v1-1 d_hand "))
	add(S.json(SCR .. "m2r5-v1-2/out/climb_fan_3.json", "v1-2 climb_fan_3 "))
	add(S.json(SCR .. "m2r5-v1-2/out/climb_w10_4.json", "v1-2 climb_w10_4 "))
	add(S.json(SCR .. "m2r5-v1-2/out/climb_w8_2.json", "v1-2 climb_w8_2 "))
	add(S.json(SCR .. "m2r5-v1-2/out/d_hand.json", "v1-2 d_hand "))
	add(S.json(SCR .. "m2r5-v1-2/out/x.json", "v1-2 x "))
	add(S.json(SCR .. "m2r5-v2-1/study/worst_P_clamped.json", "v2-1 worst_P_clamped "))
	return out
end

function S.attacksJson()
	return S.json(SCR .. "m2r5-v2-2/h/out/attacks.json", "v2-2 attacks ")
end

-- the verifiers' family files out/b_*.json (the worst designs of each family run)
function S.bFamilies()
	local out = {}
	for _, fam in ipairs({ "ballRivet", "bead", "chamfer", "comb", "curvedGrip", "fuller", "oddPoke", "pinRivet", "sunkRod", "thinPart", "tiltPlate", "wall" }) do
		for k = 0, 9 do
			local path = SCR .. "m2r5-v1-1/out/b_" .. fam .. "_" .. k .. ".json"
			if fs.isFile(path) then
				for _, d in ipairs(S.json(path, "b_" .. fam .. "_" .. k .. " ")) do table.insert(out, d) end
			end
		end
	end
	for k = 0, 3 do
		local path = SCR .. "m2r5-v1-1/out/b_plausible_" .. k .. ".json"
		if fs.isFile(path) then
			for _, d in ipairs(S.json(path, "b_plausible_" .. k .. " ")) do table.insert(out, d) end
		end
	end
	return out
end

-- a jsonl corpus written by the recording harness: one {name, parts} per line
function S.jsonl(path)
	local out = {}
	if not fs.isFile(path) then return out end
	for line in string.gmatch(fs.readFile(path), "[^\n]+") do
		local d = serde.decode("json", line)
		table.insert(out, { name = d.name, parts = clean(d.parts) })
	end
	return out
end

return S
