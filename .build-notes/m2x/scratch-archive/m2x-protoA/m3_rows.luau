--!nocheck
-- M3 on the M2 rows: every design where a reading's verdict differs from the truth's (true share >= 2 % <=> kept), D through the
-- emulator on the reading's kept row against D on the truth's kept row (the same measure). Per reading: designs, tier flips, worst
-- |dD|. args: set rows-prefix out
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local S = require("./sets")
local fmt = string.format

local which, prefix, outPath = process.args[1], process.args[2], process.args[3]
local byDesign = {}
for _, f in ipairs(fs.readDir("out")) do
	if string.sub(f, 1, #prefix) == prefix and string.sub(f, -6) == ".jsonl" then
		for line in string.gmatch(fs.readFile("out/" .. f), "[^\n]+") do
			local r = serde.decode("json", line)
			if not r.error then
				byDesign[r.d] = byDesign[r.d] or {}
				table.insert(byDesign[r.d], r)
			end
		end
	end
end
local READ = { { "old", "vo", "./v/force_old/Sampling", "./proto_old/analyze_build" }, { "base", "vb", "./v/force_base/Sampling", "./proto_base/analyze_build" },
	{ "canon", "vc", "./v/force_canon/Sampling", "./proto_canon/analyze_build" }, { "fine", "vf", "./v/force_fine/Sampling", "./proto_fine/analyze_build" } }
local wanted = {}
for name, rows in byDesign do
	for _, rd in ipairs(READ) do
		for _, r in ipairs(rows) do
			if (r.t >= 0.02) ~= r[rd[2]] then wanted[name] = true end
		end
	end
end
local designs = {}
if which == "plausible" then
	local Plausible = require("./repo/tests/Physics/PlausibleDesigns")
	for _, d in ipairs(Plausible.all()) do
		local name = d.family .. " | " .. d.name
		if wanted[name] then designs[name] = S.clean(d.parts) end
	end
elseif which == "attacks" then
	local function scan(list) for _, d in ipairs(list) do if wanted[d.name] then designs[d.name] = d.parts end end end
	scan(S.worstP()); scan(S.climbed()); scan(S.attacksJson())
	for _, f in ipairs(fs.readDir("corpus")) do
		if string.sub(f, -6) == ".jsonl" then scan(S.jsonl("corpus/" .. f)) end
	end
elseif string.sub(which, 1, 5) == "bset:" then
	local Sets = require("./atk/v11/b_sets")
	for fam in string.gmatch(string.sub(which, 6), "[^,]+") do
		for _, d in ipairs(Sets.get(fam)) do
			local name = fam .. " | " .. d.name
			if wanted[name] then designs[name] = S.clean(d.parts) end
		end
	end
end
local function dDiff(a, b)
	if not a or not b or not a.steps or not b.steps then return -1, false end
	local w, tier = 0, false
	for i, s in ipairs(a.steps) do
		w = math.max(w, math.abs(s.d - b.steps[i].d))
		tier = tier or s.tier ~= b.steps[i].tier
	end
	return w, tier
end
local out = {}
for _, rd in ipairs(READ) do
	local Force, Emu = require(rd[3]), require(rd[4])
	local n, flips, worst, worstName = 0, 0, 0, ""
	local t0 = os.clock()
	for name, parts in designs do
		local rows = byDesign[name]
		local truthRow, readRow, differs = table.create(#parts, false), table.create(#parts, false), false
		for _, r in ipairs(rows) do
			truthRow[r.i] = r.t >= 0.02
			readRow[r.i] = r[rd[2]]
			if truthRow[r.i] ~= readRow[r.i] then differs = true end
		end
		if differs then
			n += 1
			Force.FORCE.kept = readRow
			local ok1, Rv = pcall(Emu.run, { name = "x", parts = parts }, { measureInvalid = true, build = true })
			Force.FORCE.kept = truthRow
			local ok2, Rt = pcall(Emu.run, { name = "x", parts = parts }, { measureInvalid = true, build = true })
			Force.FORCE.kept = nil
			if ok1 and ok2 then
				local w, tier = dDiff(Rv, Rt)
				if tier then flips += 1 end
				if w > worst then worst, worstName = w, name end
			end
		end
	end
	print(fmt("%s %s: %d designs whose verdict differs from the truth's, %d tier flips, worst |dD| %.4f (%s), %.0f s", which, rd[1], n, flips, worst, worstName, os.clock() - t0))
	table.insert(out, { reading = rd[1], designs = n, tierFlips = flips, worstDD = worst, worst = worstName })
end
fs.writeFile(outPath, serde.encode("json", out))
