--!nocheck
-- the attack corpus (m2x-protoA/out/corpus_all.jsonl): the build's kept row against the truth's (VisibleOracle, the fine
-- lattice wherever the coarse one leaves a part within reach of 2 %), part for part. args: shard nshards
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lab")
local fmt = string.format
local shard, nshards = tonumber(process.args[1]) or 0, tonumber(process.args[2]) or 1
local text = fs.readFile("C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-protoA/out/corpus_all.jsonl")
local k, designs, rows, parts = 0, 0, 0, 0
for line in string.gmatch(text, "[^\n]+") do
	k += 1
	if (k - 1) % nshards == shard then
		local d = serde.decode("json", line)
		local list = {}
		for i, p in ipairs(d.parts) do
			list[i] = { id = i, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron", pos = p.pos, rot = p.rot, size = p.size }
		end
		local P = L.prepared(list)
		local e = L.Sampling.exposure(P)
		designs += 1
		if not e.capped then
			local _, _, hider = L.Oracle.flags(P)
			local differs = false
			for i = 1, #P do
				if hider[i] then
					parts += 1
					local rough = L.Oracle.measure(P, i, hider, L.Oracle.COARSE_POINTS)
					if (e.kept[i] and rough < 0.06) or (not e.kept[i] and rough > 0.01) then
						local truth = L.Oracle.share(P, i, hider)
						if (truth >= 0.02) ~= e.kept[i] then
							differs = true
							print(fmt("%s part %d (%s): truth %.3f%%, %s", d.name, i, P[i].shape, 100 * truth, e.kept[i] and "kept" or "cleaned"))
						end
					end
				end
			end
			if differs then rows += 1 end
		end
	end
end
print(fmt("corpus shard %d/%d: %d designs, %d parts that hide; rows that differ from the truth's: %d", shard, nshards, designs, parts, rows))
