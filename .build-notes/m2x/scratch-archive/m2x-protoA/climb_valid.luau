--!nocheck
local S = require("./sets")
local Analyze = require("./repo/src/shared/Physics/Analyze")
local Canonical = require("./repo/src/shared/Blueprint/Canonical")
local fmt = string.format
for sd = 1, 4 do
	local ok, list = pcall(S.json, "out/climb_" .. sd .. ".json", "seed " .. sd .. " #")
	if ok then
		for k = 1, math.min(3, #list) do
			local d = list[k]
			local core = { schema = 1, name = "x", type = "Sword", parts = d.parts }
			local canon = Canonical.isCanonical(core)
			local r = Analyze.run(core, {})
			local codes = {}
			for _, e in ipairs(r.validation.errors) do table.insert(codes, e.code .. (if e.reason then "/" .. e.reason else "")) end
			print(fmt("%-14s canonical %s, valid %s %s", d.name, tostring(canon), tostring(r.validation.ok), table.concat(codes, ",")))
		end
	end
end
