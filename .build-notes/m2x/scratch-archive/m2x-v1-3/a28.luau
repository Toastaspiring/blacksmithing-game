--!nocheck
-- A28 (24 thin rods past the cap) and V1's round-2 rod bundle (471,362 units in O7): units and Analyze.run's answer
local L = require("./lib")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Adv = require("./repo/tests/fixtures/Adversarial")
local fmt = string.format
local function show(name, parts)
	L.renumber(parts)
	local u = L.units(L.prep(parts))
	local r = L.run(L.copyParts(parts), { measureInvalid = true })
	print(fmt("%-24s units %12.3f  valid %s  %s  physics %s", name, u, tostring(r.validation.ok), L.codes(r), tostring(r.physics ~= nil)))
end
for _, variant in ipairs(Adv.variants) do
	if variant.key == "A28" then
		show("A28", L.copyParts(variant.draft().parts))
	end
end
local ok, b = pcall(function()
	return serde.decode("json", fs.readFile("C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v1-2/out/h_bundle.json"))
end)
if ok then
	show("V1 rod bundle", b)
end
