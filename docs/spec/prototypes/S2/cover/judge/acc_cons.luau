--!nocheck
-- Accuracy against the truth of A canon and of the conservative-probe option (proto/CoverC), on a design set: every part
-- whose reading is under 10 % by either, or where they differ, gets the truth (VisibleOracle.share). Counts false Enclosed
-- (cleaned, truth >= 2.5/3/5/7.5/10 %) and false kept (kept, truth < 1.5/1/0.5/0.25 %). args: set [every] [offset]
local process = require("@lune/process")
local L = require("./jlib")
local S = require("./jsets")
local CoverC = require("./proto/CoverC")
local fmt = string.format
local set = process.args[1] or "bfam"
local every = tonumber(process.args[2] or "8") or 8
local offset = tonumber(process.args[3] or "0") or 0
local opts = { canon = true }
local designs
if set == "bfam" then designs = S.bFamilies(every, offset); every = 1
elseif set == "attacksA" then designs = S.attackCorpusA()
elseif set == "plausible" then
	local PD = require("./repo/tests/Physics/PlausibleDesigns")
	designs = {}
	for _, d in ipairs(PD.all()) do table.insert(designs, { name = d.name, parts = S.clean(d.parts) }) end
elseif set == "fixtures" then designs = S.fixtures()
else designs = S.json(set, "") end

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
			out[i] = C.shown(models[i], hm, higher, math.huge, nil, true) / models[i].total
		end
	end
	return out
end

local E = { 0.025, 0.03, 0.05, 0.075, 0.10 }
local K = { 0.015, 0.01, 0.005, 0.0025 }
local st = {}
for _, n in ipairs({ "canon", "conservative" }) do st[n] = { fe = { 0, 0, 0, 0, 0 }, fk = { 0, 0, 0, 0 }, maxE = 0, minK = 1, worstE = "", worstK = "" } end
local nd, np, nt, differ = 0, 0, 0, 0
local t0 = os.clock()
for k, d in ipairs(designs) do
	if (k - 1 - (if set == "bfam" then 0 else offset)) % every == 0 then
		nd += 1
		local P = L.prep(d.parts)
		local flags = { L.flags(P) }
		local a = readWith(L.ACover, P, flags)
		local c = readWith(CoverC, P, flags)
		local isCopy, isDust, hider = L.Oracle.flags(P)
		for i = 1, #P do
			if a[i] then
				np += 1
				if math.abs(a[i] - c[i]) > 1e-9 then differ += 1 end
				if math.min(a[i], c[i]) < 0.1 or math.abs(a[i] - c[i]) > 1e-9 then
					nt += 1
					local tr = L.Oracle.share(P, i, hider)
					for _, w in ipairs({ { "canon", a[i] }, { "conservative", c[i] } }) do
						local s = st[w[1]]
						if w[2] < 0.02 then
							for j, th in ipairs(E) do if tr >= th then s.fe[j] += 1 end end
							if tr > s.maxE then s.maxE, s.worstE = tr, fmt("%s part %d (%s) read %.3f%%", d.name, i, P[i].shape, 100 * w[2]) end
						else
							for j, th in ipairs(K) do if tr < th then s.fk[j] += 1 end end
							if tr < s.minK then s.minK, s.worstK = tr, fmt("%s part %d (%s) read %.3f%%", d.name, i, P[i].shape, 100 * w[2]) end
						end
					end
				end
			end
		end
	end
end
print(fmt("ACC %s every %d offset %d: %d designs, %d parts, %d differ between the two, %d against the truth, %.0f s", set, every, offset, nd, np, differ, nt, os.clock() - t0))
for _, n in ipairs({ "canon", "conservative" }) do
	local s = st[n]
	print(fmt("  %-13s false Enclosed >= 2.5/3/5/7.5/10 %%: %d/%d/%d/%d/%d (highest cleaned %.3f%%: %s)", n, s.fe[1], s.fe[2], s.fe[3], s.fe[4], s.fe[5], 100 * s.maxE, s.worstE))
	print(fmt("  %-13s false kept < 1.5/1/0.5/0.25 %%: %d/%d/%d/%d (lowest kept %.3f%%: %s)", "", s.fk[1], s.fk[2], s.fk[3], s.fk[4], 100 * s.minK, s.worstK))
end
