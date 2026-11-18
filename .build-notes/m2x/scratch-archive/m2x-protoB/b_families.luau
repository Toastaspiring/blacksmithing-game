--!nocheck
-- The study's families (b_sets.luau, read) against MY truth: every k-th design. Counts per shape, the worst, |dD|. args: family k offset
local process = require("@lune/process")
local L = require("./lib")
local Sets = require("./b_sets")
local T = L.T
local fmt = string.format
local family, K, off = process.args[1], tonumber(process.args[2]) or 40, tonumber(process.args[3]) or 0
T.SPACING, T.MAX_LINES, T.BALL_POINTS = 0.003, 800, 40000
local list = Sets.get(family)
local stats = {}
local function st(shape)
	stats[shape] = stats[shape] or { parts = 0, fe = { 0, 0, 0, 0, 0, 0, 0 }, fk = { 0, 0, 0, 0 }, top = 0, low = 1 }
	return stats[shape]
end
local FE = { 0.025, 0.03, 0.05, 0.075, 0.10, 0.15, 0.20 }
local FK = { 0.015, 0.01, 0.005, 0.0025 }
local worst = {}
local nd = 0
for k, d in ipairs(list) do
	if (k - 1) % K == off then
		nd += 1
		local parts = d.parts
		L.renumber(parts)
		local real, read = L.reads(parts)
		local S = T.setup(parts)
		local row = {}
		local wrong = {}
		for i = 1, #parts do
			row[i] = false
			if S[i].hider then
				local s = T.shareOf(S, i)
				if (not real.kept[i] and s >= 0.012) or (real.kept[i] and s < 0.04) then
					T.SPACING, T.MAX_LINES, T.BALL_POINTS = 0.0006, 4000, 200000
					s = T.shareOf(S, i)
					T.SPACING, T.MAX_LINES, T.BALL_POINTS = 0.003, 800, 40000
				end
				row[i] = s >= 0.02
				local b = st(parts[i].shape)
				b.parts += 1
				if not real.kept[i] then
					b.top = math.max(b.top, s)
					for n, t in ipairs(FE) do
						if s >= t then b.fe[n] += 1 end
					end
					if s >= 0.025 then table.insert(wrong, fmt("%s#%d(%s) true %.2f read %.2f cleaned", tostring(parts[i].label), i, parts[i].shape, s * 100, read[i] * 100)) end
				else
					b.low = math.min(b.low, s)
					for n, t in ipairs(FK) do
						if s < t then b.fk[n] += 1 end
					end
					if s < 0.015 then table.insert(wrong, fmt("%s#%d(%s) true %.2f read %.2f kept", tostring(parts[i].label), i, parts[i].shape, s * 100, read[i] * 100)) end
				end
			end
		end
		if #wrong > 0 then
			local Rv, Rt = L.emu(parts), L.emu(parts, row)
			local w, tier, step = L.dDiff(Rv, Rt)
			table.insert(worst, { w = w, tier = tier, text = fmt("%s %s: %s; |dD| %.4f %s%s", family, d.name, table.concat(wrong, ", "), w, step, if tier then " TIER" else "") })
		end
	end
end
table.sort(worst, function(a, b) return a.w > b.w end)
print(fmt("== %s: %d of %d designs", family, nd, #list))
local shapes = {}
for s in pairs(stats) do table.insert(shapes, s) end
table.sort(shapes)
for _, s in ipairs(shapes) do
	local b = stats[s]
	print(fmt("%-12s parts %6d: false Enclosed at 2.5/3/5/7.5/10/15/20 %%: %s; false kept < 1.5/1/.5/.25 %%: %s; highest cleaned %.2f %%, lowest kept %.2f %%", s, b.parts, table.concat(b.fe, "/"), table.concat(b.fk, "/"), b.top * 100, b.low * 100))
end
for i = 1, math.min(6, #worst) do print("  " .. worst[i].text) end
