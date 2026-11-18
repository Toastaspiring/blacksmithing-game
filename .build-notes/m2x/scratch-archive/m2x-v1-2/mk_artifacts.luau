--!nocheck
-- the attack designs as JSON (Lune's serde: not bit-exact; the scripts that made them are beside)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local function blades(parts)
	local best, bi = -1, nil
	for i, p in ipairs(parts) do
		if p.slot == "Blade" and p.size[1] * p.size[2] * p.size[3] > best then best, bi = p.size[1] * p.size[2] * p.size[3], i end
	end
	return bi
end
for _, fx in ipairs({ { "F3", L.repoFixture("F3") }, { "C08", (L.fixture("C08")) } }) do
	local parts = L.renumber(L.copyParts(fx[2]))
	local b = parts[blades(parts)]
	local g = 1e-6
	table.insert(parts, L.part("Guard", b.shape, b.pos, b.rot, { b.size[1] + g, b.size[2] + g, b.size[3] + g }, b.material))
	fs.writeFile("out/bigcopy_" .. fx[1] .. ".json", serde.encode("json", L.renumber(parts)))
end
print("written")
