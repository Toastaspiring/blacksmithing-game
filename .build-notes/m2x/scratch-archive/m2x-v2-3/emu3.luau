--!nocheck
-- V2 round 3: every step's D on every prototype fixture: the prototype in index order ("proto"), the prototype handed the
-- parts in the repo's measure order as Reference.spec does ("protoR"), and the M3 emulator (the prototype's edge and factor
-- formulas on a tree's kept row, exposedKept, contact and ownership) on the repo ("now") and the tree before ("before").
--   lune run emu3 -- <out.tsv> [name prefix]
local process = require("@lune/process")
local fs = require("@lune/fs")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local Fx = require(W .. "/emuNow/proto/fixtures")
local Proto = require(W .. "/emuNow/proto/analyze")
local variants = {
	{ "now", require(W .. "/emuNow/proto/analyze_build") },
	{ "before", require(W .. "/emuBefore/proto/analyze_build") },
}
local NowSampling = require(W .. "/emuNow/repo/src/shared/Physics/Sampling")
local NowShapes = require(W .. "/emuNow/repo/src/shared/Physics/Shapes")
local out, only = process.args[1], process.args[2]
local fmt = string.format

local designs = {}
local function add(name, parts)
	if only and string.sub(name, 1, #only) ~= only then
		return
	end
	local copy = {}
	for i, p in ipairs(parts) do
		copy[i] = { id = i, label = p.label, slot = p.slot, shape = p.shape, material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	table.insert(designs, { name = name, parts = copy })
end
for _, b in ipairs(Fx.calibration()) do add(b.name, b.parts) end
for _, b in ipairs(Fx.golden()) do add(b.name, b.parts) end
for _, a in ipairs(Fx.adversarial()) do add(a.fixture.name, a.fixture.parts) add("base of " .. a.fixture.name, a.base.parts) end
for _, x in ipairs(Fx.regression()) do add(x.fixture.name, x.fixture.parts) add("ref of " .. x.fixture.name, x.base.parts) end
for _, b in ipairs(Fx.validation()) do add(b.name, b.parts) end
for _, b in ipairs(Fx.perf()) do add(b.name, b.parts) end

local function dline(R)
	if not R.steps then
		return "no steps (valid " .. tostring(R.valid) .. ")"
	end
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%s %.17g %s/%s", string.sub(s.step, 1, 2), s.d, s.tier, s.tierRaw))
	end
	return table.concat(t, ", ")
end

-- the parts in the repo's measure order (Reference.spec's inRankOrder)
local function inRankOrder(parts)
	local list = {}
	for i, p in ipairs(parts) do
		list[i] = NowShapes.prepare(p, i)
	end
	local _, order = NowSampling.measureRanked(list)
	local r = {}
	for k, p in ipairs(order) do
		local q = table.clone(parts[p.index])
		q.id = k
		r[k] = q
	end
	return r
end

local lines = {}
for _, d in ipairs(designs) do
	local row = { d.name }
	local ok, R = pcall(Proto.run, { name = d.name, parts = d.parts }, { measureInvalid = true })
	table.insert(row, ok and dline(R) or ("ERROR " .. tostring(R)))
	ok, R = pcall(Proto.run, { name = d.name, parts = inRankOrder(d.parts) }, { measureInvalid = true })
	table.insert(row, ok and dline(R) or ("ERROR " .. tostring(R)))
	for _, v in ipairs(variants) do
		ok, R = pcall(v[2].run, { name = d.name, parts = d.parts }, { measureInvalid = true, build = true })
		table.insert(row, ok and dline(R) or ("ERROR " .. tostring(R)))
	end
	table.insert(lines, table.concat(row, "\t"))
end
fs.writeFile(out, "name\tproto\tprotoR\tnow\tbefore\n" .. table.concat(lines, "\n") .. "\n")
print(#designs .. " designs")
