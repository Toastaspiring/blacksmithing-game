--!nocheck
-- A follow-up option for the model's channel (proto/CoverC.luau, a copy of A's Cover): a round target's facets probe
-- HIDE_OFFSET + their sagitta, and a round hider's half-spaces move out to the true solid's support for the probe test only
-- (the buried / coincident test keeps the inscribed half-spaces, so coincident round copies still count once).
-- Compared with A canon on: the model-channel designs (out/atk_model_all.json), and against the truth on the plausible
-- families with round parts (every k-th design): false Enclosed (cleaned, truth ≥ 2.5/3/5 %) and false kept (kept,
-- truth < 1.5/1/0.5 %). args: [every]
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./jlib")
local S = require("./jsets")
local CoverC = require("./proto/CoverC")
local fmt = string.format
local every = tonumber(process.args[1] or "8") or 8
local opts = { canon = true }

local function readWith(C, P, flags)
	local rank, byRank, isCopy, dust, hider = table.unpack(flags)
	local models = {}
	for i = 1, #P do if hider[i] then models[i] = C.model(P[i], opts) end end
	local out = {}
	for i = 1, #P do
		if hider[i] then
			local idx, higher = L.cands(P, i, rank, byRank, hider)
			local hm = {}
			for k, j in ipairs(idx) do hm[k] = models[j] end
			local s = C.shown(models[i], hm, higher, math.huge, nil, true)
			out[i] = s / models[i].total
		end
	end
	return out
end

print("-- the model-channel designs")
for _, d in ipairs(S.json("out/atk_model_all.json", "")) do
	local P = L.prep(d.parts)
	local flags = { L.flags(P) }
	local a = readWith(L.ACover, P, flags)
	local c = readWith(CoverC, P, flags)
	local t = if string.find(d.name, "ball in grip") then #P elseif string.find(d.name, "rod") then 5 elseif string.find(d.name, "part 1") then 1 else 2
	local truth = L.truth(P, t)
	print(fmt("%-44s truth %7.3f%%  canon %7.3f%%  conservative %7.3f%%", d.name, 100 * (truth or 0), 100 * (a[t] or 0), 100 * (c[t] or 0)))
end

print(fmt("-- plausible families with round parts, every %d-th design, against the truth", every))
local PD = require("./repo/tests/Physics/PlausibleDesigns")
local fams = { ballRivet = true, cylRivet = true, cylRib = true, wrapRings = true, pommelInBlock = true, rod = true }
local stats = {}
local function stat(name) stats[name] = stats[name] or { n = 0, fe = { 0, 0, 0 }, fk = { 0, 0, 0 }, maxE = 0, minK = 1 }; return stats[name] end
local k = 0
local t0 = os.clock()
for _, d in ipairs(PD.all()) do
	local fam = d.family or string.match(d.name or "", "^(%a+)")
	if fams[fam] then
		k += 1
		if (k - 1) % every == 0 then
			local parts = S.clean(d.parts)
			local P = L.prep(parts)
			local flags = { L.flags(P) }
			local a = readWith(L.ACover, P, flags)
			local c = readWith(CoverC, P, flags)
			local isCopy, isDust, hider = L.Oracle.flags(P)
			for i = 1, #P do
				if a[i] and (P[i].code == L.Shapes.BALL or P[i].code == L.Shapes.CYLINDER or a[i] < 0.1 or c[i] < 0.1) then
					local tr = L.Oracle.share(P, i, hider)
					for _, which in ipairs({ { "canon", a[i] }, { "conservative", c[i] } }) do
						local s = stat(which[1])
						s.n += 1
						local kept = which[2] >= 0.02
						if not kept then
							if tr >= 0.025 then s.fe[1] += 1 end
							if tr >= 0.03 then s.fe[2] += 1 end
							if tr >= 0.05 then s.fe[3] += 1 end
							if tr > s.maxE then s.maxE = tr end
						else
							if tr < 0.015 then s.fk[1] += 1 end
							if tr < 0.01 then s.fk[2] += 1 end
							if tr < 0.005 then s.fk[3] += 1 end
							if tr < s.minK then s.minK = tr end
						end
					end
				end
			end
		end
	end
end
for _, name in ipairs({ "canon", "conservative" }) do
	local s = stats[name]
	if s then
		print(fmt("%-13s parts %d: false Enclosed at true >= 2.5/3/5 %%: %d/%d/%d (highest cleaned %.3f%%); false kept at true < 1.5/1/0.5 %%: %d/%d/%d (lowest kept %.3f%%)",
			name, s.n, s.fe[1], s.fe[2], s.fe[3], 100 * s.maxE, s.fk[1], s.fk[2], s.fk[3], 100 * s.minK))
	end
end
print(fmt("%.0f s", os.clock() - t0))
