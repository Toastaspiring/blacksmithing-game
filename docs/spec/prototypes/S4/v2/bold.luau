--!strict
-- S4 prototype v2: expected Q of a whole craft vs design difficulty (every step at the same D), from the
-- gamma sweep means (out/gamma_data.luau): E[Q] = T * sum_i w_i * E[s_eff,i](D) * d(tier, D), with and without gamma.
-- usage: lune run bold.luau [gamma] [steelT]
local data = require("./out/gamma_data")
local process = require("@lune/process")
local G = tonumber(process.args[1]) or 0.15
local TS = tonumber(process.args[2]) or 1.02
local W = { HoldZone = 0.25, TimingStrike = 0.40, PrecisionTrace = 0.35 }
local DMIN = { Normal = 0.0, Hard = 0.2 }
local DMUL = { Normal = 1.00, Hard = 1.25 }
local function eff(fam: string, mat: string, prof: string, tier: string, x: number): number
	for _, r in data do
		if r.family == fam and r.material == mat and r.profile == prof and r.tier == tier and math.abs(r.x - x) < 1e-6 then
			return r.eff
		end
	end
	error("missing")
end
local XS = { { "Normal", 0.0 }, { "Normal", 0.1 }, { "Normal", 0.1999 }, { "Hard", 0.2 }, { "Hard", 0.3 }, { "Hard", 0.45 }, { "Hard", 0.6 }, { "Hard", 0.8 }, { "Hard", 1.0 } }
local hdr = {}
for _, p in XS do
	table.insert(hdr, string.format("%s %.2f", string.sub(p[1], 1, 1), p[2]))
end
print("| Profile, material, gamma | " .. table.concat(hdr, " | ") .. " |")
print("|---|" .. string.rep("---|", #XS))
for _, prof in { "Elite", "Good", "Average", "Poor" } do
	for _, mat in { "Iron", "Steel" } do
		for _, g in { 0, G } do
			local cells = {}
			for _, p in XS do
				local tier, x = p[1], p[2]
				local d = DMUL[tier] * (1 + g * (x - DMIN[tier]))
				local s = 0
				for fam, w in W do
					s += w * eff(fam, mat, prof, tier, x) * d
				end
				local T = if mat == "Steel" then TS else 1
				table.insert(cells, string.format("%.3f", T * s))
			end
			print(string.format("| %s, %s, %.2f | %s |", prof, mat, g, table.concat(cells, " | ")))
		end
	end
end
