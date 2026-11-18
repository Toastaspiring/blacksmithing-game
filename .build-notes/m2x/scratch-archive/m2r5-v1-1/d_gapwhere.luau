--!nocheck
-- Where the longest gaps end, per design: the median gap's place
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local fmt = string.format
local function run(name, parts)
	local core = { schema = 1, name = "x", type = "Sword", parts = V.renumber(V.copyParts(parts)) }
	local places = {}
	for r = 1, 15 do
		collectgarbage("collect")
		local last = os.clock()
		local top, where = 0, ""
		V.Analyze.run(core, { measureInvalid = true, checkpoint = function()
			local now = os.clock()
			if now - last > top then
				top = now - last
				where = debug.traceback("", 1)
			end
			last = os.clock()
		end })
		local key = {}
		for f, n in string.gmatch(where, "(%a+)%.luau\"%]:(%d+)") do
			table.insert(key, f .. ":" .. n)
		end
		table.insert(places, { top * 1000, table.concat(key, " < ") })
	end
	table.sort(places, function(a, b) return a[1] < b[1] end)
	local m = places[8]
	print(fmt("%-18s median longest %.3f ms at %s", name, m[1], string.sub(m[2], 1, 90)))
end
local worst = serde.decode("json", fs.readFile("out/worst_P.json"))
run("P1", (V.fixture("P1")))
run("C09", (V.fixture("C09")))
run("worst_P#10", worst[10].parts)
run("worst_P#12", worst[12].parts)
run("worst_P#9", worst[9].parts)
