--!nocheck
-- m2r5: a variant against the truth, on a shard of a set. Per part: false Enclosed (cleaned, true share at or above each band), false kept (kept, true
-- share below 1.5 % and below 1 %), by family and shape. Per design with a wrong verdict: D with the variant's verdict against D with truth's, through the
-- emulator (the kept row forced, the same measure both ways).
-- args: variant set shard nshards [nodelta]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local RepoSampling = require("./repo/src/shared/Physics/Sampling")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Emu = require("./proto/analyze_build")
local Sets = require("./sets")
local V = require("./variants")
local fmt = string.format

local variant, setName, shard, nshards = process.args[1], process.args[2], tonumber(process.args[3]), tonumber(process.args[4])
local noDelta = process.args[5] == "nodelta"
local isRepo = variant == "R"
if not isRepo then
	V.apply(Sampling, variant)
end

local BANDS = { 0.025, 0.03, 0.05, 0.075, 0.10, 0.15, 0.20 }
local THRESHOLD = 0.02

local list = Sets.get(setName)
local truth = {}
for s = 0, 200 do
	local path = fmt("out/truth/%s.%d.json", setName, s)
	if not fs.isFile(path) then break end
	for _, row in ipairs(serde.decode("json", fs.readFile(path))) do
		truth[row[1]] = row[2]
	end
end

local counts = { designs = 0, parts = 0, partsByShape = {}, nearByShape = {}, trueHidden = {} }
local fe, fk, tally = {}, {}, {}
local function bump(t, fam, shape, band)
	t[fam] = t[fam] or {}
	t[fam][shape] = t[fam][shape] or {}
	t[fam][shape][band] = (t[fam][shape][band] or 0) + 1
end

local effects = {}
local worstShare = {}
local emuErrors = 0

local function verdict(P)
	if isRepo then
		return RepoSampling.exposure(P).kept
	end
	Sampling.CFG.verdictOnly = true
	local ex = Sampling.exposure(P)
	Sampling.CFG.verdictOnly = false
	return ex.kept
end

local function dOf(parts, row)
	Sampling.CFG.forceKept = row
	local ok, R = pcall(Emu.run, { name = "x", parts = parts }, { measureInvalid = true, build = true })
	Sampling.CFG.forceKept = nil
	if not ok then
		emuErrors += 1
		return nil
	end
	return R
end

local t0 = os.clock()
for k, d in ipairs(list) do
	if (k - 1) % nshards == shard then
		counts.designs += 1
		local parts = d.parts
		local shares = truth[k]
		assert(shares, "no truth for " .. d.name)
		local P = table.create(#parts)
		for i, p in ipairs(parts) do
			P[i] = Shapes.prepare(p, i)
		end
		local kept = verdict(P)
		local wrong = {}
		local anyWrong = false
		for i = 1, #parts do
			local s = shares[i]
			if s ~= false then
				local shape = parts[i].shape
				counts.parts += 1
				counts.partsByShape[shape] = (counts.partsByShape[shape] or 0) + 1
				if s >= 0.005 and s < 0.20 then
					counts.nearByShape[shape] = (counts.nearByShape[shape] or 0) + 1
				end
				local fam = d.family
				if not kept[i] then
					local inBand = false
					for _, b in ipairs(BANDS) do
						if s >= b then
							bump(fe, fam, shape, tostring(b))
							inBand = true
						end
					end
					if inBand then
						table.insert(wrong, { i = i, label = parts[i].label or "", shape = shape, s = s, kept = false, vol = P[i].volume })
						anyWrong = true
						table.insert(worstShare, { name = d.name, i = i, label = parts[i].label or "", shape = shape, s = s })
					end
				else
					if s < 0.015 then
						bump(fk, fam, shape, "0.015")
						table.insert(wrong, { i = i, label = parts[i].label or "", shape = shape, s = s, kept = true, vol = P[i].volume })
						anyWrong = true
						if s < 0.01 then
							bump(fk, fam, shape, "0.01")
						end
					end
				end
			end
		end
		if anyWrong and not noDelta and #parts <= 24 then
			local truthRow = table.create(#parts, false)
			for i = 1, #parts do
				truthRow[i] = shares[i] ~= false and shares[i] >= THRESHOLD
			end
			local Rt = dOf(parts, truthRow)
			local Rv = dOf(parts, kept)
			if Rt and Rv and Rt.steps and Rv.steps then
				local row = { name = d.name, family = d.family, wrong = wrong, dv = {}, dt = {}, dd = {}, tierFlip = false, maxDD = 0, valid = Rt.valid and Rv.valid, step = "" }
				for si, st in ipairs(Rt.steps) do
					local o = Rv.steps[si]
					local dd = o.d - st.d
					row.dv[si], row.dt[si], row.dd[si] = o.d, st.d, dd
					if math.abs(dd) > row.maxDD then
						row.maxDD = math.abs(dd)
						row.step = st.step
					end
					if o.tier ~= st.tier then
						row.tierFlip = true
					end
				end
				table.insert(effects, row)
			end
		end
	end
end

table.sort(worstShare, function(a, b) return a.s > b.s end)
local top = {}
for i = 1, math.min(60, #worstShare) do top[i] = worstShare[i] end
table.sort(effects, function(a, b) return a.maxDD > b.maxDD end)

fs.writeDir("out/eval")
fs.writeFile(fmt("out/eval/%s.%s.%d.json", variant, setName, shard), serde.encode("json", {
	variant = variant, set = setName, counts = counts, fe = fe, fk = fk, worstShare = top, effects = effects, emuErrors = emuErrors, seconds = os.clock() - t0,
}))
print(variant, setName, shard, counts.designs, "designs", #effects, "with effect rows", fmt("%.1f s", os.clock() - t0))
