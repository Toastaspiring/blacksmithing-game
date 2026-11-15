--!nocheck
-- Every climbed design through Blueprint/Canonical and Analyze.run: canonical, valid? Writes out/cands.json. args: out json...
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local Canonical = require("./tree/src/shared/Blueprint/Canonical")
local Versions = require("./tree/src/shared/Definitions/Versions")
local C = require("./count/Sampling")
local COUNT = C.COUNT
local fmt = string.format

local OUT = process.args[1]
local out = {}
local seen = 0
for a = 2, #process.args do
	local path = process.args[a]
	local stem = string.gsub(string.match(path, "[^/\\]*$"), "%.json$", "")
	local data = serde.decode("json", fs.readFile(path))
	for i, d in ipairs(data) do
		seen += 1
		local parts = {}
		for k, p in ipairs(d.parts) do
			parts[k] = { id = k, slot = p.slot, shape = p.shape, material = p.material or "Iron", pos = p.pos, rot = p.rot, size = p.size }
		end
		local draft = { schema = Versions.BLUEPRINT_SCHEMA, name = "worst", type = "Sword", parts = parts }
		local res = Canonical.draft(draft)
		if not res.ok then
			print(fmt("%s#%d refused: %s %s", stem, i, tostring(res.code), tostring(res.path)))
		else
			local core = res.value or res.draft or res.core
			local r = V.Analyze.run(core, {})
			local P = V.prep(core.parts)
			COUNT.sd, COUNT.aabb, COUNT.chord, COUNT.reach = 0, 0, 0, 0
			C.FORCE.verdictOnly = true
			C.exposure(P)
			C.FORCE.verdictOnly = nil
			local score = COUNT.sd + 0.25 * COUNT.aabb + 2 * COUNT.chord + 1.5 * COUNT.reach
			print(fmt("%s#%d canonical %s valid %s cleaned %d score %.0f", stem, i, tostring(Canonical.isCanonical(core)), tostring(r.validation.ok), #r.cleaned, score))
			if not r.validation.ok and #core.parts == 24 then
				-- the labels change no verdict: the 2 lowest kept parts in the Grip, the highest 12 in the Blade, so that a climbed design is a legal one
				local kept = V.Sampling.exposure(P).kept
				local order = {}
				for k = 1, 24 do order[k] = k end
				table.sort(order, function(x, y)
					if P[x].gy ~= P[y].gy then return P[x].gy < P[y].gy end
					return x < y
				end)
				local grips = 0
				local rest = {}
				for _, k in ipairs(order) do
					if kept[k] and grips < 2 then
						core.parts[k].slot = "Grip"
						grips += 1
					else
						table.insert(rest, k)
					end
				end
				for n, k in ipairs(rest) do
					core.parts[k].slot = if n <= 2 then "Pommel" elseif n <= 10 then "Guard" else "Blade"
				end
				r = V.Analyze.run(core, {})
				print("   relabelled: valid", r.validation.ok)
			end
			if r.validation.ok then
				local clean = {}
				for k, p in ipairs(core.parts) do
					clean[k] = { id = p.id, slot = p.slot, shape = p.shape, material = p.material, pos = p.pos, rot = p.rot, size = p.size }
				end
				table.insert(out, { from = fmt("%s#%d", stem, i), score = score, parts = clean })
			end
		end
	end
end
table.sort(out, function(a, b) return a.score > b.score end)
fs.writeFile(OUT, serde.encode("json", out))
print(fmt("%d seen, %d canonical and valid", seen, #out))
