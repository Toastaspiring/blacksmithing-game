--!nocheck
-- per design of a set, on the tree LAB_ROOT: kept row; the measure (hSurf, surfSamples, subSampled, exposedKept, contact) and
-- mass, volume, COM, balance, each to the bit, one line. args: set k0 k1 out
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./lab")
local set, k0, k1, OUT = process.args[1], tonumber(process.args[2]), tonumber(process.args[3]), process.args[4]
local designs = {}
if set == "plausible" then
	designs = ((require :: any)(L.ROOT .. "/tests/Physics/PlausibleDesigns")).all()
elseif set == "corpus" then
	local serde = require("@lune/serde")
	local text = fs.readFile("C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-protoA/out/corpus_all.jsonl")
	for line in string.gmatch(text, "[^\n]+") do
		local d = serde.decode("json", line)
		local parts = {}
		for i, p in ipairs(d.parts) do
			parts[i] = { id = i, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron", pos = p.pos, rot = p.rot, size = p.size }
		end
		table.insert(designs, { name = d.name or "?", parts = parts })
	end
elseif set == "attacks" then
	designs = L.Attacks
elseif set == "fixtures" then
	for _, id in ipairs(L.Blueprints.order) do table.insert(designs, { name = id, parts = L.Blueprints.core(id).parts }) end
	table.insert(designs, { name = "C09", parts = L.H.ornate().parts })
	for _, s in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf() }) do
		for _, b in ipairs(s) do
			if b.parts then table.insert(designs, { name = b.name, parts = b.parts })
			elseif b.fixture then table.insert(designs, { name = b.fixture.name, parts = b.fixture.parts }) end
		end
	end
end
local function h(x) return string.format("%.17g", x) end
k1 = math.min(k1, #designs)
local lines = {}
for k = k0, k1 do
	local d = designs[k]
	local props, e = L.H.measure({ parts = d.parts })
	local kept, ex, ct = {}, {}, {}
	for i = 1, #d.parts do
		kept[i] = e.kept[i] and "1" or "0"
		ex[i] = h(e.exposedKept[i])
		local row = {}
		for j = 1, #d.parts do row[j] = h(e.contact[i][j]) end
		ct[i] = table.concat(row, ",")
	end
	local mass = props and table.concat({ h(props.mass), h(props.volume), h(props.com[1]), h(props.com[2]), h(props.com[3]), h(props.balance or 0) }, " ") or "-"
	table.insert(lines, string.format("%d\t%s\t%s\t%s %d %d\t%s\t%s\t%s", k, d.name, table.concat(kept), h(e.hSurf), e.surfSamples, e.subSampled, table.concat(ex, " "), table.concat(ct, ";"), mass))
end
fs.writeFile(OUT, table.concat(lines, "\n") .. "\n")
print(set, k0, k1, #lines)
