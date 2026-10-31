--!strict
-- S3 prototype v2: quick table of mean / pass rate per family x config x profile.
-- usage: lune run base.luau <family> <N> [profiles,comma] [policy] [x override]
local Sim = require("./Sim")
local process = require("@lune/process")

local FAM = process.args[1] or "TimingStrike"
local N = tonumber(process.args[2]) or 200
local PROFS = string.split(process.args[3] or "Elite,Good,Average,Poor", ",")
local POLICY = process.args[4]
local X = tonumber(process.args[5] or "")

local CONFIGS = { { "Iron", "Normal" }, { "Steel", "Normal" }, { "Iron", "Hard" }, { "Steel", "Hard" } }
local t0 = os.clock()
for _, c in CONFIGS do
	local row = {}
	for _, prof in PROFS do
		local st = Sim.summary({ family = FAM, material = c[1], tier = c[2], profile = prof, n = N, policy = POLICY, x = X })
		table.insert(row, string.format("%s %.3f [%.2f-%.2f] %5.1f%%", prof, st.mean, st.p10, st.p90, st.pass * 100))
	end
	print(string.format("%s %s/%s | %s", FAM, c[1], c[2], table.concat(row, " | ")))
end
print(string.format("(%.1f s)", os.clock() - t0))
