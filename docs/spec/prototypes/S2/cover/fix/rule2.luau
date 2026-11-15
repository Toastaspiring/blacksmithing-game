--!nocheck
-- the r2 verifier's designs of what the 2 % rule admits (V2: a_void #6 → #5, a_lam #13 → #14, a_sheets #12 → #11), D now
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lab")
local E = require("./emulab")
local fmt = string.format
local text = fs.readFile("C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-protoA/out/corpus_all.jsonl")
local want = { ["a_void"] = { 6, 5 }, ["a_lam"] = { 13, 14 }, ["a_sheets"] = { 12, 11 } }
for line in string.gmatch(text, "[^\n]+") do
	local d = serde.decode("json", line)
	local fam, n = string.match(d.name or "", "^v12/(a_%a+) %a+ #(%d+)$")
	if fam and want[fam] and (tonumber(n) == want[fam][1] or tonumber(n) == want[fam][2]) then
		local parts = {}
		for i, p in ipairs(d.parts) do
			parts[i] = { id = i, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron", pos = p.pos, rot = p.rot, size = p.size }
		end
		local e = L.Sampling.exposure(L.prepared(parts))
		local cl = {}
		for _, c in ipairs(e.cleaned) do table.insert(cl, c.partId) end
		print(fmt("%-24s %2d parts  %s  cleaned {%s}", d.name, #parts, E.dline(E.run(parts)), table.concat(cl, " ")))
	end
end
