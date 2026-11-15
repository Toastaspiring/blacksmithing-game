--!nocheck
-- gaps.luau's median per-run longest gap with Analyze's CHECK_UNITS planted. args: checkUnits runs file.json|real names...
local process = require("@lune/process")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local L = require("./lib")
local fmt = string.format
local CU, RUNS = process.args[1], tonumber(process.args[2])
local root = "../snapcap/src/shared/"
local src = fs.readFile(root .. "Physics/Analyze.luau")
src = string.gsub(src, "local CHECK_UNITS = %d+", "local CHECK_UNITS = " .. CU)
local mods = {
	["../Definitions/Types"] = require("../snapcap/src/shared/Definitions/Types"),
	["../Definitions/EquipmentTypes"] = require("../snapcap/src/shared/Definitions/EquipmentTypes"),
	["../Definitions/Limits"] = require("../snapcap/src/shared/Definitions/Limits"),
	["../Definitions/Versions"] = require("../snapcap/src/shared/Definitions/Versions"),
	["../Blueprint/Schema"] = require("../snapcap/src/shared/Blueprint/Schema"),
	["./Gjk"] = require("../snapcap/src/shared/Physics/Gjk"),
	["./MassProps"] = require("../snapcap/src/shared/Physics/MassProps"),
	["./Sampling"] = require("../snapcap/src/shared/Physics/Sampling"),
	["./Shapes"] = require("../snapcap/src/shared/Physics/Shapes"),
}
local Analyze = luau.load(src, { debugName = "Analyze", environment = { require = function(n) return mods[n] end, math = math, table = table, string = string, error = error, tostring = tostring, ipairs = ipairs, pairs = pairs, type = type } })()
local designs = {}
for a = 3, #process.args do
	local arg = process.args[a]
	if string.sub(arg, 1, 5) == "real:" then
		for _, d in ipairs(L.realFixtures()) do if string.find(d.name, string.sub(arg, 6), 1, true) then table.insert(designs, d) end end
	else
		local file, n = string.match(arg, "^(.-)#(%d+)$")
		local list = serde.decode("json", fs.readFile(file))
		table.insert(designs, { name = arg, parts = L.clean(list[tonumber(n)].parts) })
	end
end
for _, d in ipairs(designs) do
	local core = L.Canonical.draft({ schema = 1, name = "x", type = "Sword", parts = d.parts }).value
	local maxima, counts = {}, 0
	for r = 1, RUNS do
		local last, m, c = os.clock(), 0, 0
		Analyze.run(core, { measureInvalid = true, checkpoint = function()
			local now = os.clock()
			m = math.max(m, (now - last) * 1000)
			c += 1
			last = now
		end })
		maxima[r] = m
		counts = c
	end
	print(fmt("CHECK_UNITS %s %-36s checkpoints %5d  median run-maximum %.3f ms", CU, string.sub(d.name, 1, 36), counts, L.median(maxima)))
end
