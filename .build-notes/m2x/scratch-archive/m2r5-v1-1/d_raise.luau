--!nocheck
-- A checkpoint that raises at the k-th call, for every k: nothing left behind, and the next run bit-identical to a run with no checkpoint at all. Also: how often it fires, per phase of work.
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local Analyze = V.Analyze
local fmt = string.format

local function digest(value)
	local h = 2166136261
	local function mix(b)
		h = bit32.bxor(h, b)
		h = (h * 16777619) % 4294967296
	end
	local function feed(x)
		local t = type(x)
		if t == "number" then
			local s = string.pack(">d", x)
			for i = 1, 8 do mix(string.byte(s, i)) end
		elseif t == "boolean" then
			mix(if x then 1 else 2)
		elseif t == "string" then
			for i = 1, #x do mix(string.byte(x, i)) end
		elseif t == "table" then
			local keys = {}
			for k in x do table.insert(keys, k) end
			table.sort(keys, function(a, b)
				if type(a) == type(b) then return a < b end
				return type(a) == "number"
			end)
			for _, k in ipairs(keys) do
				feed(k)
				feed(x[k])
			end
		end
	end
	feed(value)
	return h
end

local designs = {}
for _, n in ipairs({ "F5", "C09", "C05", "P1", "P3", "P4" }) do
	table.insert(designs, { n, V.renumber((V.fixture(n))) })
end
for a = 1, #process.args do
	local data = serde.decode("json", fs.readFile(process.args[a]))
	for i = 1, math.min(3, #data) do
		table.insert(designs, { fmt("%s#%d", string.match(process.args[a], "[^/]*$"), i), V.renumber(V.copyParts(data[i].parts)) })
	end
end
for _, d in ipairs(designs) do
	local core = { schema = 1, name = "x", type = "Sword", parts = d[2] }
	local base = digest(Analyze.run(core, { measureInvalid = true }))
	local calls = 0
	local same = digest(Analyze.run(core, { measureInvalid = true, checkpoint = function() calls += 1 end }))
	assert(base == same, "a checkpoint changed the result")
	local tried, raised, bad = 0, 0, 0
	local step = math.max(1, calls // 400)
	for k = 1, calls, step do
		local n = 0
		local ok, err = pcall(Analyze.run, core, { measureInvalid = true, checkpoint = function()
			n += 1
			if n == k then error("cancelled") end
		end })
		tried += 1
		if not ok and string.find(tostring(err), "cancelled", 1, true) then raised += 1 end
		local again = digest(Analyze.run(core, { measureInvalid = true }))
		if again ~= base then bad += 1 end
	end
	print(fmt("%-22s %5d checkpoints; raised at %3d of them (step %d): %3d raised, %d next runs differ", string.sub(d[1], 1, 22), calls, tried, step, raised, bad))
end
