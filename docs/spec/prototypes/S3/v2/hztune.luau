--!strict
-- S3 prototype v2: HoldZone tuning: both policies per profile and config; the better mean is the reference.
-- usage: lune run hztune.luau <N> "<sets>"   (same set syntax as sweep.luau: name=base[:hard][:steel])
local Sim = require("./Sim")
local Params = require("./Params")
local Bots = require("./Bots")
local process = require("@lune/process")
local N = tonumber(process.args[1]) or 300
local SETS = process.args[2] or ""
local PROFS = string.split(process.args[3] or "Good,Average", ",")
for _, item in string.split(SETS, ";") do
	if item ~= "" then
		local kv = string.split(item, "=")
		local d = Params.find("HoldZone", kv[1])
		local parts = string.split(kv[2], ":")
		d.base = tonumber(parts[1]) :: number
		if parts[2] and parts[2] ~= "" then
			local t = table.clone(d.tier or { 1, 1, 1, 1, 1 }); t[2] = tonumber(parts[2]) :: number; d.tier = t
		end
		if parts[3] and parts[3] ~= "" then
			local m = table.clone(d.material or {}); m.Steel = tonumber(parts[3]) :: number; d.material = m
		end
	end
end
local out = {}
for _, c in { { "IN", "Iron", "Normal" }, { "SN", "Steel", "Normal" }, { "IH", "Iron", "Hard" }, { "SH", "Steel", "Hard" } } do
	local cells = {}
	for _, prof in PROFS do
		local best, bestPol = nil :: any, ""
		local both = {}
		for _, pol in { "hold", "pump" } do
			local s, p = Sim.run({ family = "HoldZone", material = c[2], tier = c[3], profile = prof, n = N, policy = pol })
			local st = Bots.stats(s, p)
			table.insert(both, string.format("%s%.3f", string.sub(pol, 1, 1), st.mean))
			if best == nil or st.mean > best.mean then
				best, bestPol = st, pol
			end
		end
		table.insert(cells, string.format("%s %s %.3f/%4.1f%% (%s)", string.sub(prof, 1, 2), string.sub(bestPol, 1, 1), best.mean, (1 - best.pass) * 100, table.concat(both, " ")))
	end
	table.insert(out, c[1] .. " " .. table.concat(cells, " "))
end
print("[" .. SETS .. "] " .. table.concat(out, " | "))
