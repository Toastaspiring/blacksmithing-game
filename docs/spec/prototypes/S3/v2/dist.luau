--!strict
-- S3 prototype v2: FINAL tables + score distributions (generator of final/S3-score-distributions.luau).
-- usage: lune run dist.luau <runsPerCell> <outLuauPath> <outTablePath>
-- Cells: family (3 MVP) x tier {Normal, Hard} x material {Iron, Steel} x profile {Elite, Good, Average, Poor};
-- design factors at Sim.REF_X (Normal 0.10, Hard 0.30); HoldZone with the pump policy (the better one);
-- TimingStrike with timingOffsetMs = 0 (uncalibrated). Seeds: Sim.seedOf(i, salt = 1).
local Sim = require("./Sim")
local Bots = require("./Bots")
local Params = require("./Params")
local fs = require("@lune/fs")
local process = require("@lune/process")

local N = tonumber(process.args[1]) or 2000
local OUT_LUAU = process.args[2]
local OUT_TXT = process.args[3]

local FAMS = { "HoldZone", "TimingStrike", "PrecisionTrace" }
local TIERS = { "Normal", "Hard" }
local MATS = { "Iron", "Steel" }
local PROFS = { "Elite", "Good", "Average", "Poor" }

local lines: { string } = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end

local function sd(xs: { number }, mean: number): number
	local ss = 0
	for _, x in xs do
		ss += (x - mean) * (x - mean)
	end
	return math.sqrt(ss / math.max(1, #xs - 1))
end

local cells = {}
local t0 = os.clock()
out(string.format("# S3 final bot table: %d runs per cell; mean sd [p10 p50 p90] pass%% flagged%%", N))
for _, fam in FAMS do
	for _, tier in TIERS do
		for _, mat in MATS do
			local row = {}
			for _, prof in PROFS do
				local s, p, f = Sim.run({ family = fam, material = mat, tier = tier, profile = prof, n = N, policy = if fam == "HoldZone" then "pump" else nil })
				local st = Bots.stats(s, p, f)
				local d = sd(s, st.mean)
				table.insert(cells, { family = fam, tier = tier, material = mat, profile = prof, scores = s, mean = st.mean, sd = d, pass = st.pass, flag = st.flag })
				table.insert(row, string.format("%s %.3f %.3f [%.2f %.2f %.2f] %5.1f%% %.2f%%", prof, st.mean, d, st.p10, st.p50, st.p90, st.pass * 100, st.flag * 100))
			end
			out(string.format("%s %s/%s | %s", fam, mat, tier, table.concat(row, " | ")))
		end
	end
end
out(string.format("(main cells %.1f s)", os.clock() - t0))

-- extremes and variants (fewer runs)
local NV = math.max(200, N // 2)
out("# Perfect / Idle")
for _, fam in FAMS do
	for _, tier in TIERS do
		for _, mat in MATS do
			local cellsTxt = {}
			local fpsList = if fam == "TimingStrike" then { 60, 30 } else { 60 }
			for _, fps in fpsList do
				local s, p, f = Sim.run({ family = fam, material = mat, tier = tier, profile = "Perfect", fps = fps, n = if fam == "TimingStrike" then NV else math.min(NV, 300) })
				local st = Bots.stats(s, p, f)
				local mn = 1
				for _, v in s do
					mn = math.min(mn, v)
				end
				table.insert(cellsTxt, string.format("Perfect@%d %.4f min %.4f flagged %.0f%%", fps, st.mean, mn, st.flag * 100))
			end
			local s2, p2 = Sim.run({ family = fam, material = mat, tier = tier, profile = "Idle", n = 50 })
			local st2 = Bots.stats(s2, p2)
			table.insert(cellsTxt, string.format("Idle %.4f", st2.mean))
			out(string.format("%s %s/%s | %s", fam, mat, tier, table.concat(cellsTxt, " | ")))
		end
	end
end
out("# Variants: Average@30fps, Good/Average bold design (all factors 1), TimingStrike calibrated offset")
for _, fam in FAMS do
	for _, tier in TIERS do
		for _, mat in MATS do
			local cellsTxt = {}
			local pol = if fam == "HoldZone" then "pump" else nil
			local s, p = Sim.run({ family = fam, material = mat, tier = tier, profile = "Average", fps = 30, n = NV, policy = pol })
			local st = Bots.stats(s, p)
			table.insert(cellsTxt, string.format("Avg@30 %.3f %5.1f%%", st.mean, st.pass * 100))
			for _, prof in { "Good", "Average" } do
				local s3, p3 = Sim.run({ family = fam, material = mat, tier = tier, profile = prof, x = 1, n = NV, policy = pol })
				local st3 = Bots.stats(s3, p3)
				table.insert(cellsTxt, string.format("%s x=1 %.3f %5.1f%%", prof, st3.mean, st3.pass * 100))
			end
			if fam == "TimingStrike" then
				do
					local pr = Bots.variant((Bots.PROFILES :: any).Average, 30)
					local off = math.round(Bots.renderLag(pr) + pr.biasMeanMs)
					local s6, p6 = Sim.run({ family = fam, material = mat, tier = tier, profile = "Average", fps = 30, n = NV, offsetMs = off })
					local st6 = Bots.stats(s6, p6)
					table.insert(cellsTxt, string.format("Avg@30 cal(-%d ms) %.3f %5.1f%%", off, st6.mean, st6.pass * 100))
				end
				for _, prof in { "Elite", "Good", "Average" } do
					local pr = (Bots.PROFILES :: any)[prof]
					local off = math.round(Bots.renderLag(pr) + pr.biasMeanMs)
					local s4, p4 = Sim.run({ family = fam, material = mat, tier = tier, profile = prof, n = NV, offsetMs = off })
					local st4 = Bots.stats(s4, p4)
					table.insert(cellsTxt, string.format("%s cal(-%d ms) %.3f %5.1f%%", prof, off, st4.mean, st4.pass * 100))
				end
			end
			if fam == "HoldZone" then
				local s5, p5 = Sim.run({ family = fam, material = mat, tier = tier, profile = "Average", n = 200, policy = "hold" })
				local st5 = Bots.stats(s5, p5)
				table.insert(cellsTxt, string.format("Avg hold-only %.3f", st5.mean))
			end
			out(string.format("%s %s/%s | %s", fam, mat, tier, table.concat(cellsTxt, " | ")))
		end
	end
end
out(string.format("(total %.1f s)", os.clock() - t0))

if OUT_TXT then
	fs.writeFile(OUT_TXT, table.concat(lines, "\n") .. "\n")
end

if OUT_LUAU then
	local b: { string } = {}
	table.insert(b, "--!strict\n-- S3 per-run score distributions for S4's rarity tuning (RULINGS 2.16). GENERATED, do not edit.\n")
	table.insert(b, "-- Generator: prototypes/S3/v2/dist.luau (lune run dist.luau " .. N .. " <this file> <table>).\n")
	table.insert(b, "-- Each score is one bot run of one step, quantized with Util/Quantize.q(x, 1e4) exactly as Minigames.judge returns it.\n")
	table.insert(b, "-- Design factors of the step's weight list at REF_X; HoldZone pump policy; TimingStrike timingOffsetMs = 0.\n")
	table.insert(b, "-- A step passes when score >= passThreshold. Use cells[i] (ordered) or get(family, tier, material, profile).\n")
	table.insert(b, "local M = {}\n")
	table.insert(b, string.format("M.runsPerCell = %d\nM.passThreshold = 0.5\nM.refX = { Normal = %.2f, Hard = %.2f }\n", N, Sim.REF_X.Normal, Sim.REF_X.Hard))
	table.insert(b, "M.families = { \"HoldZone\", \"TimingStrike\", \"PrecisionTrace\" }\nM.tiers = { \"Normal\", \"Hard\" }\nM.materials = { \"Iron\", \"Steel\" }\nM.profiles = { \"Elite\", \"Good\", \"Average\", \"Poor\" }\n")
	table.insert(b, "M.cells = {\n")
	for _, c in cells do
		local nums = table.create(#c.scores)
		for i, v in c.scores do
			nums[i] = string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "")
		end
		table.insert(b, string.format("\t{ family = %q, tier = %q, material = %q, profile = %q, passThreshold = 0.5, mean = %.4f, sd = %.4f, passRate = %.4f,\n\t\tscores = { %s } },\n",
			c.family, c.tier, c.material, c.profile, c.mean, c.sd, c.pass, table.concat(nums, ", ")))
	end
	table.insert(b, "}\n")
	table.insert(b, [[
local index: { [string]: any } = {}
for _, c in M.cells do
	index[c.family .. "/" .. c.tier .. "/" .. c.material .. "/" .. c.profile] = c
end
function M.get(family: string, tier: string, material: string, profile: string): { number }
	local c = index[family .. "/" .. tier .. "/" .. material .. "/" .. profile]
	assert(c, "no cell " .. family .. "/" .. tier .. "/" .. material .. "/" .. profile)
	return c.scores
end
return M
]])
	fs.writeFile(OUT_LUAU, table.concat(b))
end
