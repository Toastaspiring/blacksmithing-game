--!strict
-- S3 prototype v2: parameter sweep. usage:
--   lune run sweep.luau <family> <N> <profiles> <policy> "<param>=<base>[:<tierHard>][:<steel>];..." [configs]
-- e.g. lune run sweep.luau HoldZone 300 Good,Average hold "fullHeat=1.2;heatDecay=0.8"
local Sim = require("./Sim")
local Params = require("./Params")
local process = require("@lune/process")

local FAM = process.args[1]
local N = tonumber(process.args[2]) or 200
local PROFS = string.split(process.args[3] or "Good,Average", ",")
local POLICY = process.args[4]
if POLICY == "-" then
	POLICY = nil
end
local SETS = process.args[5] or ""
local CFG = process.args[6] or "IN,SN,IH,SH"
local X = tonumber(process.args[7] or "")

for _, item in string.split(SETS, ";") do
	if item ~= "" then
		local kv = string.split(item, "=")
		local d = Params.find(FAM, kv[1])
		local parts = string.split(kv[2], ":")
		d.base = tonumber(parts[1]) :: number
		if parts[2] and parts[2] ~= "" then
			local t = table.clone(d.tier or { 1, 1, 1, 1, 1 })
			t[2] = tonumber(parts[2]) :: number
			d.tier = t
		end
		if parts[3] and parts[3] ~= "" then
			local m = table.clone(d.material or {})
			m.Steel = tonumber(parts[3]) :: number
			d.material = m
		end
	end
end

local MAP = { IN = { "Iron", "Normal" }, SN = { "Steel", "Normal" }, IH = { "Iron", "Hard" }, SH = { "Steel", "Hard" } }
local out = {}
for _, key in string.split(CFG, ",") do
	local c = MAP[key]
	local cells = {}
	for _, prof in PROFS do
		local st = Sim.summary({ family = FAM, material = c[1], tier = c[2], profile = prof, n = N, policy = POLICY, x = X })
		table.insert(cells, string.format("%s %.3f/%4.1f%%", string.sub(prof, 1, 2), st.mean, (1 - st.pass) * 100))
	end
	table.insert(out, key .. " " .. table.concat(cells, " "))
end
print(string.format("[%s %s] %s", SETS, POLICY or "", table.concat(out, " | ")))
