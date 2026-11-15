--!nocheck
-- fix-2: units, validity and the lowest reading of V1's saved designs on the final tree
local L = require("./lib")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local fmt = string.format
for _, f in ipairs({ "h_bundle", "pastcap_32", "pastcap_33", "pastcap_34", "h_report", "cageflip_sword" }) do
	local d = serde.decode("json", fs.readFile("out/" .. f .. ".json"))
	local parts = L.renumber(L.copyParts(d.parts or d))
	local P = L.prep(parts)
	local Free = nil
	local e = L.Sampling.exposure(P)
	local r = L.run(L.copyParts(parts), { measureInvalid = false })
	print(fmt("%-16s %2d parts %12.3f units%s, %s %s", f, #parts, e.verdictWork, e.capped and " (capped)" or "", r.validation.ok and "valid" or "invalid", L.codes(r)))
end
