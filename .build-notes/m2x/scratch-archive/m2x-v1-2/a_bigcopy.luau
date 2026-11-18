--!nocheck
-- A copy of F3's / C08's main blade in the Guard (Pommel, Grip), its size larger by `grow` in every dimension, same
-- centre and turn: does the blade stay in the Blade?
local L = require("./lib")
local fmt = string.format
local function blades(parts)
	local best, bi = -1, nil
	for i, p in ipairs(parts) do
		if p.slot == "Blade" and p.size[1] * p.size[2] * p.size[3] > best then
			best, bi = p.size[1] * p.size[2] * p.size[3], i
		end
	end
	return bi
end
for _, fx in ipairs({ { "F3", L.repoFixture("F3") }, { "C08", (L.fixture("C08")) } }) do
	local base = L.renumber(L.copyParts(fx[2]))
	local R0 = L.emu(L.copyParts(base))
	print(fmt("%s: %s", fx[1], L.dline(R0)))
	local bi = blades(base)
	print(fmt("   main blade #%d %s size %s", bi, base[bi].shape, table.concat(base[bi].size, " × ")))
	for _, slot in ipairs({ "Guard", "Pommel", "Grip" }) do
		for _, grow in ipairs({ 0, 1e-7, 2e-7, 2.5e-7, 1e-6, 1e-5, 1e-4 }) do
			local parts = L.copyParts(base)
			local b = parts[bi]
			local c = L.part(slot, b.shape, b.pos, b.rot, { b.size[1] + grow, b.size[2] + grow, b.size[3] + grow }, b.material)
			table.insert(parts, c)
			L.renumber(parts)
			local okc = L.canonical(L.copyParts(parts))
			local P = L.prep(parts)
			local e = L.Sampling.exposure(P)
			local r = L.run(L.copyParts(parts), { measureInvalid = false })
			local R = L.emu(L.copyParts(parts))
			local d = L.dDiff(R0, R)
			print(fmt("   + a copy in the %-6s %.1e larger: canonical %s valid %s %s; blade %s, copy %s; %s; |dD| %.4f",
				slot, grow, tostring(okc), tostring(r.validation.ok), L.codes(r), e.kept[bi] and "kept" or "cleaned", e.kept[#parts] and "kept" or "cleaned", L.dline(R), d))
		end
	end
end
