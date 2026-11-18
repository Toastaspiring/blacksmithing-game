--!nocheck
local process = require("@lune/process")
local L = require("./lib")
local T = require("./tsets")
local fmt = string.format
local name = process.args[1] or "P4"
local parts
if name == "cluster" then parts = T.cluster(0.58, 0.08, 0.2, 0.3) else parts = L.fixture(name) end
L.renumber(parts)
local core = { schema = 1, name = "x", type = "Sword", parts = parts }
local where = {}
for run = 1, 15 do
	local last = os.clock()
	local prev = "start"
	local longest, at = 0, ""
	L.Analyze.run(core, { measureInvalid = true, checkpoint = function()
		local now = os.clock()
		local g = (now - last) * 1000
		local names = {}
		for level = 3, 7 do
			local s, n, ln = debug.info(level, "snl")
			table.insert(names, (n or "?") .. ":" .. tostring(ln))
		end
		local here = table.concat(names, "<")
		if g > longest then longest, at = g, prev .. " -> " .. here end
		prev = here
		last = now
	end })
	where[run] = { longest, at }
end
table.sort(where, function(a, b) return a[1] < b[1] end)
for k = 1, #where do print(fmt("%.3f ms  %s", where[k][1], where[k][2])) end
