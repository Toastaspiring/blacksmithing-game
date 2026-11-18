--!nocheck
-- M2: the worst designs per reading (old, base, canon, fine), with their parts: false Enclosed by true share, false kept by true share.
-- args: set rows-glob-prefix out
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local S = require("./sets")

local which, prefix, outPath = process.args[1], process.args[2], process.args[3]
local rows = {}
for _, f in ipairs(fs.readDir("out")) do
	if string.sub(f, 1, #prefix) == prefix and string.sub(f, -6) == ".jsonl" then
		for line in string.gmatch(fs.readFile("out/" .. f), "[^\n]+") do
			local r = serde.decode("json", line)
			if not r.error then table.insert(rows, r) end
		end
	end
end
local want = {}
local picks = {}
for _, rd in ipairs({ { "old", "vo" }, { "base", "vb" }, { "canon", "vc" }, { "fine", "vf" } }) do
	local v = rd[2]
	local fe, fk = {}, {}
	for _, r in ipairs(rows) do
		if not r[v] and r.t >= 0.025 then table.insert(fe, r) end
		if r[v] and r.t < 0.015 then table.insert(fk, r) end
	end
	table.sort(fe, function(a, b) return a.t > b.t end)
	table.sort(fk, function(a, b) return a.t < b.t end)
	for k = 1, math.min(5, #fe) do table.insert(picks, { reading = rd[1], kind = "false Enclosed", row = fe[k] }); want[fe[k].d] = true end
	for k = 1, math.min(5, #fk) do table.insert(picks, { reading = rd[1], kind = "false kept", row = fk[k] }); want[fk[k].d] = true end
end
local byName = {}
local function scan(list) for _, d in ipairs(list) do if want[d.name] then byName[d.name] = d.parts end end end
if which == "plausible" then
	local Plausible = require("./repo/tests/Physics/PlausibleDesigns")
	for _, d in ipairs(Plausible.all()) do
		local name = d.family .. " | " .. d.name
		if want[name] then byName[name] = S.clean(d.parts) end
	end
elseif which == "attacks" then
	scan(S.worstP()); scan(S.climbed()); scan(S.attacksJson())
	for _, f in ipairs(fs.readDir("corpus")) do
		if string.sub(f, -6) == ".jsonl" then scan(S.jsonl("corpus/" .. f)) end
	end
end
local out = {}
for _, p in ipairs(picks) do
	table.insert(out, { reading = p.reading, kind = p.kind, design = p.row.d, part = p.row.i, shape = p.row.shape, trueShare = p.row.t,
		read = { base = p.row.rb, canon = p.row.rc, fine = p.row.rf }, kept = { old = p.row.vo, base = p.row.vb, canon = p.row.vc, fine = p.row.vf }, parts = byName[p.row.d] })
end
fs.writeFile(outPath, serde.encode("json", out, true))
print(#out, "worst rows written to", outPath)
