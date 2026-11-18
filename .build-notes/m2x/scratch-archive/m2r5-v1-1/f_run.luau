--!nocheck
-- A family against V1's truth. Cheap pass at cell 0.002 everywhere; the fine cell where a verdict looks wrong. D with the build's verdict against D with truth's kept row, through the emulator. args: family shard nshards
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local V = require("./v1")
local Fix = require("./fix/Sampling")
local Sets = require("./b_sets")
local T = V.T
local fmt = string.format

local family, shard, nshards = process.args[1], tonumber(process.args[2]), tonumber(process.args[3])
local list = Sets.get(family)

local out = { family = family, designs = 0, parts = 0, wrong = {}, byShape = {} }
local function bump(shape, key)
	out.byShape[shape] = out.byShape[shape] or {}
	out.byShape[shape][key] = (out.byShape[shape][key] or 0) + 1
end
local t0 = os.clock()
for k, d in ipairs(list) do
	if (k - 1) % nshards == shard then
		out.designs += 1
		local parts = d.parts
		V.renumber(parts)
		local P0 = V.prep(parts)
		Fix.FORCE.read, Fix.FORCE.fullRead = {}, true
		local real = Fix.exposure(P0)
		local read = Fix.FORCE.read
		Fix.FORCE.read, Fix.FORCE.fullRead = nil, nil
		local S = T.solids(parts)
		local hider, isCopy, isDust = T.hidersOf(S)
		local row = table.create(#parts, false)
		local wrong = {}
		for i = 1, #parts do
			if not isCopy[i] and not isDust[i] then
				out.parts += 1
				local shape = parts[i].shape
				bump(shape, "parts")
				local s = T.share(S, i, hider, if real.kept[i] then 0.008 else 0.004)
				if (not real.kept[i] and s >= 0.01) or (real.kept[i] and s < 0.05) then
					s = T.share(S, i, hider, 0.0004)
				end
				row[i] = s >= 0.02
				if not real.kept[i] and s >= 0.025 then
					table.insert(wrong, { i = i, label = parts[i].label or "", shape = shape, s = s, read = read[i], kept = false })
					for _, b in ipairs({ 0.025, 0.03, 0.05, 0.075, 0.10, 0.15, 0.20, 0.30, 0.40 }) do
						if s >= b then bump(shape, "E" .. tostring(b)) end
					end
				elseif real.kept[i] and s < 0.015 then
					table.insert(wrong, { i = i, label = parts[i].label or "", shape = shape, s = s, read = read[i], kept = true })
					bump(shape, "K0.015")
					if s < 0.01 then bump(shape, "K0.01") end
					if s < 0.005 then bump(shape, "K0.005") end
					if s < 0.0025 then bump(shape, "K0.0025") end
				end
			end
		end
		if #wrong > 0 then
			-- what the wrong verdicts do: the build's row against truth's, the same measure
			local ok, dv, dt = pcall(function()
				local Rv = V.emu(parts, real.kept)
				local Rt = V.emu(parts, row)
				return Rv, Rt
			end)
			local e = { name = d.name, family = family, wrong = wrong, maxDD = -1, tier = false, step = "", valid = false }
			if ok and dv.steps and dt.steps then
				local w, tier, step = V.dDiff(dv, dt)
				e.maxDD, e.tier, e.step, e.lineV, e.lineT = w, tier, step, V.dline(dv), V.dline(dt)
				local okv = V.valid(parts)
				e.valid = okv
			else
				e.error = tostring(dv)
			end
			table.insert(out.wrong, e)
		end
	end
end
out.seconds = os.clock() - t0
fs.writeFile(fmt("out/f_%s_%d.json", family, shard), serde.encode("json", out))
print(family, shard, out.designs, "designs", out.parts, "parts", #out.wrong, "wrong", fmt("%.1f s", out.seconds))
