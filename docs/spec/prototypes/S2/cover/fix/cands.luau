--!nocheck
-- worst_designs candidates under the build: units with the cap lifted, capped with it, valid (Analyze.run), canonical.
-- args: out.json  (writes name, units, valid, lua for every candidate)
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local L = require("./lab")
local fmt = string.format
local OUT = process.args[1] or "cands.json"
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/"
local Free = L.H.plantedSampling({ VERDICT_WORK_MAX = math.huge })

local function canonical(parts)
	local r = L.Canonical.draft({ schema = 1, name = "worst", type = "Sword", parts = parts })
	if not r.ok then return nil, tostring(r.code) .. " " .. tostring(r.path) end
	return r.value.parts
end
local function num(x)
	if x == math.floor(x) and math.abs(x) < 1e15 then return string.format("%d", x) end
	for p = 15, 17 do
		local s = string.format("%." .. p .. "g", x)
		if tonumber(s) == x then return s end
	end
	return string.format("%.17g", x)
end
local function lit(p)
	return fmt("{ id = %d, slot = %q, shape = %q, material = %q, pos = { %s, %s, %s }, rot = { %s, %s, %s, %s }, size = { %s, %s, %s } }",
		p.id, p.slot, p.shape, p.material, num(p.pos[1]), num(p.pos[2]), num(p.pos[3]), num(p.rot[1]), num(p.rot[2]), num(p.rot[3]),
		num(p.rot[4]), num(p.size[1]), num(p.size[2]), num(p.size[3]))
end
local cands = {}
local function add(name, parts) table.insert(cands, { name = name, parts = parts }) end
local BUILD = L.ROOT .. "/docs/spec/prototypes/S2/cover/build/out/"
for k = 1, 4 do
	local rows = serde.decode("json", fs.readFile(BUILD .. "tclimb_" .. k .. ".json"))
	for n, row in ipairs(rows) do
		add(fmt("tclimb_%d.json #%d", k, n), luau.load("return { " .. row.lua .. " }")())
	end
end
for k = 1, 4 do
	local path = SCR .. "m2x-v1-1/out/climb_v1_" .. k .. ".luau"
	if fs.isFile(path) then add(fmt("V1 climb_v1_%d", k), luau.load(fs.readFile(path))()) end
end
for k, d in ipairs(L.Worst.tooComplex) do add(d.name, d.parts) end
local out = {}
for _, c in ipairs(cands) do
	local parts, why = canonical(c.parts)
	if parts == nil then
		print(fmt("%-52s not canonical: %s", c.name, why))
	else
		local P = L.prepared(parts)
		local free = Free.exposure(P)
		local run = L.Analyze.run({ schema = 1, name = "worst", type = "Sword", parts = parts })
		local codes = {}
		for _, e in ipairs(run.validation.errors) do table.insert(codes, e.code) end
		local lits = {}
		for _, p in ipairs(parts) do table.insert(lits, lit(p)) end
		table.insert(out, { name = c.name, units = free.verdictWork, valid = run.validation.ok, codes = table.concat(codes, ","), lua = table.concat(lits, ",\n") })
		print(fmt("%-52s %10.3f units  %s %s", string.sub(c.name, 1, 52), free.verdictWork, run.validation.ok and "valid" or "INVALID", table.concat(codes, ",")))
	end
end
fs.writeFile(OUT, serde.encode("json", out))
