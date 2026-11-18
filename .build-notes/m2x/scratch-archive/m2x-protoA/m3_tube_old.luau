--!nocheck
-- the old reading on the false-kept tube designs of m3_tube_fine (base model kept a truly hidden rod)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local fmt = string.format
local rows = serde.decode("json", fs.readFile("out/m3_tube_fine.json"))
for _, r in ipairs(rows) do
	if r.model == "base" and r.truth < 0.02 and r.read >= 0.02 then
		local old = L.oldVerdict(r.parts)
		print(fmt("%-45s true %.3f %% new(base) read %.3f %% kept | old verdict on the rod: %s", r.name, r.truth * 100, r.read * 100, if old[#r.parts] then "kept" else "CLEANED"))
	end
end
