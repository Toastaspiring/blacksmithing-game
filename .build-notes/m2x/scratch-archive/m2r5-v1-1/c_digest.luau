--!nocheck
-- A digest of every bit of Analyze.run and Sampling.exposure on fixed designs. Each run inserts every record's fields in its own random order and allocates junk first: a process's string hashing and table layout differ.
local process = require("@lune/process")
local Analyze = require("./tree/src/shared/Physics/Analyze")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local TestRng = require("./tree/tests/lib/TestRng")
local Fx = require("./proto/fixtures")

local seed = math.floor(os.clock() * 1e6) % 2147483647 + tonumber(process.args[1] or "0") * 1000
math.randomseed(seed)
local junk = {}
for i = 1, math.random(100, 5000) do
	junk["k" .. tostring(math.random(1, 1e9))] = { i }
end

local h = 2166136261
local function mix(b)
	h = bit32.bxor(h, b)
	h = (h * 16777619) % 4294967296
end
local function feed(value)
	local t = type(value)
	if t == "number" then
		local s = string.pack(">d", value)
		for i = 1, 8 do mix(string.byte(s, i)) end
	elseif t == "boolean" then
		mix(if value then 1 else 2)
	elseif t == "string" then
		for i = 1, #value do mix(string.byte(value, i)) end
	elseif t == "table" then
		-- keys sorted: the digest must not itself depend on the order
		local keys = {}
		for k in value do table.insert(keys, k) end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			feed(k)
			feed(value[k])
		end
	else
		mix(3)
	end
end

local function shuffled(part)
	local fields = { "id", "slot", "shape", "material", "pos", "rot", "size", "label" }
	for i = #fields, 2, -1 do
		local j = math.random(1, i)
		fields[i], fields[j] = fields[j], fields[i]
	end
	local out = {}
	for _, f in ipairs(fields) do
		if part[f] ~= nil then
			local v = part[f]
			out[f] = if type(v) == "table" then table.clone(v) else v
		end
	end
	return out
end

local function run(parts)
	local list = {}
	for i, p in ipairs(parts) do list[i] = shuffled(p) end
	local fields = { "schema", "name", "type", "parts" }
	local core = {}
	for i = #fields, 2, -1 do
		local j = math.random(1, i)
		fields[i], fields[j] = fields[j], fields[i]
	end
	local values = { schema = 1, name = "x", type = "Sword", parts = list }
	for _, f in ipairs(fields) do core[f] = values[f] end
	local r = Analyze.run(core, { measureInvalid = true })
	feed(r.validation)
	feed(r.cleaned)
	feed(r.physics)
	feed(r.budget)
	local P = {}
	for i, p in ipairs(list) do P[i] = Shapes.prepare(p, i) end
	local ex = Sampling.exposure(P)
	feed(ex)
end

for _, l in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
	for _, b in ipairs(l) do
		local parts = {}
		for i, p in ipairs(b.parts) do
			local c = table.clone(p)
			c.id = i
			parts[i] = c
		end
		run(parts)
	end
end
local rng = TestRng.new(5)
for d = 1, 200 do
	run(H.anyDesign(rng).parts)
end
print(string.format("%08x", h))
