--!strict
-- S3 prototype v2: multi-set sweep (one family, one policy) for tuning.
-- usage: lune run multisweep.luau <family> <N> <profiles> <policy|-> "<set1>" "<set2>" ...
-- set syntax: name=base[:hard][:steel];name2=...   ("" keeps the current Params)
local Sim = require("./Sim")
local Params = require("./Params")
local process = require("@lune/process")

local FAM = process.args[1]
local N = tonumber(process.args[2]) or 200
local PROFS = string.split(process.args[3] or "Good,Average", ",")
local POLICY: string? = process.args[4]
if POLICY == "-" then
	POLICY = nil
end

local function snapshot(): any
	local snap = {}
	for i, d in Params.DEFS[FAM].params do
		snap[i] = { base = d.base, tier = d.tier and table.clone(d.tier), material = d.material and table.clone(d.material) }
	end
	return snap
end
local function restore(snap: any)
	for i, d in Params.DEFS[FAM].params do
		d.base, d.tier, d.material = snap[i].base, snap[i].tier, snap[i].material
	end
end
local function apply(set: string)
	for _, item in string.split(set, ";") do
		if item ~= "" then
			local kv = string.split(item, "=")
			local d = Params.find(FAM, kv[1])
			local parts = string.split(kv[2], ":")
			if parts[1] ~= "" then
				d.base = tonumber(parts[1]) :: number
			end
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
end

local snap = snapshot()
for ai = 5, #process.args do
	local set = process.args[ai]
	restore(snap)
	apply(set)
	local out = {}
	for _, c in { { "IN", "Iron", "Normal" }, { "SN", "Steel", "Normal" }, { "IH", "Iron", "Hard" }, { "SH", "Steel", "Hard" } } do
		local cells = {}
		for _, prof in PROFS do
			local st = Sim.summary({ family = FAM, material = c[2], tier = c[3], profile = prof, n = N, policy = POLICY })
			table.insert(cells, string.format("%s%.3f/%4.1f", string.sub(prof, 1, 1), st.mean, (1 - st.pass) * 100))
		end
		table.insert(out, c[1] .. " " .. table.concat(cells, " "))
	end
	print(string.format("[%s]\n   %s", set, table.concat(out, " | ")))
end
